import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createMockExtensionAPI } from "./helpers/mock-extension-api.js";

const state = vi.hoisted(() => ({
  wikiRoot: "/tmp/wiki-root",
  host: "pad-nixos",
  digest: "",
  protectWrite: false,
  pagePath: false,
  rebuildCalls: [] as string[],
  captureCalls: [] as Array<{ wikiRoot: string; params: Record<string, unknown> }>,
  searchCalls: [] as Array<{ wikiRoot: string; query: string; options: Record<string, unknown> }>,
  ensureCalls: [] as Array<{ wikiRoot: string; params: Record<string, unknown> }>,
  lintCalls: [] as Array<{ wikiRoot: string; mode: unknown }>,
}));

vi.mock("../extension/paths.js", () => ({
  getWikiRoot: () => state.wikiRoot,
  getCurrentHost: () => state.host,
  getAllowedDomains: () => undefined,
  isProtectedPath: () => state.protectWrite,
  isWikiPagePath: () => state.pagePath,
}));

vi.mock("../extension/actions-meta.js", () => ({
  buildWikiDigest: () => state.digest,
  handleWikiStatus: () => ({ isErr: () => false, value: { text: "ok", details: { initialized: true } } }),
  loadRegistry: () => ({ version: 1, generatedAt: "now", pages: [] }),
  rebuildAllMeta: (wikiRoot: string) => {
    state.rebuildCalls.push(wikiRoot);
    return {
      registry: { version: 1, generatedAt: "now", pages: [] },
      backlinks: { version: 1, generatedAt: "now", byPath: {} },
    };
  },
}));

vi.mock("../extension/actions-capture.js", () => ({
  captureText: (wikiRoot: string, _value: string, params: Record<string, unknown>) => {
    state.captureCalls.push({ wikiRoot, params });
    return { isErr: () => false, isOk: () => true, value: { text: "captured", details: {} } };
  },
  captureFile: (wikiRoot: string, _value: string, params: Record<string, unknown>) => {
    state.captureCalls.push({ wikiRoot, params });
    return { isErr: () => false, isOk: () => true, value: { text: "captured-file", details: {} } };
  },
}));

vi.mock("../extension/actions-search.js", () => ({
  handleWikiSearch: (_registry: unknown, query: string, options: Record<string, unknown>) => {
    state.searchCalls.push({ wikiRoot: state.wikiRoot, query, options });
    return { isErr: () => false, isOk: () => true, value: { text: "search", details: {} } };
  },
}));

vi.mock("../extension/actions-pages.js", () => ({
  handleEnsurePage: (wikiRoot: string, params: Record<string, unknown>) => {
    state.ensureCalls.push({ wikiRoot, params });
    return { isErr: () => false, isOk: () => true, value: { text: "ensured", details: {} } };
  },
}));

vi.mock("../extension/actions-lint.js", () => ({
  handleWikiLint: (wikiRoot: string, mode: unknown) => {
    state.lintCalls.push({ wikiRoot, mode });
    return { isErr: () => false, isOk: () => true, value: { text: "lint", details: {} } };
  },
}));

