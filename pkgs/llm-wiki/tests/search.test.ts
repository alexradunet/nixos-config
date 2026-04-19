import { describe, expect, it } from "vitest";
import { handleWikiSearch, searchRegistry } from "../extension/actions-search.js";
import type { RegistryData, RegistryEntry } from "../extension/types.js";

function makeEntry(overrides: Partial<RegistryEntry>): RegistryEntry {
  return {
    type: "concept",
    path: "pages/resources/technical/default.md",
    folder: "resources/technical",
    title: "Default",
    aliases: [],
    summary: "",
    status: "active",
    tags: [],
    hosts: [],
    domain: "technical",
    areas: ["infrastructure"],
    updated: "2026-04-19",
    sourceIds: [],
    linksOut: [],
    headings: [],
    wordCount: 10,
    ...overrides,
  };
}

function makeRegistry(pages: RegistryEntry[]): RegistryData {
  return {
    version: 1,
    generatedAt: new Date().toISOString(),
    pages,
  };
}

describe("searchRegistry", () => {
  it("ranks exact title matches first", () => {
    const registry = makeRegistry([
      makeEntry({ title: "Attention Mechanism", path: "pages/resources/technical/attention-mechanism.md" }),
      makeEntry({ title: "Attention", path: "pages/resources/technical/attention.md" }),
    ]);

    const result = searchRegistry(registry, "Attention");
    expect(result.matches[0]?.title).toBe("Attention");
    expect(result.matches[0]?.score).toBeGreaterThanOrEqual(120);
  });

  it("can find by alias, domain, and area", () => {
    const registry = makeRegistry([
      makeEntry({
        title: "Flake Patterns",
        aliases: ["nix flakes"],
        domain: "technical",
        areas: ["nixos", "infrastructure"],
        path: "pages/resources/technical/flake-patterns.md",
      }),
    ]);

    expect(searchRegistry(registry, "nix flakes").matches[0]?.title).toBe("Flake Patterns");
    expect(searchRegistry(registry, "technical", { domain: "technical" }).matches[0]?.title).toBe("Flake Patterns");
    expect(searchRegistry(registry, "nixos", { areas: ["nixos"] }).matches[0]?.title).toBe("Flake Patterns");
  });

  it("filters by folder, host, and domain", () => {
    const registry = makeRegistry([
      makeEntry({
        title: "pad Host Notes",
        path: "pages/resources/technical/pad.md",
        folder: "resources/technical",
        hosts: ["pad-nixos"],
        domain: "technical",
      }),
      makeEntry({
        title: "Personal Identity",
        type: "identity",
        path: "pages/areas/personal/personal-identity.md",
        folder: "areas/personal",
        domain: "personal",
        areas: ["identity"],
      }),
    ]);

    expect(searchRegistry(registry, "notes", { folder: "resources/technical", host: "pad-nixos" }).matches).toHaveLength(1);
    expect(searchRegistry(registry, "notes", { folder: "resources/technical", host: "evo-nixos" }).matches).toHaveLength(0);
    expect(searchRegistry(registry, "identity", { domain: "personal" }).matches[0]?.title).toBe("Personal Identity");
  });

  it("includes host-specific pages only in hostScope=all or matching host", () => {
    const registry = makeRegistry([
      makeEntry({ title: "Shared", path: "pages/resources/technical/shared.md", hosts: [] }),
      makeEntry({ title: "Laptop", path: "pages/resources/technical/laptop.md", hosts: ["pad-nixos"] }),
    ]);

    expect(searchRegistry(registry, "laptop", { host: "evo-nixos" }).matches).toHaveLength(0);
    expect(searchRegistry(registry, "laptop", { host: "evo-nixos", hostScope: "all" }).matches).toHaveLength(1);
  });
});

describe("handleWikiSearch", () => {
  it("renders scope info in successful search output", () => {
    const registry = makeRegistry([
      makeEntry({ title: "Daily Journal", type: "journal", path: "pages/journal/daily/2026-04-19.md", folder: "journal/daily", domain: "personal", areas: ["journal"] }),
    ]);

    const result = handleWikiSearch(registry, "daily", {
      domain: "personal",
      areas: ["journal"],
      folder: "journal/daily",
      host: "pad-nixos",
    });

    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.text).toContain("domain=personal");
      expect(result.value.text).toContain("areas=journal");
      expect(result.value.text).toContain("folder=journal/daily");
    }
  });

  it("renders no-match output with scope info", () => {
    const result = handleWikiSearch(makeRegistry([]), "ghost", { domain: "technical", folder: "resources/technical" });
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.text).toContain("No wiki matches");
      expect(result.value.text).toContain("domain=technical");
      expect(result.value.text).toContain("folder=resources/technical");
    }
  });
});
