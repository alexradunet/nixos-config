import { StringEnum } from "@mariozechner/pi-ai";
import { Type } from "@sinclair/typebox";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { existsSync, readFileSync, writeFileSync, mkdirSync, mkdtempSync, chmodSync } from "node:fs";
import { join, dirname } from "node:path";
import { tmpdir } from "node:os";

const execFileAsync = promisify(execFile);
const NIXOS_UPDATE_ACTIONS = ["status", "apply", "rollback"] as const;
const SYSTEMD_ACTIONS = ["start", "stop", "restart", "status"] as const;
const PROPOSAL_ACTIONS = ["status", "validate", "diff", "commit", "push", "apply"] as const;
const ALLOWED_SYSTEMD_UNITS = new Set(["sshd", "syncthing", "reaction"]);

async function run(cmd: string, args: string[], signal?: AbortSignal, cwd?: string) {
  try {
    const result = await execFileAsync(cmd, args, {
      signal,
      cwd,
      env: process.env,
      maxBuffer: 10 * 1024 * 1024,
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

function truncate(text: string) {
  return text.length > 50_000 ? `${text.slice(0, 50_000)}\n... [truncated]` : text;
}

async function confirm(ctx: any, action: string) {
  if (!ctx.hasUI) return `Cannot perform \"${action}\" without interactive confirmation.`;
  const ok = await ctx.ui.confirm("Confirm action", `Allow: ${action}?`);
  return ok ? null : `User declined: ${action}`;
}

function shellEscape(value: string) {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

function preview(command: string, max = 140) {
  const oneLine = command.replace(/\s+/g, " ").trim();
  return oneLine.length > max ? `${oneLine.slice(0, max - 1)}…` : oneLine;
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

async function privilegedTmuxHandoff(params: {
  ctx: any;
  signal?: AbortSignal;
  command: string;
  purpose: string;
  titleBase: string;
  confirmationLabel: string;
  confirmationBody?: string;
}) {
  const { ctx, signal, command, purpose, titleBase, confirmationLabel, confirmationBody } = params;

  if (!ctx.hasUI) {
    return {
      content: [{ type: "text" as const, text: `Blocked privileged action: ${confirmationLabel} requires interactive UI for tmux handoff.` }],
      details: { ok: false, handoff: false, reason: "no-ui" },
      isError: true,
    };
  }

  if (!process.env.TMUX) {
    return {
      content: [{ type: "text" as const, text: `Blocked privileged action: ${confirmationLabel} requires PI to run inside tmux for password handoff.` }],
      details: { ok: false, handoff: false, reason: "not-in-tmux" },
      isError: true,
    };
  }

  const confirmed = await ctx.ui.confirm(
    "Open privileged command in tmux?",
    confirmationBody ?? `PI will open a tmux side pane and run:\n\n${preview(command, 220)}\n\nYou will type the sudo password directly in that pane if prompted.`,
  );
  if (!confirmed) {
    return {
      content: [{ type: "text" as const, text: `Cancelled privileged tmux handoff: ${confirmationLabel}.` }],
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
  writeExecutable(commandPath, `#!/usr/bin/env bash\n${command}\n`);
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
  tmux kill-pane -t "\${TMUX_PANE:-}" 2>/dev/null || exit 0
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
    ["split-window", "-h", "-p", "45", "-P", "-F", "#{pane_id}", `bash ${shellEscape(runnerPath)}`],
    signal,
  );

  if (tmuxResult.exitCode !== 0) {
    return {
      content: [{ type: "text" as const, text: `Failed to open tmux handoff pane: ${tmuxResult.stderr || tmuxResult.stdout}` }],
      details: { ok: false, handoff: false, reason: "tmux-failed", handoffDir },
      isError: true,
    };
  }

  const paneId = (tmuxResult.stdout || "").trim() || "(unknown)";
  await run("tmux", ["select-pane", "-t", paneId, "-T", `${titleBase} [auth]`], signal);
  writeTmuxRecord({
    paneId,
    purpose,
    titleBase,
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
      type: "text" as const,
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
}

function systemFlakeDir() {
  return join(process.env.HOME || "/home/alex", "Workspace", "NixPI");
}

function currentHostName() {
  if (process.env.HOSTNAME) return process.env.HOSTNAME;
  try {
    return readFileSync("/etc/hostname", "utf-8").trim();
  } catch {
    return "nixos";
  }
}

function currentGenerationLine(stdout: string) {
  const lines = stdout
    .trim()
    .split("\n")
    .map((line) => line.trimEnd())
    .filter(Boolean);
  if (lines.length === 0) return "No generation info available.";

  const dataLines = lines.filter((line, index) => !(index === 0 && /^Generation\b/i.test(line.trim())));
  const currentFromBooleanColumn = dataLines.find((line) => /\bTrue\s*$/.test(line));
  if (currentFromBooleanColumn) return currentFromBooleanColumn.replace(/\bTrue\s*$/, "(current)");

  const currentFromMarker = dataLines.find((line) => /\(current\)|\bcurrent\b/i.test(line));
  if (currentFromMarker) return currentFromMarker;

  return dataLines[0] ?? lines[0] ?? "No generation info available.";
}

function normalizedServiceName(service: string) {
  return service.endsWith(".service") ? service.slice(0, -8) : service;
}

function isAllowedService(service: string) {
  const normalized = normalizedServiceName(service);
  return normalized.startsWith("nixpi-") || ALLOWED_SYSTEMD_UNITS.has(normalized);
}

async function handleSystemHealth(signal?: AbortSignal) {
  const [nixos, ps, df, loadavg, meminfo, uptime] = await Promise.all([
    run("nixos-rebuild", ["list-generations"], signal),
    run("podman", ["ps", "--format", "json", "--filter", "name=nixpi-"], signal),
    run("df", ["-h", "/", "/var", "/home"], signal),
    run("cat", ["/proc/loadavg"], signal),
    run("free", ["-h", "--si"], signal),
    run("uptime", ["-p"], signal),
  ]);

  const sections: string[] = [];
  sections.push(
    nixos.exitCode === 0
      ? `## OS\nNixOS — ${currentGenerationLine(nixos.stdout)}`
      : "## OS\n(nixos-rebuild unavailable)",
  );

  if (ps.exitCode === 0) {
    try {
      const containers = JSON.parse(ps.stdout || "[]") as Array<{ Names?: string[]; Status?: string; State?: string }>;
      if (containers.length === 0) {
        sections.push("## Containers\nNo nixpi-* containers running.");
      } else {
        sections.push(
          "## Containers\n" +
            containers
              .map((c) => `- ${((c.Names ?? []).join(", ") || "unknown")}: ${c.Status ?? c.State ?? "unknown"}`)
              .join("\n"),
        );
      }
    } catch {
      sections.push("## Containers\n(parse error)");
    }
  }

  if (df.exitCode === 0) sections.push(`## Disk Usage\n\`\`\`\n${df.stdout.trim()}\n\`\`\``);

  const systemLines: string[] = [];
  if (loadavg.exitCode === 0) {
    const parts = loadavg.stdout.trim().split(/\s+/);
    systemLines.push(`- Load: ${parts.slice(0, 3).join(" ")}`);
  }
  if (uptime.exitCode === 0) systemLines.push(`- Uptime: ${uptime.stdout.trim()}`);
  if (meminfo.exitCode === 0) {
    const memLine = meminfo.stdout.split("\n").find((line) => line.startsWith("Mem:"));
    if (memLine) {
      const cols = memLine.split(/\s+/);
      systemLines.push(`- Memory: ${cols[2] ?? "?"} used / ${cols[1] ?? "?"} total`);
    }
  }
  if (systemLines.length > 0) sections.push(`## System\n${systemLines.join("\n")}`);

  return {
    content: [{ type: "text" as const, text: truncate(sections.join("\n\n")) }],
    details: { ok: true, sections },
  };
}

async function handleNixosUpdate(action: (typeof NIXOS_UPDATE_ACTIONS)[number], signal: AbortSignal | undefined, ctx: any) {
  if (action === "status") {
    const gen = await run("nixos-rebuild", ["list-generations"], signal);
    const text = gen.exitCode === 0 ? gen.stdout.trim() || "No generation info available." : gen.stderr || "Failed to list generations.";
    return {
      content: [{ type: "text" as const, text: truncate(text) }],
      details: { ok: gen.exitCode === 0, exitCode: gen.exitCode },
      ...(gen.exitCode !== 0 ? { isError: true } : {}),
    };
  }

  const denied = await confirm(ctx, `OS ${action}`);
  if (denied) {
    return { content: [{ type: "text" as const, text: denied }], details: { ok: false }, isError: true };
  }

  if (action === "rollback") {
    return privilegedTmuxHandoff({
      ctx,
      signal,
      command: "sudo nixos-rebuild switch --rollback",
      purpose: "nixos-rollback",
      titleBase: "pi-nixos",
      confirmationLabel: "OS rollback",
      confirmationBody:
        "PI will open a tmux side pane and run:\n\n" +
        "sudo nixos-rebuild switch --rollback\n\n" +
        "Type the sudo password in that pane if prompted.",
    });
  }

  const flakeDir = systemFlakeDir();
  const flakeRef = `${flakeDir}#${currentHostName()}`;
  if (!existsSync(join(flakeDir, "flake.nix"))) {
    return {
      content: [{ type: "text" as const, text: `System flake not found at ${flakeDir}.` }],
      details: { ok: false, flakeDir },
      isError: true,
    };
  }

  return privilegedTmuxHandoff({
    ctx,
    signal,
    command: `sudo nixos-rebuild switch --flake ${shellEscape(flakeRef)}`,
    purpose: "nixos-apply",
    titleBase: "pi-nixos",
    confirmationLabel: "OS apply",
    confirmationBody:
      "PI will open a tmux side pane and run:\n\n" +
      `sudo nixos-rebuild switch --flake ${flakeRef}\n\n` +
      "Type the sudo password in that pane if prompted.",
  });
}

async function handleSystemdControl(service: string, action: (typeof SYSTEMD_ACTIONS)[number], signal: AbortSignal | undefined, ctx: any) {
  if (!isAllowedService(service)) {
    return {
      content: [{ type: "text" as const, text: `Security error: service ${service} is not allowed.` }],
      details: { ok: false, validationError: true },
      isError: true,
    };
  }

  const unit = service.endsWith(".service") ? service : `${service}.service`;
  if (action !== "status") {
    const denied = await confirm(ctx, `systemctl ${action} ${unit}`);
    if (denied) {
      return { content: [{ type: "text" as const, text: denied }], details: { ok: false }, isError: true };
    }
  }

  if (action === "status") {
    const result = await run("systemctl", [action, unit, "--no-pager"], signal);
    const text = result.stdout || result.stderr || `systemctl ${action} ${unit} completed.`;
    return {
      content: [{ type: "text" as const, text: truncate(text) }],
      details: { ok: result.exitCode === 0, exitCode: result.exitCode, unit },
      ...(result.exitCode !== 0 ? { isError: true } : {}),
    };
  }

  return privilegedTmuxHandoff({
    ctx,
    signal,
    command: `sudo systemctl ${action} ${shellEscape(unit)} --no-pager`,
    purpose: "systemd-control",
    titleBase: "pi-systemd",
    confirmationLabel: `systemctl ${action} ${unit}`,
  });
}

async function handleScheduleReboot(delayMinutes: number, signal: AbortSignal | undefined, ctx: any) {
  const delay = Math.max(1, Math.min(7 * 24 * 60, Math.round(delayMinutes)));
  const denied = await confirm(ctx, `Schedule reboot in ${delay} minute(s)`);
  if (denied) {
    return { content: [{ type: "text" as const, text: denied }], details: { ok: false }, isError: true };
  }

  return privilegedTmuxHandoff({
    ctx,
    signal,
    command: `sudo shutdown -r +${delay}`,
    purpose: "schedule-reboot",
    titleBase: "pi-reboot",
    confirmationLabel: `schedule reboot in ${delay} minute(s)`,
  });
}

function updateStatusPath() {
  return join(process.env.HOME || "/tmp", ".pi", "agent", "update-status.json");
}

type UpdateStatus = {
  available: boolean;
  behindBy: number;
  checked: string;
  branch?: string;
  notified?: boolean;
};

function readUpdateStatus(): UpdateStatus | null {
  try {
    return JSON.parse(readFileSync(updateStatusPath(), "utf-8")) as UpdateStatus;
  } catch {
    return null;
  }
}

function writeUpdateStatus(status: UpdateStatus) {
  const p = updateStatusPath();
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, JSON.stringify(status, null, 2) + "\n", "utf-8");
}

async function handleUpdateStatus() {
  const status = readUpdateStatus();
  if (!status) {
    return {
      content: [{ type: "text" as const, text: "No update status available yet. The update timer may not have run." }],
      details: { ok: false },
    };
  }
  const lines = [
    `Available: ${status.available}`,
    `Behind by: ${status.behindBy} commit(s)`,
    `Checked: ${status.checked}`,
  ];
  if (status.branch) lines.push(`Branch: ${status.branch}`);
  return {
    content: [{ type: "text" as const, text: lines.join("\n") }],
    details: { ok: true, ...status },
  };
}

async function handleNixConfigProposal(
  action: (typeof PROPOSAL_ACTIONS)[number],
  signal: AbortSignal | undefined,
  ctx: any,
) {
  const repoDir = systemFlakeDir();
  if (!existsSync(join(repoDir, ".git"))) {
    return {
      content: [{ type: "text" as const, text: `NixPI repo not found at ${repoDir}. Expected a git checkout there.` }],
      details: { ok: false, repoDir },
      isError: true,
    };
  }

  if (action === "status") {
    const [branch, remote, status, log] = await Promise.all([
      run("git", ["branch", "--show-current"], signal, repoDir),
      run("git", ["remote", "-v"], signal, repoDir),
      run("git", ["status", "--short"], signal, repoDir),
      run("git", ["log", "--oneline", "-8"], signal, repoDir),
    ]);
    const lines = [
      `Repo: ${repoDir}`,
      `Branch: ${branch.stdout.trim() || "(unknown)"}`,
      `Remote: ${remote.stdout.split("\n")[0]?.trim() || "(none)"}`,
      "",
      "Working tree:",
      status.stdout.trim() || "Clean",
      "",
      "Recent commits:",
      log.stdout.trim() || "(none)",
    ];
    return {
      content: [{ type: "text" as const, text: truncate(lines.join("\n")) }],
      details: { ok: true, repoDir, clean: !status.stdout.trim() },
    };
  }

  if (action === "diff") {
    const [unstaged, staged] = await Promise.all([
      run("git", ["diff", "--stat", "HEAD"], signal, repoDir),
      run("git", ["diff", "--stat", "--cached"], signal, repoDir),
    ]);
    return {
      content: [{ type: "text" as const, text: truncate(
        `Unstaged diff:\n${unstaged.stdout.trim() || "(none)"}

Staged diff:\n${staged.stdout.trim() || "(none)"}`
      )}],
      details: { ok: true },
    };
  }

  if (action === "validate") {
    const result = await run("nix", ["flake", "check", "--no-build"], signal, repoDir);
    const ok = result.exitCode === 0;
    return {
      content: [{ type: "text" as const, text: ok
        ? `Flake check passed for ${repoDir}.`
        : truncate(`Flake check failed:\n${result.stderr || result.stdout}`),
      }],
      details: { ok, exitCode: result.exitCode },
      ...(ok ? {} : { isError: true }),
    };
  }

  if (action === "commit") {
    const statusResult = await run("git", ["status", "--short"], signal, repoDir);
    if (!statusResult.stdout.trim()) {
      return {
        content: [{ type: "text" as const, text: "Nothing to commit — working tree is clean." }],
        details: { ok: true, noop: true },
      };
    }
    const denied = await confirm(ctx, `git commit all changes in ${repoDir}`);
    if (denied) return { content: [{ type: "text" as const, text: denied }], details: { ok: false }, isError: true };

    const msg = `Update NixPI — ${new Date().toISOString().slice(0, 10)}`;
    await run("git", ["add", "-A"], signal, repoDir);
    const commit = await run("git", ["commit", "-m", msg], signal, repoDir);
    const ok = commit.exitCode === 0;
    return {
      content: [{ type: "text" as const, text: truncate(ok ? `Committed:\n${commit.stdout.trim()}` : commit.stderr || commit.stdout) }],
      details: { ok, exitCode: commit.exitCode },
      ...(ok ? {} : { isError: true }),
    };
  }

  if (action === "push") {
    const denied = await confirm(ctx, `git push from ${repoDir}`);
    if (denied) return { content: [{ type: "text" as const, text: denied }], details: { ok: false }, isError: true };

    const branch = await run("git", ["branch", "--show-current"], signal, repoDir);
    const branchName = branch.stdout.trim();
    const result = await run("git", ["push", "origin", branchName], signal, repoDir);
    const ok = result.exitCode === 0;
    return {
      content: [{ type: "text" as const, text: truncate(result.stdout || result.stderr || `Pushed ${branchName}.`) }],
      details: { ok, exitCode: result.exitCode },
      ...(ok ? {} : { isError: true }),
    };
  }

  // apply
  const denied = await confirm(ctx, `nixos-rebuild switch --flake ${repoDir}#${currentHostName()}`);
  if (denied) return { content: [{ type: "text" as const, text: denied }], details: { ok: false }, isError: true };

  const flakeRef = `${repoDir}#${currentHostName()}`;
  return privilegedTmuxHandoff({
    ctx,
    signal,
    command: `sudo nixos-rebuild switch --flake ${shellEscape(flakeRef)}`,
    purpose: "nix-config-apply",
    titleBase: "pi-apply",
    confirmationLabel: `nixos-rebuild switch --flake ${flakeRef}`,
  });
}

export default function osExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "update_status",
    label: "Update Status",
    description: "Read the NixPI update status — whether the local repo is behind its remote.",
    promptSnippet: "Use update_status to check whether there are upstream NixPI commits not yet pulled.",
    parameters: Type.Object({}),
    async execute() {
      return handleUpdateStatus();
    },
  });

  pi.registerTool({
    name: "nix_config_proposal",
    label: "Nix Config Proposal",
    description: "Inspect, validate, commit, push, and apply changes in the local NixPI repo at ~/Workspace/NixPI.",
    promptSnippet: "Use nix_config_proposal to manage the NixPI repo lifecycle — status, validate, commit, push, apply.",
    promptGuidelines: [
      "Use action=status first to understand the working tree.",
      "Use action=validate before commit or apply.",
      "Use action=commit then action=push to publish changes.",
      "Use action=apply to rebuild the current host from the repo.",
      "Always confirm with the user before commit, push, or apply.",
    ],
    parameters: Type.Object({
      action: StringEnum(PROPOSAL_ACTIONS, {
        description: "status: repo state. validate: nix flake check. diff: working tree diff. commit: stage+commit. push: push branch. apply: nixos-rebuild switch.",
      }),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      return handleNixConfigProposal(params.action, signal, ctx);
    },
  });

  pi.registerTool({
    name: "system_health",
    label: "System Health",
    description: "Composite health check: OS image status, containers, disk usage, system load, and memory.",
    promptSnippet: "Use system_health for a broad host snapshot before deeper diagnosis.",
    promptGuidelines: [
      "Run system_health first when the user asks about host state, health, or troubleshooting.",
    ],
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, signal) {
      return handleSystemHealth(signal);
    },
  });

  pi.registerTool({
    name: "nixos_update",
    label: "NixOS Update Management",
    description: "Manage NixOS updates: list generations, apply the current host flake, or rollback to the previous generation.",
    promptSnippet: "Use nixos_update to inspect generations or rebuild/rollback the current host declaratively.",
    promptGuidelines: [
      "Use action=status before apply or rollback.",
      "apply runs sudo nixos-rebuild switch against ~/Workspace/NixPI#<current-host>.",
      "rollback runs sudo nixos-rebuild switch --rollback and requires confirmation.",
    ],
    parameters: Type.Object({
      action: StringEnum(NIXOS_UPDATE_ACTIONS, {
        description: "status: list generations. apply: rebuild current host. rollback: switch to previous generation.",
      }),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      return handleNixosUpdate(params.action, signal, ctx);
    },
  });

  pi.registerTool({
    name: "schedule_reboot",
    label: "Schedule Reboot",
    description: "Schedule a system reboot after a delay in minutes.",
    promptSnippet: "Use schedule_reboot when a rebuild or maintenance flow needs a delayed restart with explicit confirmation.",
    promptGuidelines: [
      "Only use schedule_reboot after the user requests or approves a reboot.",
      "Prefer a short explicit delay like 1-5 minutes unless the user requests otherwise.",
    ],
    parameters: Type.Object({
      delay_minutes: Type.Number({ description: "Minutes to wait before rebooting", default: 1 }),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      return handleScheduleReboot(params.delay_minutes, signal, ctx);
    },
  });

  pi.registerTool({
    name: "systemd_control",
    label: "Systemd Service Control",
    description: "Manage a small allowlisted set of services: nixpi-*, sshd, syncthing, and reaction.",
    promptSnippet: "Use systemd_control for safe service inspection and minimal remediation instead of ad-hoc shell service commands.",
    promptGuidelines: [
      "Prefer action=status first.",
      "Only use mutations after the user asks or agrees.",
    ],
    parameters: Type.Object({
      service: Type.String({ description: "Service name, for example sshd, syncthing, reaction, or a nixpi-* unit." }),
      action: StringEnum(SYSTEMD_ACTIONS, { description: "Systemd action to run." }),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      return handleSystemdControl(params.service, params.action, signal, ctx);
    },
  });

  pi.on("before_agent_start", async (event) => {
    const host = currentHostName();
    const flakeDir = systemFlakeDir();
    let note = `\n\n[OS CONTEXT]\nCurrent host: ${host}\nCanonical flake repo: ${flakeDir}\nUse system_health for diagnosis and nixos_update for declarative rebuilds.`;

    const updateStatus = readUpdateStatus();
    if (updateStatus?.available && !updateStatus.notified) {
      writeUpdateStatus({ ...updateStatus, notified: true });
      note += `\n\n[UPDATE AVAILABLE] The NixPI repo is ${updateStatus.behindBy} commit(s) behind origin/${updateStatus.branch ?? "main"}. Inform the user and offer to pull and apply.`;
    }

    return { systemPrompt: event.systemPrompt + note };
  });
}
