import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const execFileAsync = promisify(execFile);
const HIDDEN_STATUSES = new Set(["done", "closed"] as const);
type TempPaneStatus = "needs-auth" | "running" | "done" | "failed" | "closed";

type TempPaneRecord = {
  id: string;
  paneId: string;
  purpose: string;
  titleBase?: string;
  title?: string;
  status: TempPaneStatus;
  createdAt: string;
  statusPath?: string;
  logPath?: string;
  handoffDir?: string;
  autoCloseOnSuccess?: boolean;
  closeDelayMs?: number;
  keepOpenOnFailure?: boolean;
};

type RegisterPayload = {
  id?: string;
  paneId: string;
  purpose: string;
  titleBase?: string;
  title?: string;
  status?: TempPaneStatus;
  statusPath?: string;
  logPath?: string;
  handoffDir?: string;
  autoCloseOnSuccess?: boolean;
  closeDelayMs?: number;
  keepOpenOnFailure?: boolean;
};

function runtimeBaseDir() {
  const xdg = process.env.XDG_RUNTIME_DIR;
  if (xdg && existsSync(xdg)) return xdg;

  const runUser = `/run/user/${process.getuid()}`;
  if (existsSync(runUser)) return runUser;

  return tmpdir();
}

function registryDir() {
  return join(runtimeBaseDir(), "pi-tmux-temp");
}

function ensureRegistryDir() {
  mkdirSync(registryDir(), { recursive: true });
  return registryDir();
}

function recordPath(id: string) {
  return join(ensureRegistryDir(), `${id}.json`);
}

function safeJsonParse<T>(value: string): T | undefined {
  try {
    return JSON.parse(value) as T;
  } catch {
    return undefined;
  }
}

function slug(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-{2,}/g, "-") || "temp";
}

function makeId(purpose: string) {
  return `${slug(purpose)}-${Date.now()}`;
}

function readRecord(id: string): TempPaneRecord | undefined {
  const path = recordPath(id);
  if (!existsSync(path)) return undefined;
  return safeJsonParse<TempPaneRecord>(readFileSync(path, "utf-8"));
}

function writeRecord(record: TempPaneRecord) {
  writeFileSync(recordPath(record.id), `${JSON.stringify(record, null, 2)}\n`, "utf-8");
}

function deleteRecord(id: string) {
  rmSync(recordPath(id), { force: true });
}

function loadRecords() {
  if (!existsSync(registryDir())) return [] as TempPaneRecord[];
  return readdirSync(registryDir())
    .filter((name) => name.endsWith(".json"))
    .map((name) => safeJsonParse<TempPaneRecord>(readFileSync(join(registryDir(), name), "utf-8")))
    .filter((value): value is TempPaneRecord => Boolean(value));
}

