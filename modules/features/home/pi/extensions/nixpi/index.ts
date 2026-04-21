import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

type BlueprintVersions = {
  packageVersion: string;
  seeded: Record<string, string>;
  seededHashes: Record<string, string>;
  updatesAvailable: Record<string, string>;
};

function agentDir() {
  return join(process.env.HOME || "/tmp", ".pi", "agent");
}

function versionsPath() {
  return join(agentDir(), "blueprint-versions.json");
}

function readVersions(): BlueprintVersions {
  try {
    if (!existsSync(versionsPath())) {
      return { packageVersion: "0", seeded: {}, seededHashes: {}, updatesAvailable: {} };
    }
    return JSON.parse(readFileSync(versionsPath(), "utf-8")) as BlueprintVersions;
  } catch {
    return { packageVersion: "0", seeded: {}, seededHashes: {}, updatesAvailable: {} };
  }
}

function writeVersions(versions: BlueprintVersions) {
  mkdirSync(agentDir(), { recursive: true });
  writeFileSync(versionsPath(), `${JSON.stringify(versions, null, 2)}\n`, "utf-8");
}

function renderStatus() {
  const versions = readVersions();
  const pending = Object.keys(versions.updatesAvailable);
  const seeded = Object.keys(versions.seeded);

  const lines = [
    `Blueprint package version: ${versions.packageVersion || "0"}`,
    `Seeded blueprints: ${seeded.length}`,
    `Pending updates: ${pending.length}`,
  ];

  if (pending.length > 0) {
    lines.push("", "Pending:");
    for (const key of pending) lines.push(`- ${key} -> ${versions.updatesAvailable[key]}`);
  }

  return { versions, text: lines.join("\n") };
}

export default function nixpiExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "nixpi_status",
    label: "NixPI Status",
    description: "Show local PI blueprint state for seeded files such as guardrails.",
    promptSnippet: "Use nixpi_status when the user asks about blueprint seed/update state for PI runtime files.",
    parameters: Type.Object({}),
    async execute() {
      const status = renderStatus();
      return {
        content: [{ type: "text", text: status.text }],
        details: { ok: true, ...status.versions },
      };
    },
  });

  pi.registerCommand("nixpi", {
    description: "NixPI runtime status: /nixpi status | update-blueprints",
    handler: async (args, ctx) => {
      const subcommand = args.trim().split(/\s+/)[0] || "status";
      if (subcommand === "status") {
        const status = renderStatus();
        if (ctx.hasUI) ctx.ui.notify(status.text, "info");
        return;
      }

      if (subcommand === "update-blueprints") {
        const versions = readVersions();
        const pending = Object.keys(versions.updatesAvailable);
        if (pending.length === 0) {
          if (ctx.hasUI) ctx.ui.notify("All blueprints are up to date", "info");
          return;
        }

        versions.updatesAvailable = {};
        writeVersions(versions);
        if (ctx.hasUI) {
          ctx.ui.notify("Cleared pending blueprint markers. Reload if you also changed packaged sources.", "info");
        }
        return;
      }

      if (ctx.hasUI) ctx.ui.notify("Usage: /nixpi status | update-blueprints", "warning");
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    const status = renderStatus();
    if (ctx.hasUI) {
      ctx.ui.setStatus("nixpi", `NixPI blueprints: ${Object.keys(status.versions.updatesAvailable).length} pending`);
    }
  });
}
