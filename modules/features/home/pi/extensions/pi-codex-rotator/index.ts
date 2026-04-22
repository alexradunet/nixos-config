import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";

interface AccountEntry {
  name: string;
  provider?: string;
  model?: string;
  email?: string;
  auth?: {
    access: string;
    refresh?: string;
    expires?: number;
    accountId?: string;
    type?: string;
  };
}

interface RotatorConfig {
  provider: string;
  model: string;
  autoSwitchOn429: boolean;
  accounts: AccountEntry[];
}

interface RotatorState {
  activeAccount?: string;
  lastSwitchAt?: string;
}

const DEFAULT_PROVIDER = "openai-codex";
const DEFAULT_MODEL = "gpt-5.4";

function ensureDir(path: string) {
  mkdirSync(path, { recursive: true });
}

function readJsonFile<T>(path: string, fallback: T): T {
  try {
    if (!existsSync(path)) return fallback;
    return JSON.parse(readFileSync(path, "utf8")) as T;
  } catch (error) {
    console.error(`[pi-codex-rotator] Failed to read ${path}:`, error);
    return fallback;
  }
}

function writeJsonFile(path: string, value: unknown) {
  ensureDir(dirname(path));
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function getPaths() {
  const agentDir = getAgentDir();
  const dataDir = join(agentDir, "data", "pi-codex-rotator");
  return {
    agentDir,
    dataDir,
    authPath: join(agentDir, "auth.json"),
    settingsPath: join(agentDir, "settings.json"),
    configPath: join(dataDir, "accounts.json"),
    statePath: join(dataDir, "state.json"),
  };
}

function loadConfig(): RotatorConfig {
  const { configPath, authPath } = getPaths();
  const auth = readJsonFile<Record<string, any>>(authPath, {});

  const fallback: RotatorConfig = {
    provider: DEFAULT_PROVIDER,
    model: DEFAULT_MODEL,
    autoSwitchOn429: false,
    accounts: auth[DEFAULT_PROVIDER]
      ? [
          {
            name: "default",
            provider: DEFAULT_PROVIDER,
            model: DEFAULT_MODEL,
            auth: {
              type: auth[DEFAULT_PROVIDER].type ?? "oauth",
              access: auth[DEFAULT_PROVIDER].access,
              refresh: auth[DEFAULT_PROVIDER].refresh,
              expires: auth[DEFAULT_PROVIDER].expires,
              accountId: auth[DEFAULT_PROVIDER].accountId,
            },
          },
        ]
      : [],
  };

  const config = readJsonFile<RotatorConfig>(configPath, fallback);
  config.provider ||= DEFAULT_PROVIDER;
  config.model ||= DEFAULT_MODEL;
  config.autoSwitchOn429 ??= false;
  config.accounts ||= [];
  return config;
}

function loadState(): RotatorState {
  const { statePath } = getPaths();
  return readJsonFile<RotatorState>(statePath, {});
}

function saveState(state: RotatorState) {
  const { statePath } = getPaths();
  writeJsonFile(statePath, state);
}

function saveConfig(config: RotatorConfig) {
  const { configPath } = getPaths();
  writeJsonFile(configPath, config);
}

function decodeJwtPayload(token: string): any | undefined {
  try {
    const parts = token.split(".");
    if (parts.length < 2) return undefined;
    const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64 + "=".repeat((4 - (base64.length % 4 || 4)) % 4);
    return JSON.parse(Buffer.from(padded, "base64").toString("utf8"));
  } catch {
    return undefined;
  }
}

function getEmailFromAccessToken(access: string): string | undefined {
  const payload = decodeJwtPayload(access);
  return payload?.["https://api.openai.com/profile"]?.email ?? payload?.email;
}

function getCurrentProviderAuth(provider: string): AccountEntry["auth"] | undefined {
  const { authPath } = getPaths();
  const auth = readJsonFile<Record<string, any>>(authPath, {});
  const entry = auth[provider];
  if (!entry?.access) return undefined;

  return {
    type: entry.type ?? "oauth",
    access: entry.access,
    refresh: entry.refresh,
    expires: entry.expires,
    accountId: entry.accountId,
  };
}

function upsertAccount(config: RotatorConfig, account: AccountEntry): { config: RotatorConfig; replaced: boolean } {
  const index = config.accounts.findIndex((entry) => entry.name === account.name);
  if (index >= 0) {
    const next = [...config.accounts];
    next[index] = account;
    return { config: { ...config, accounts: next }, replaced: true };
  }

  return { config: { ...config, accounts: [...config.accounts, account] }, replaced: false };
}

function removeAccount(config: RotatorConfig, name: string): { config: RotatorConfig; removed: boolean } {
  const next = config.accounts.filter((entry) => entry.name !== name);
  return { config: { ...config, accounts: next }, removed: next.length !== config.accounts.length };
}

function getActiveAccount(config: RotatorConfig, state: RotatorState): AccountEntry | undefined {
  if (state.activeAccount) {
    const found = config.accounts.find((account) => account.name === state.activeAccount);
    if (found) return found;
  }
  return config.accounts[0];
}

function updateStatus(ctx: ExtensionContext, config: RotatorConfig, state: RotatorState, pendingName?: string) {
  const active = getActiveAccount(config, state);
  if (pendingName) {
    ctx.ui.setStatus("codex-rotator", ctx.ui.theme.fg("warning", `codex:pending ${pendingName}`));
    return;
  }
  if (!active) {
    ctx.ui.setStatus("codex-rotator", ctx.ui.theme.fg("warning", "codex:none"));
    return;
  }

  const provider = active.provider ?? config.provider;
  const model = active.model ?? config.model;
  ctx.ui.setStatus("codex-rotator", ctx.ui.theme.fg("accent", `codex:${active.name} ${provider}/${model}`));
}

async function applyAccount(account: AccountEntry, config: RotatorConfig, state: RotatorState, ctx?: ExtensionContext) {
  const { authPath, settingsPath } = getPaths();
  const auth = readJsonFile<Record<string, any>>(authPath, {});
  const settings = readJsonFile<Record<string, any>>(settingsPath, {});

  const provider = account.provider ?? config.provider;
  const model = account.model ?? config.model;

  if (!account.auth?.access) {
    throw new Error(`Account \"${account.name}\" has no auth.access token`);
  }

  auth[provider] = {
    type: account.auth.type ?? "oauth",
    access: account.auth.access,
    refresh: account.auth.refresh,
    expires: account.auth.expires,
    accountId: account.auth.accountId,
  };

  settings.defaultProvider = provider;
  settings.defaultModel = model;

  writeJsonFile(authPath, auth);
  writeJsonFile(settingsPath, settings);

  state.activeAccount = account.name;
  state.lastSwitchAt = new Date().toISOString();
  saveState(state);

  if (ctx) {
    const resolved = ctx.modelRegistry.find(provider, model);
    if (resolved) await piSetModelSafe(ctx, resolved);
    updateStatus(ctx, config, state);
    ctx.ui.notify(`Switched Codex account to ${account.name}`, "success");
  }
}

async function piSetModelSafe(ctx: ExtensionContext, model: any) {
  try {
    await (ctx as any).pi?.setModel?.(model);
  } catch {
    // best effort only
  }
}

export default function codexRotator(pi: ExtensionAPI) {
  let config = loadConfig();
  let state = loadState();
  let switching = false;
  let pendingCaptureName: string | undefined;

  async function saveCurrentAs(name: string, ctx: ExtensionContext) {
    config = loadConfig();
    state = loadState();

    const provider = config.provider || DEFAULT_PROVIDER;
    const auth = getCurrentProviderAuth(provider);
    if (!auth) {
      ctx.ui.notify(`No live ${provider} auth found in ${getPaths().authPath}`, "error");
      return false;
    }

    const { config: nextConfig, replaced } = upsertAccount(config, {
      name,
      provider,
      model: config.model || DEFAULT_MODEL,
      email: getEmailFromAccessToken(auth.access),
      auth,
    });

    saveConfig(nextConfig);
    config = nextConfig;

    ctx.ui.notify(replaced ? `Updated account ${name}` : `Added account ${name}`, "success");
    updateStatus(ctx, config, state);
    return true;
  }

  async function switchTo(name: string, ctx: ExtensionContext) {
    config = loadConfig();
    state = loadState();

    const account = config.accounts.find((entry) => entry.name === name);
    if (!account) {
      ctx.ui.notify(`Unknown account: ${name}`, "error");
      return;
    }

    await applyAccount(account, config, state, ctx);
  }

  async function switchNext(ctx: ExtensionContext) {
    config = loadConfig();
    state = loadState();

    if (config.accounts.length === 0) {
      ctx.ui.notify(`No accounts configured in ${getPaths().configPath}`, "warning");
      return;
    }

    const currentIndex = config.accounts.findIndex((entry) => entry.name === state.activeAccount);
    const nextIndex = currentIndex === -1 ? 0 : (currentIndex + 1) % config.accounts.length;
    await applyAccount(config.accounts[nextIndex], config, state, ctx);
  }

  pi.registerCommand("codex-list", {
    description: "List configured Codex OAuth accounts",
    handler: async (_args, ctx) => {
      config = loadConfig();
      state = loadState();

      if (config.accounts.length === 0) {
        ctx.ui.notify(`No accounts configured yet. Use /codex-add or /codex-login. Data path: ${getPaths().configPath}`, "warning");
        return;
      }

      const lines = config.accounts.map((account, index) => {
        const active = account.name === state.activeAccount || (!state.activeAccount && index === 0);
        const email = account.email ? ` <${account.email}>` : "";
        return `${active ? "*" : "-"} ${account.name}${email} (${account.provider ?? config.provider}/${account.model ?? config.model})`;
      });

      ctx.ui.notify(lines.join("\n"), "info");
      updateStatus(ctx, config, state);
    },
  });

  pi.registerCommand("codex-add", {
    description: "Save the current live Codex OAuth auth as a named rotator account",
    handler: async (args, ctx) => {
      let name = args?.trim();
      if (!name) {
        name = (await ctx.ui.input("Account name", {
          placeholder: "work | personal | alt",
        }))?.trim();
      }
      if (!name) {
        ctx.ui.notify("Cancelled", "warning");
        return;
      }

      await saveCurrentAs(name, ctx);
    },
  });

  pi.registerCommand("codex-login-new-account", {
    description: "Stage capture for a new Codex account, then complete /login openai-codex",
    handler: async (args, ctx) => {
      let name = args?.trim();
      if (!name) {
        name = (await ctx.ui.input("New account name", {
          placeholder: "work | personal | alt",
        }))?.trim();
      }
      if (!name) {
        ctx.ui.notify("Cancelled", "warning");
        return;
      }

      pendingCaptureName = name;
      updateStatus(ctx, config, state, pendingCaptureName);
      ctx.ui.notify(`Run /login openai-codex now. After login succeeds, this extension will capture it as ${name}.`, "info");
      pi.appendEntry("codex-login-helper", {
        pendingCaptureName: name,
        instruction: `Run /login openai-codex now. After login finishes, the rotator will save it as ${name}.`,
      });
    },
  });

  pi.registerCommand("codex-login", {
    description: "Manage Codex accounts: current, switch, add, remove",
    handler: async (_args, ctx) => {
      config = loadConfig();
      state = loadState();
      updateStatus(ctx, config, state);

      const choice = await ctx.ui.select("Codex account manager", [
        "Current account",
        "Switch account",
        "Add new account",
        "Remove account",
        "Cancel",
      ]);

      if (choice === "Current account") {
        if (pendingCaptureName) {
          ctx.ui.notify(`Pending capture: ${pendingCaptureName}. Run /login openai-codex to finish adding it.`, "warning");
          return;
        }
        const active = getActiveAccount(config, state);
        if (!active) {
          ctx.ui.notify(`No active account. Configure ${getPaths().configPath}`, "warning");
          return;
        }
        const email = active.email ? ` <${active.email}>` : "";
        ctx.ui.notify(`Active: ${active.name}${email} (${active.provider ?? config.provider}/${active.model ?? config.model})`, "info");
        return;
      }

      if (choice === "Switch account") {
        if (config.accounts.length === 0) {
          ctx.ui.notify(`No accounts configured in ${getPaths().configPath}`, "warning");
          return;
        }
        const options = config.accounts.map((account, index) => {
          const active = account.name === state.activeAccount || (!state.activeAccount && index === 0);
          const email = account.email ? ` <${account.email}>` : "";
          return `${active ? "* " : ""}${account.name}${email}`;
        });
        const picked = await ctx.ui.select("Switch Codex account", [...options, "Cancel"]);
        if (!picked || picked === "Cancel") return;
        const name = picked.replace(/^\*\s+/, "").split(" <")[0];
        await switchTo(name, ctx);
        return;
      }

      if (choice === "Add new account") {
        const name = (await ctx.ui.input("New account name", {
          placeholder: "work | personal | alt",
        }))?.trim();
        if (!name) {
          ctx.ui.notify("Cancelled", "warning");
          return;
        }
        pendingCaptureName = name;
        updateStatus(ctx, config, state, pendingCaptureName);
        ctx.ui.notify(`Now run /login openai-codex. After login succeeds, the account will be captured as ${name}.`, "info");
        return;
      }

      if (choice === "Remove account") {
        if (config.accounts.length === 0) {
          ctx.ui.notify(`No accounts configured in ${getPaths().configPath}`, "warning");
          return;
        }
        const options = config.accounts.map((account) => `${account.name}${account.email ? ` <${account.email}>` : ""}`);
        const picked = await ctx.ui.select("Remove Codex account", [...options, "Cancel"]);
        if (!picked || picked === "Cancel") return;
        const name = picked.split(" <")[0];
        config = loadConfig();
        state = loadState();
        const { config: nextConfig, removed } = removeAccount(config, name);
        if (!removed) {
          ctx.ui.notify(`Unknown account: ${name}`, "warning");
          return;
        }
        saveConfig(nextConfig);
        config = nextConfig;
        if (state.activeAccount === name) {
          delete state.activeAccount;
          saveState(state);
        }
        ctx.ui.notify(`Removed account ${name}`, "success");
        updateStatus(ctx, config, state);
        return;
      }
    },
  });

  pi.registerCommand("codex-remove", {
    description: "Remove a named rotator account",
    getArgumentCompletions: (prefix: string) => {
      const current = loadConfig();
      return current.accounts
        .filter((account) => account.name.startsWith(prefix))
        .map((account) => ({ value: account.name, label: account.name }));
    },
    handler: async (args, ctx) => {
      const name = args?.trim();
      if (!name) {
        ctx.ui.notify("Usage: /codex-remove <account>", "warning");
        return;
      }

      config = loadConfig();
      state = loadState();

      const { config: nextConfig, removed } = removeAccount(config, name);
      if (!removed) {
        ctx.ui.notify(`Unknown account: ${name}`, "warning");
        return;
      }

      saveConfig(nextConfig);
      config = nextConfig;

      if (state.activeAccount === name) {
        delete state.activeAccount;
        saveState(state);
      }

      ctx.ui.notify(`Removed account ${name}`, "success");
      updateStatus(ctx, config, state);
    },
  });

  pi.registerCommand("codex-use", {
    description: "Switch to a configured Codex OAuth account",
    getArgumentCompletions: (prefix: string) => {
      const current = loadConfig();
      return current.accounts
        .filter((account) => account.name.startsWith(prefix))
        .map((account) => ({ value: account.name, label: account.name }));
    },
    handler: async (args, ctx) => {
      let name = args?.trim();
      if (!name) {
        config = loadConfig();
        state = loadState();
        if (config.accounts.length === 0) {
          ctx.ui.notify(`No accounts configured in ${getPaths().configPath}`, "warning");
          return;
        }
        const options = config.accounts.map((account, index) => {
          const active = account.name === state.activeAccount || (!state.activeAccount && index === 0);
          const email = account.email ? ` <${account.email}>` : "";
          return `${active ? "* " : ""}${account.name}${email}`;
        });
        const picked = await ctx.ui.select("Switch Codex account", [...options, "Cancel"]);
        if (!picked || picked === "Cancel") return;
        name = picked.replace(/^\*\s+/, "").split(" <")[0];
      }
      await switchTo(name, ctx);
    },
  });

  pi.registerCommand("codex-next", {
    description: "Rotate to the next configured Codex OAuth account",
    handler: async (_args, ctx) => {
      await switchNext(ctx);
    },
  });

  pi.registerCommand("codex-status", {
    description: "Show active Codex rotator account",
    handler: async (_args, ctx) => {
      config = loadConfig();
      state = loadState();
      const active = getActiveAccount(config, state);
      if (!active) {
        ctx.ui.notify(`No active account. Accounts live in ${getPaths().configPath}`, "warning");
        return;
      }
      const email = active.email ? ` <${active.email}>` : "";
      ctx.ui.notify(`Active: ${active.name}${email} (${active.provider ?? config.provider}/${active.model ?? config.model})`, "info");
      updateStatus(ctx, config, state);
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    config = loadConfig();
    state = loadState();
    updateStatus(ctx, config, state);
  });

  pi.on("after_provider_response", async (event, ctx) => {
    config = loadConfig();
    state = loadState();
    updateStatus(ctx, config, state);

    if (!config.autoSwitchOn429 || switching) return;
    const active = getActiveAccount(config, state);
    if (!active) return;

    if (event.status === 429 && config.accounts.length > 1) {
      switching = true;
      try {
        ctx.ui.notify(`429 from provider, rotating Codex account...`, "warning");
        await switchNext(ctx);
      } finally {
        switching = false;
      }
    }
  });

  pi.on("model_select", async (event, ctx) => {
    config = loadConfig();
    state = loadState();
    updateStatus(ctx, config, state);

    if (pendingCaptureName && event.model.provider === (config.provider || DEFAULT_PROVIDER)) {
      const name = pendingCaptureName;
      pendingCaptureName = undefined;
      await saveCurrentAs(name, ctx);
      updateStatus(ctx, config, state);
    }
  });
}