async function tmux(args: string[], signal?: AbortSignal) {
  try {
    const result = await execFileAsync("tmux", args, {
      signal,
      env: process.env,
      maxBuffer: 1024 * 1024,
    });
    return { ok: true, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
  } catch (error: any) {
    return {
      ok: false,
      stdout: error.stdout ?? "",
      stderr: error.stderr ?? "",
      code: typeof error.code === "number" ? error.code : 1,
    };
  }
}

async function paneExists(paneId: string, signal?: AbortSignal) {
  const result = await tmux(["display-message", "-p", "-t", paneId, "#{pane_id}"], signal);
  return result.ok && (result.stdout || "").trim() === paneId;
}

function statusLabel(status: TempPaneStatus) {
  switch (status) {
    case "needs-auth":
      return "[auth]";
    case "running":
      return "[run]";
    case "done":
      return "[done]";
    case "failed":
      return "[fail]";
    case "closed":
      return "[closed]";
  }
}

async function setPaneTitle(record: TempPaneRecord, signal?: AbortSignal) {
  const title = record.title ?? `${record.titleBase ?? `pi ${record.purpose}`} ${statusLabel(record.status)}`;
  await tmux(["select-pane", "-t", record.paneId, "-T", title], signal);
}

function readStatusFile(statusPath?: string) {
  if (!statusPath || !existsSync(statusPath)) return undefined;
  return readFileSync(statusPath, "utf-8").trim();
}

function renderRecords(records: TempPaneRecord[]) {
  const visible = records.filter((record) => !HIDDEN_STATUSES.has(record.status));
  if (visible.length === 0) return "No PI-managed temporary tmux panes.";
  return visible
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    .map((record) => {
      const parts = [
        `${record.paneId} ${record.purpose}`,
        `status=${record.status}`,
      ];
      if (record.statusPath) parts.push(`statusPath=${record.statusPath}`);
      if (record.logPath) parts.push(`logPath=${record.logPath}`);
      return `- ${parts.join(" | ")}`;
    })
    .join("\n");
}

export default function tmuxManager(pi: ExtensionAPI) {
  const watchers = new Map<string, ReturnType<typeof setInterval>>();
  const closers = new Map<string, ReturnType<typeof setTimeout>>();
  let discoveryTimer: ReturnType<typeof setInterval> | undefined;
  let lastCtx: ExtensionContext | undefined;

  function updateStatusWidget() {
    if (!lastCtx?.hasUI) return;
    const records = loadRecords().filter((record) => !HIDDEN_STATUSES.has(record.status));
    if (records.length === 0) {
      lastCtx.ui.setStatus("tmux-temp", undefined);
      return;
    }
    lastCtx.ui.setStatus("tmux-temp", `tmux temp panes: ${records.length}`);
  }

  function clearTracking(id: string) {
    const watcher = watchers.get(id);
    if (watcher) {
      clearInterval(watcher);
      watchers.delete(id);
    }
    const closer = closers.get(id);
    if (closer) {
      clearTimeout(closer);
      closers.delete(id);
    }
  }

  async function closeRecord(id: string, reason: "manual" | "success" | "missing" = "manual") {
    const record = readRecord(id);
    if (!record) return false;

    if (await paneExists(record.paneId)) {
      await tmux(["kill-pane", "-t", record.paneId]);
    }

    clearTracking(id);

    const statusText = readStatusFile(record.statusPath);
    if (reason === "success" || reason === "manual" || statusText === "0") {
      deleteRecord(id);
      updateStatusWidget();
      return true;
    }

    writeRecord({ ...record, status: "closed" });
    updateStatusWidget();
    return true;
  }

  async function scheduleClose(record: TempPaneRecord) {
    if (!record.autoCloseOnSuccess || record.status !== "done") return;
    if (closers.has(record.id)) return;

    const delay = Math.max(1000, record.closeDelayMs ?? 15000);
    const timer = setTimeout(async () => {
      closers.delete(record.id);
      await closeRecord(record.id, "success");
    }, delay);
    closers.set(record.id, timer);
  }

  async function updateRecordStatus(id: string, nextStatus: TempPaneStatus) {
    const record = readRecord(id);
    if (!record) return;
    if (record.status === nextStatus) return;

    const next = { ...record, status: nextStatus };
    writeRecord(next);
    await setPaneTitle(next);
    updateStatusWidget();

    if (nextStatus === "done") {
      await scheduleClose(next);
    }
    if (nextStatus === "failed" && !next.keepOpenOnFailure) {
      await closeRecord(id, "manual");
    }
  }

  async function reconcileRecord(id: string) {
    const record = readRecord(id);
    if (!record) return;

    if (!(await paneExists(record.paneId))) {
      await closeRecord(id, "missing");
      return;
    }

    const statusText = readStatusFile(record.statusPath);
    if (statusText === undefined || statusText === "running") {
      if (record.status === "needs-auth") {
        await updateRecordStatus(id, "running");
      }
      return;
    }

    if (statusText === "0") {
      await updateRecordStatus(id, "done");
      return;
    }

    await updateRecordStatus(id, "failed");
  }

  function watchRecord(id: string) {
    if (watchers.has(id)) return;
    const interval = setInterval(() => {
      void reconcileRecord(id);
    }, 2000);
    watchers.set(id, interval);
    void reconcileRecord(id);
  }

  function discoverRecords() {
    for (const record of loadRecords()) {
      if (record.status === "done" || record.status === "closed") continue;
      watchRecord(record.id);
      void setPaneTitle(record);
    }
    updateStatusWidget();
  }

  async function register(payload: RegisterPayload) {
    const record: TempPaneRecord = {
      id: payload.id ?? makeId(payload.purpose),
      paneId: payload.paneId,
      purpose: payload.purpose,
      titleBase: payload.titleBase,
      title: payload.title,
      status: payload.status ?? "running",
      createdAt: new Date().toISOString(),
      statusPath: payload.statusPath,
      logPath: payload.logPath,
      handoffDir: payload.handoffDir,
      autoCloseOnSuccess: payload.autoCloseOnSuccess ?? true,
      closeDelayMs: payload.closeDelayMs ?? 15000,
      keepOpenOnFailure: payload.keepOpenOnFailure ?? true,
    };

    writeRecord(record);
    await setPaneTitle(record);
    watchRecord(record.id);
    updateStatusWidget();
    return record;
  }

  pi.events.on("pi-tmux:register", (payload: RegisterPayload) => {
    void register(payload);
  });

  pi.events.on("pi-tmux:close", (payload: { id?: string; paneId?: string }) => {
    const records = loadRecords();
    const record = records.find((item) => item.id === payload.id || item.paneId === payload.paneId);
    if (!record) return;
    void closeRecord(record.id, "manual");
  });

  pi.registerCommand("tmux-temp", {
    description: "Manage PI-owned temporary tmux panes: /tmux-temp list | cleanup | close <pane>",
    handler: async (args, ctx) => {
      lastCtx = ctx;
      const [subcommand, ...rest] = args.trim().split(/\s+/).filter(Boolean);
      const command = subcommand ?? "list";

      if (command === "list") {
        const text = renderRecords(loadRecords());
        if (ctx.hasUI) ctx.ui.notify(text, "info");
        return;
      }

      if (command === "cleanup") {
        const records = loadRecords();
        let closed = 0;
        for (const record of records) {
          if (record.status === "done" || record.status === "closed") {
            if (await closeRecord(record.id, "manual")) closed++;
            continue;
          }
          if (!(await paneExists(record.paneId))) {
            await closeRecord(record.id, "missing");
            closed++;
          }
        }
        if (ctx.hasUI) ctx.ui.notify(`tmux-temp cleanup closed/pruned ${closed} pane(s).`, "info");
        return;
      }

      if (command === "close") {
        const target = rest.join(" ").trim();
        if (!target) {
          if (ctx.hasUI) ctx.ui.notify("Usage: /tmux-temp close <pane-id>", "warning");
          return;
        }
        const record = loadRecords().find((item) => item.paneId === target || item.id === target);
        if (!record) {
          if (ctx.hasUI) ctx.ui.notify(`No tracked pane matches ${target}`, "warning");
          return;
        }
        await closeRecord(record.id, "manual");
        if (ctx.hasUI) ctx.ui.notify(`Closed ${record.paneId}`, "info");
        return;
      }

      if (ctx.hasUI) {
        ctx.ui.notify("Usage: /tmux-temp list | cleanup | close <pane-id>", "warning");
      }
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    lastCtx = ctx;
    for (const record of loadRecords()) {
      const statusText = readStatusFile(record.statusPath);
      if (record.status === "done" || record.status === "closed" || statusText === "0") {
        await closeRecord(record.id, statusText === "0" ? "success" : "manual");
        continue;
      }
      await setPaneTitle(record);
      watchRecord(record.id);
    }
    if (discoveryTimer) clearInterval(discoveryTimer);
    discoveryTimer = setInterval(() => {
      discoverRecords();
    }, 2000);
    updateStatusWidget();
  });

  pi.on("session_shutdown", async () => {
    if (discoveryTimer) {
      clearInterval(discoveryTimer);
      discoveryTimer = undefined;
    }
    for (const id of Array.from(watchers.keys())) clearTracking(id);
  });
}
