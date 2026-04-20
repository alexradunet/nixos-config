import { StringEnum } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { spawn } from "node:child_process";

const ACTIONS = ["list", "add", "show", "conf", "qr", "nix_snippet", "enable", "disable", "sync_nix"] as const;

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
}
