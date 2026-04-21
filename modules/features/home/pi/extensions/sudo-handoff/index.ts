import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { createBashTool } from "@mariozechner/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const execFileAsync = promisify(execFile);
const SUDO_RE = /(^|[\n;|&()])\s*sudo(?:\s|$)/m;

function shellEscape(value: string) {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

function preview(command: string, max = 140) {
  const oneLine = command.replace(/\s+/g, " ").trim();
  return oneLine.length > max ? `${oneLine.slice(0, max - 1)}…` : oneLine;
}

async function run(cmd: string, args: string[], signal?: AbortSignal) {
  try {
    const result = await execFileAsync(cmd, args, {
      signal,
      env: process.env,
      maxBuffer: 2 * 1024 * 1024,
    });
    return { stdout: result.stdout ?? "", stderr: result.stderr ?? "", exitCode: 0 };
  } catch (error: any) {
    return {
      stdout: error.stdout ?? "",
      stderr: error.stderr ?? "",
      exitCode: typeof error.code === "number" ? error.code : 1,
    };
  }
}

function runtimeBaseDir() {
  const xdg = process.env.XDG_RUNTIME_DIR;
  if (xdg && existsSync(xdg)) return xdg;

  const runUser = `/run/user/${process.getuid()}`;
  if (existsSync(runUser)) return runUser;

  return tmpdir();
}

function writeExecutable(path: string, content: string) {
  writeFileSync(path, content, { encoding: "utf-8", mode: 0o700 });
  chmodSync(path, 0o700);
}

function tmuxRegistryDir() {
  const baseDir = runtimeBaseDir();
  mkdirSync(baseDir, { recursive: true });
  const registryDir = join(baseDir, "pi-tmux-temp");
  mkdirSync(registryDir, { recursive: true });
  return registryDir;
}

function writeTmuxRecord(params: {
  paneId: string;
  purpose: string;
  titleBase: string;
  status: "needs-auth" | "running" | "done" | "failed" | "closed";
  statusPath: string;
  logPath: string;
  handoffDir: string;
  autoCloseOnSuccess: boolean;
  closeDelayMs: number;
  keepOpenOnFailure: boolean;
}) {
  const id = `${params.purpose}-${Date.now()}`;
  const recordPath = join(tmuxRegistryDir(), `${id}.json`);
  writeFileSync(
    recordPath,
    `${JSON.stringify({
      id,
      paneId: params.paneId,
      purpose: params.purpose,
      titleBase: params.titleBase,
      status: params.status,
      createdAt: new Date().toISOString(),
      statusPath: params.statusPath,
      logPath: params.logPath,
      handoffDir: params.handoffDir,
      autoCloseOnSuccess: params.autoCloseOnSuccess,
      closeDelayMs: params.closeDelayMs,
      keepOpenOnFailure: params.keepOpenOnFailure,
    }, null, 2)}\n`,
    "utf-8",
  );
}

export default function sudoHandoff(pi: ExtensionAPI) {
  const baseBash = createBashTool(process.cwd());

  pi.registerTool({
    ...baseBash,
    name: "bash",
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const command = params.command;
      if (!SUDO_RE.test(command)) {
        return baseBash.execute(toolCallId, params, signal, onUpdate);
      }

      if (!ctx.hasUI) {
        return {
          content: [{
            type: "text",
            text:
              "Blocked sudo bash command: tmux handoff requires interactive UI. Run PI inside tmux, or use a structured tool like nixos_update/systemd_control if applicable.",
          }],
          details: { ok: false, handoff: false, reason: "no-ui" },
          isError: true,
        };
      }

      if (!process.env.TMUX) {
        return {
          content: [{
            type: "text",
            text:
              "Blocked sudo bash command: this workflow requires PI to run inside tmux so it can open a side pane for direct authentication and live logs.",
          }],
          details: { ok: false, handoff: false, reason: "not-in-tmux" },
          isError: true,
        };
      }

      const confirmed = await ctx.ui.confirm(
        "Open privileged command in tmux?",
        `PI will open a tmux side pane and run:\n\n${preview(command, 220)}\n\nYou will type the sudo password directly in that pane.`,
      );
      if (!confirmed) {
        return {
          content: [{ type: "text", text: "Cancelled privileged tmux handoff." }],
          details: { ok: false, handoff: false, reason: "user-cancelled" },
        };
      }

      const baseDir = runtimeBaseDir();
      mkdirSync(baseDir, { recursive: true });
      const handoffDir = mkdtempSync(join(baseDir, "pi-sudo-"));
      const commandPath = join(handoffDir, "command.sh");
      const runnerPath = join(handoffDir, "runner.sh");
      const logPath = join(handoffDir, "command.log");
      const statusPath = join(handoffDir, "exit-status.txt");
      const cwd = ctx.cwd;

      writeFileSync(statusPath, "running\n", "utf-8");

      writeExecutable(
        commandPath,
        `#!/usr/bin/env bash\n${command}\n`,
      );

      writeExecutable(
        runnerPath,
        `#!/usr/bin/env bash
set -uo pipefail
LOG=${shellEscape(logPath)}
STATUS=${shellEscape(statusPath)}
COMMAND=${shellEscape(commandPath)}
WORKDIR=${shellEscape(cwd)}
PREVIEW=${shellEscape(preview(command, 400))}

(
  echo "[pi-sudo] started: $(date --iso-8601=seconds)"
  echo "[pi-sudo] cwd: $WORKDIR"
  echo "[pi-sudo] authenticate in this pane if sudo prompts"
  echo "[pi-sudo] command: $PREVIEW"
  echo
  cd "$WORKDIR"
  bash "$COMMAND"
  status=$?
  printf '%s\n' "$status" > "$STATUS"
  exit "$status"
) 2>&1 | tee -a "$LOG"
status=$(cat "$STATUS" 2>/dev/null || printf '1\n')
echo
if [ "$status" -eq 0 ]; then
  echo "[pi-sudo] command completed successfully (exit 0)" | tee -a "$LOG"
  echo "[pi-sudo] log: $LOG" | tee -a "$LOG"
  echo "[pi-sudo] status: $STATUS" | tee -a "$LOG"
  echo "[pi-sudo] auto-closing pane in 15 seconds." | tee -a "$LOG"
  sleep 15
  tmux kill-pane -t "${TMUX_PANE:-}" 2>/dev/null || exit 0
else
  echo "[pi-sudo] command failed with exit $status" | tee -a "$LOG"
  echo "[pi-sudo] log: $LOG" | tee -a "$LOG"
  echo "[pi-sudo] status: $STATUS" | tee -a "$LOG"
  echo "[pi-sudo] pane left open for inspection; exit when done." | tee -a "$LOG"
  exec bash
fi
`,
      );

      const tmuxResult = await run(
        "tmux",
        [
          "split-window",
          "-h",
          "-p",
          "45",
          "-P",
          "-F",
          "#{pane_id}",
          `bash ${shellEscape(runnerPath)}`,
        ],
        signal,
      );

      if (tmuxResult.exitCode !== 0) {
        return {
          content: [{ type: "text", text: `Failed to open tmux handoff pane: ${tmuxResult.stderr || tmuxResult.stdout}` }],
          details: { ok: false, handoff: false, reason: "tmux-failed", handoffDir },
          isError: true,
        };
      }

      const paneId = (tmuxResult.stdout || "").trim() || "(unknown)";
      await run("tmux", ["select-pane", "-t", paneId, "-T", "pi-sudo [auth]"], signal);
      writeTmuxRecord({
        paneId,
        purpose: "sudo-handoff",
        titleBase: "pi-sudo",
        status: "needs-auth",
        statusPath,
        logPath,
        handoffDir,
        autoCloseOnSuccess: true,
        closeDelayMs: 15000,
        keepOpenOnFailure: true,
      });

      return {
        content: [{
          type: "text",
          text:
            `Opened privileged command in tmux pane ${paneId}.\n` +
            `Authenticate directly in that pane if prompted.\n` +
            `Log: ${logPath}\n` +
            `Status: ${statusPath}`,
        }],
        details: {
          ok: true,
          handoff: true,
          paneId,
          logPath,
          statusPath,
          handoffDir,
          commandPreview: preview(command),
        },
      };
    },
  });
}