describe("llm-wiki extension wiring", () => {
  beforeEach(() => {
    state.wikiRoot = path.join("/tmp", "llm-wiki-index-test");
    state.host = "pad-nixos";
    state.digest = "";
    state.protectWrite = false;
    state.pagePath = false;
    state.rebuildCalls = [];
    state.captureCalls = [];
    state.searchCalls = [];
    state.ensureCalls = [];
    state.lintCalls = [];
  });

  afterEach(() => {
    vi.resetModules();
  });

  async function loadExtension() {
    const api = createMockExtensionAPI();
    const mod = await import("../extension/index.js");
    mod.default(api as never);
    return api;
  }

  async function loadTool(name: string) {
    const api = await loadExtension();
    const tool = api._registeredTools.find((entry) => entry.name === name);
    if (!tool || typeof tool.execute !== "function") {
      throw new Error(`Tool ${name} not found`);
    }
    return {
      api,
      execute: tool.execute as (toolCallId: string, params: Record<string, unknown>) => Promise<{ isError?: boolean }>,
    };
  }

  it("registers all llm-wiki tools", async () => {
    const api = await loadExtension();
    expect(api._registeredTools.map((tool) => tool.name)).toEqual([
      "wiki_status",
      "wiki_capture",
      "wiki_search",
      "wiki_ensure_page",
      "wiki_lint",
      "wiki_rebuild",
    ]);
  });

  it("forwards capture metadata and rebuilds after success", async () => {
    const { execute } = await loadTool("wiki_capture");
    await execute("tool-call", {
      input_type: "text",
      value: "hello world",
      domain: "technical",
      areas: ["infrastructure"],
      hosts: ["pad-nixos"],
    });

    expect(state.captureCalls).toEqual([
      {
        wikiRoot: state.wikiRoot,
        params: {
          title: undefined,
          kind: undefined,
          tags: undefined,
          hosts: ["pad-nixos"],
          domain: "technical",
          areas: ["infrastructure"],
        },
      },
    ]);
    expect(state.rebuildCalls).toEqual([state.wikiRoot]);
  });

  it("forwards search filters", async () => {
    const { execute } = await loadTool("wiki_search");
    await execute("tool-call", {
      query: "journal",
      domain: "personal",
      areas: ["journal"],
      folder: "journal/daily",
      host_scope: "all",
    });

    expect(state.searchCalls).toEqual([
      {
        wikiRoot: state.wikiRoot,
        query: "journal",
        options: {
          type: undefined,
          limit: undefined,
          hostScope: "all",
          domain: "personal",
          areas: ["journal"],
          folder: "journal/daily",
        },
      },
    ]);
  });

  it("forwards folder and journal type to ensure page", async () => {
    const { execute } = await loadTool("wiki_ensure_page");
    await execute("tool-call", {
      type: "journal",
      title: "2026-04-19 Daily Journal",
      folder: "journal/daily",
      domain: "personal",
      areas: ["journal"],
    });

    expect(state.ensureCalls).toEqual([
      {
        wikiRoot: state.wikiRoot,
        params: {
          type: "journal",
          title: "2026-04-19 Daily Journal",
          aliases: undefined,
          tags: undefined,
          hosts: undefined,
          domain: "personal",
          areas: ["journal"],
          folder: "journal/daily",
          summary: undefined,
        },
      },
    ]);
    expect(state.rebuildCalls).toEqual([state.wikiRoot]);
  });

  it("executes wiki_status, wiki_lint, and wiki_rebuild tools", async () => {
    const status = await loadTool("wiki_status");
    await status.execute("tool-call", {});

    const lint = await loadTool("wiki_lint");
    await lint.execute("tool-call", { mode: "duplicates" });

    const rebuild = await loadTool("wiki_rebuild");
    await rebuild.execute("tool-call", {});

    expect(state.lintCalls).toEqual([{ wikiRoot: state.wikiRoot, mode: "duplicates" }]);
    expect(state.rebuildCalls).toContain(state.wikiRoot);
  });

  it("blocks writes to protected wiki paths", async () => {
    state.protectWrite = true;
    const api = await loadExtension();
    const result = await api.fireEvent("tool_call", {
      toolName: "write",
      input: { path: `${state.wikiRoot}/raw/SRC-001/manifest.json` },
    });

    expect(result).toEqual({ block: true, reason: "Wiki protects raw/ and meta/. Use wiki tools instead." });
  });

  it("returns undefined for non-protected writes and for agent_end when not dirty", async () => {
    const api = await loadExtension();
    const result = await api.fireEvent("tool_call", {
      toolName: "write",
      input: { path: `${state.wikiRoot}/pages/resources/technical/foo.md` },
    });
    expect(result).toBeUndefined();

    await api.fireEvent("agent_end");
    expect(state.rebuildCalls).toEqual([]);
  });

  it("marks page edits dirty and rebuilds on agent_end", async () => {
    state.pagePath = true;
    const api = await loadExtension();
    await api.fireEvent("tool_call", {
      toolName: "edit",
      input: { path: `${state.wikiRoot}/pages/resources/technical/foo.md` },
    });
    await api.fireEvent("agent_end");

    expect(state.rebuildCalls).toEqual([state.wikiRoot]);
  });

  it("injects wiki context and digest before agent start", async () => {
    state.digest = "\n\n[WIKI PLANNER DIGEST — pad-nixos — 2026-04-21]\n- Shared Note";
    const api = await loadExtension();
    const result = (await api.fireEvent("before_agent_start", { systemPrompt: "BASE" })) as { systemPrompt: string };

    expect(result.systemPrompt).toContain("BASE");
    expect(result.systemPrompt).toContain("Plain-Markdown wiki");
    expect(result.systemPrompt).toContain("domain: technical or personal");
    expect(result.systemPrompt).toContain("planner/tasks");
    expect(result.systemPrompt).toContain("[WIKI PLANNER DIGEST");
  });

  it("injects context even when digest is empty", async () => {
    const api = await loadExtension();
    const result = (await api.fireEvent("before_agent_start", { systemPrompt: "BASE" })) as { systemPrompt: string };
    expect(result.systemPrompt).toContain("BASE");
    expect(result.systemPrompt).toContain("[LLM WIKI CONTEXT]");
    expect(result.systemPrompt).not.toContain("[WIKI PLANNER DIGEST");
  });
});
