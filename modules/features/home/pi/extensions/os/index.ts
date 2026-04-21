import { StringEnum } from "@mariozechner/pi-ai";
import { Type } from "@sinclair/typebox";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const execFileAsync = promisify(execFile);
const NIXOS_UPDATE_ACTIONS = ["status", "apply", "rollback"] as const;
const SYSTEMD_ACTIONS = ["start", "stop", "restart", "status"] as const;
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
    const result = await run("sudo", ["nixos-rebuild", "switch", "--rollback"], signal);
    const text = result.stdout || result.stderr || "Rollback completed.";
    return {
      content: [{ type: "text" as const, text: truncate(text) }],
      details: { ok: result.exitCode === 0, exitCode: result.exitCode },
      ...(result.exitCode !== 0 ? { isError: true } : {}),
    };
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

  const result = await run("sudo", ["nixos-rebuild", "switch", "--flake", flakeRef], signal);
  const text = result.stdout || result.stderr || `Applied ${flakeRef}.`;
  return {
    content: [{ type: "text" as const, text: truncate(text) }],
    details: { ok: result.exitCode === 0, exitCode: result.exitCode, flakeRef },
    ...(result.exitCode !== 0 ? { isError: true } : {}),
  };
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

  const command = action === "status" ? "systemctl" : "sudo";
  const args = action === "status" ? [action, unit, "--no-pager"] : ["systemctl", action, unit, "--no-pager"];
  const result = await run(command, args, signal);
  const text = result.stdout || result.stderr || `systemctl ${action} ${unit} completed.`;
  return {
    content: [{ type: "text" as const, text: truncate(text) }],
    details: { ok: result.exitCode === 0, exitCode: result.exitCode, unit },
    ...(result.exitCode !== 0 ? { isError: true } : {}),
  };
}

export default function osExtension(pi: ExtensionAPI) {
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
    const note = `\n\n[OS CONTEXT]\nCurrent host: ${host}\nCanonical flake repo: ${flakeDir}\nUse system_health for diagnosis and nixos_update for declarative rebuilds.`;
    return { systemPrompt: event.systemPrompt + note };
  });
}
