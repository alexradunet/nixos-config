import { StringEnum } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { spawn } from "node:child_process";

const ACTIONS = ["list", "add", "show", "conf", "qr", "nix_snippet", "enable", "disable", "sync_nix"] as const;
const ONBOARD_MODES = ["mobile", "desktop"] as const;

function buildArgs(params: {
  action: (typeof ACTIONS)[number];
  name?: string;
  ip?: string;
  png?: boolean;
}) {
  switch (params.action) {
    case "list":
      return ["list"];
    case "add":
      return ["add", params.name!, ...(params.ip ? [params.ip] : [])];
    case "show":
      return ["show", params.name!];
    case "conf":
      return ["conf", params.name!];
    case "qr":
      return ["qr", params.name!, ...(params.png ? ["--png"] : [])];
    case "nix_snippet":
      return ["nix-snippet", params.name!];
    case "enable":
      return ["enable", params.name!];
    case "disable":
      return ["disable", params.name!];
    case "sync_nix":
      return ["sync-nix"];
  }
}

function requiresName(action: (typeof ACTIONS)[number]) {
  return action !== "list" && action !== "sync_nix";
}

function buildOnboardArgs(params: {
  mode: (typeof ONBOARD_MODES)[number];
  name: string;
  ip?: string;
  rebuild?: boolean;
}) {
  return [
    params.mode === "mobile" ? "onboard-mobile" : "onboard-desktop",
    params.name,
    ...(params.ip ? [params.ip] : []),
    ...(params.rebuild ? ["--rebuild"] : []),
  ];
}

async function runWgAdmin(args: string[], cwd: string, signal: AbortSignal) {
  return await new Promise<{ stdout: string; stderr: string; exitCode: number | null }>((resolve, reject) => {
    const child = spawn("wg-admin", args, {
      cwd,
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    const onAbort = () => {
      child.kill("SIGTERM");
    };

    signal.addEventListener("abort", onAbort, { once: true });

    child.on("error", (error) => {
      signal.removeEventListener("abort", onAbort);
      reject(error);
    });

    child.on("close", (exitCode) => {
      signal.removeEventListener("abort", onAbort);
      resolve({ stdout: stdout.trim(), stderr: stderr.trim(), exitCode });
    });
  });
}

export default function wireguardAdminExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "wg_admin",
    label: "WireGuard Admin",
    description:
      "Manage the local wg-admin WireGuard peer registry on the canonical hub. Use for listing peers, adding devices, generating configs or QR paths, showing Nix snippets, and enabling/disabling peers.",
    promptSnippet:
      "Use wg_admin for structured WireGuard peer management on the hub instead of ad-hoc shell commands when you need peer listings, config generation, QR export paths, or Nix snippets.",
    promptGuidelines: [
      "Use action=list before making assumptions about existing peers.",
      "Use action=add to create a new peer and allocate an IP when onboarding a device.",
      "Use action=nix_snippet after add when the user wants the declarative peer block to copy into Nix.",
      "Use action=sync_nix to fully regenerate the dedicated Nix peer inventory file from the runtime registry.",
      "Use action=qr with png=true when the user explicitly wants a PNG QR path; otherwise qr returns the terminal QR.",
    ],
    parameters: Type.Object({
      action: StringEnum(ACTIONS, { description: "WireGuard admin action to run" }),
      name: Type.Optional(Type.String({ description: "Peer name for all actions except list" })),
      ip: Type.Optional(Type.String({ description: "Optional IPv4 address to assign when adding a peer" })),
      png: Type.Optional(Type.Boolean({ description: "When action=qr, generate a PNG file and return its path instead of terminal QR output" })),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      if (requiresName(params.action) && !params.name) {
        return {
          content: [{ type: "text", text: `Action ${params.action} requires a peer name.` }],
          details: { ok: false, validationError: true },
        };
      }

      try {
        const args = buildArgs(params);
        const result = await runWgAdmin(args, ctx.cwd, signal);
        const output = [result.stdout, result.stderr].filter(Boolean).join("\n\n").trim();

        if (result.exitCode !== 0) {
          return {
            content: [{ type: "text", text: output || `wg-admin exited with code ${result.exitCode}` }],
            details: { ok: false, exitCode: result.exitCode, args },
          };
        }

        return {
          content: [{ type: "text", text: output || "wg-admin completed successfully." }],
          details: { ok: true, exitCode: result.exitCode, args },
        };
      } catch (error: any) {
        return {
          content: [
            {
              type: "text",
              text: `Failed to run wg-admin. Ensure it is installed on this host (expected on vps-nixos). Error: ${error.message}`,
            },
          ],
          details: { ok: false, error: true },
        };
      }
    },
  });

  pi.registerTool({
    name: "wg_onboard",
    label: "WireGuard Onboard",
    description:
      "High-level WireGuard onboarding helper for the canonical hub. Use this when the user wants to add a mobile device and get a QR path, add a desktop and get a config path, and optionally rebuild vps-nixos afterwards.",
    promptSnippet:
      "Use wg_onboard for the common workflows: add a phone peer and emit QR artifacts, add a desktop peer and emit config artifacts, and optionally rebuild the vps-nixos hub.",
    promptGuidelines: [
      "Use mode=mobile for phones and tablets; it returns QR and config artifact paths.",
      "Use mode=desktop for laptops and desktops; it returns the generated config path.",
      "Set rebuild=true when the user explicitly wants the hub rebuilt after onboarding.",
    ],
    parameters: Type.Object({
      mode: StringEnum(ONBOARD_MODES, { description: "Whether the new peer is a mobile or desktop-style device" }),
      name: Type.String({ description: "Stable peer name, for example iphone-alex or macbook-air" }),
      ip: Type.Optional(Type.String({ description: "Optional explicit IPv4 address to assign" })),
      rebuild: Type.Optional(Type.Boolean({ description: "Whether to rebuild vps-nixos after the peer and Nix inventory are updated" })),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      try {
        const args = buildOnboardArgs(params);
        const result = await runWgAdmin(args, ctx.cwd, signal);
        const output = [result.stdout, result.stderr].filter(Boolean).join("\n\n").trim();

        if (result.exitCode !== 0) {
          return {
            content: [{ type: "text", text: output || `wg-admin exited with code ${result.exitCode}` }],
            details: { ok: false, exitCode: result.exitCode, args },
          };
        }

        return {
          content: [{ type: "text", text: output || "wg-admin onboarding completed successfully." }],
          details: { ok: true, exitCode: result.exitCode, args },
        };
      } catch (error: any) {
        return {
          content: [
            {
              type: "text",
              text: `Failed to run wg-admin onboarding. Ensure it is installed on vps-nixos. Error: ${error.message}`,
            },
          ],
          details: { ok: false, error: true },
        };
      }
    },
  });

  pi.registerCommand("wg-onboard", {
    description: "Onboard a peer via wg-admin: /wg-onboard <mobile|desktop> <name> [ip] [--rebuild]",
    handler: async (args, ctx) => {
      const parts = args.trim().split(/\s+/).filter(Boolean);
      if (parts.length < 2) {
        ctx.ui.notify("Usage: /wg-onboard <mobile|desktop> <name> [ip] [--rebuild]", "warning");
        return;
      }

      const mode = parts[0] as (typeof ONBOARD_MODES)[number];
      if (!ONBOARD_MODES.includes(mode)) {
        ctx.ui.notify("First argument must be mobile or desktop", "warning");
        return;
      }

      const rebuild = parts.includes("--rebuild");
      const name = parts[1];
      const ip = parts[2] && parts[2] !== "--rebuild" ? parts[2] : undefined;
      const result = await runWgAdmin(buildOnboardArgs({ mode, name, ip, rebuild }), ctx.cwd, AbortSignal.timeout(10 * 60 * 1000));
      const output = [result.stdout, result.stderr].filter(Boolean).join("\n\n").trim();
      ctx.ui.notify(output || `wg-admin exited with code ${result.exitCode}`, result.exitCode === 0 ? "success" : "error");
    },
  });

  pi.registerCommand("wg-rebuild", {
    description: "Rebuild the canonical vps-nixos hub after wg-admin changes",
    handler: async (_args, ctx) => {
      const result = await runWgAdmin(["rebuild"], ctx.cwd, AbortSignal.timeout(20 * 60 * 1000));
      const output = [result.stdout, result.stderr].filter(Boolean).join("\n\n").trim();
      ctx.ui.notify(output || `wg-admin exited with code ${result.exitCode}`, result.exitCode === 0 ? "success" : "error");
    },
  });
}
