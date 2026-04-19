import { existsSync, mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { captureFile, captureText } from "../extension/actions-capture.js";
import { handleWikiLint } from "../extension/actions-lint.js";
import { rebuildAllMeta } from "../extension/actions-meta.js";
import { handleEnsurePage } from "../extension/actions-pages.js";

describe("capture, pages, and lint", () => {
  let wikiRoot: string;

  beforeEach(() => {
    wikiRoot = mkdtempSync(path.join(os.tmpdir(), "llm-wiki-actions-"));
    mkdirSync(path.join(wikiRoot, "raw"), { recursive: true });
    mkdirSync(path.join(wikiRoot, "pages", "sources"), { recursive: true });
    mkdirSync(path.join(wikiRoot, "meta"), { recursive: true });
  });

  afterEach(() => {
    rmSync(wikiRoot, { recursive: true, force: true });
  });

  it("captureText creates packet and source page with domain, areas, and hosts", () => {
    const result = captureText(wikiRoot, "Captured body", {
      title: "Captured Note",
      kind: "note",
      tags: ["capture"],
      hosts: ["pad-nixos"],
      domain: "technical",
      areas: ["infrastructure", "ai"],
    });

    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      const packetDir = path.join(wikiRoot, result.value.details?.packetDir ?? "");
      const pagePath = path.join(wikiRoot, result.value.details?.sourcePagePath ?? "");
      expect(existsSync(path.join(packetDir, "manifest.json"))).toBe(true);
      expect(existsSync(path.join(packetDir, "extracted.md"))).toBe(true);
      expect(existsSync(pagePath)).toBe(true);
      const page = readFileSync(pagePath, "utf8");
      expect(page).toContain("domain: technical");
      expect(page).toContain("areas:");
      expect(page).toContain("- infrastructure");
      expect(page).toContain("hosts:");
      expect(page).toContain("- pad-nixos");
    }
  });

  it("captureFile copies the original and rejects binary/pdf input", () => {
    const sourceFile = path.join(wikiRoot, "input.txt");
    writeFileSync(sourceFile, "hello", "utf8");

    const okResult = captureFile(wikiRoot, sourceFile, { domain: "personal", areas: ["journal"] });
    expect(okResult.isOk()).toBe(true);
    if (okResult.isOk()) {
      expect(existsSync(path.join(wikiRoot, okResult.value.details?.packetDir ?? "", "original", "source.txt"))).toBe(true);
    }

    const pdfFile = path.join(wikiRoot, "input.pdf");
    writeFileSync(pdfFile, Buffer.from([0x25, 0x50, 0x44, 0x46]));
    expect(captureFile(wikiRoot, pdfFile).isErr()).toBe(true);

    const binaryFile = path.join(wikiRoot, "input.bin");
    writeFileSync(binaryFile, Buffer.from([0xff, 0xfe, 0x00]));
    expect(captureFile(wikiRoot, binaryFile).isErr()).toBe(true);
  });

  it("handleEnsurePage creates notes in requested folder with metadata", () => {
    rebuildAllMeta(wikiRoot);
    const result = handleEnsurePage(wikiRoot, {
      type: "concept",
      title: "Flake Patterns",
      domain: "technical",
      areas: ["nixos"],
      folder: "resources/technical",
      hosts: ["pad-nixos"],
      summary: "Patterns for flakes",
    });

    expect(result.isOk()).toBe(true);
    if (result.isOk() && result.value.details?.resolved && !result.value.details.conflict) {
      expect(result.value.details.path).toBe("pages/resources/technical/flake-patterns.md");
      const content = readFileSync(path.join(wikiRoot, result.value.details.path), "utf8");
      expect(content).toContain("domain: technical");
      expect(content).toContain("- nixos");
      expect(content).toContain("- pad-nixos");
      expect(content).toContain("summary: Patterns for flakes");
    }
  });

  it("handleEnsurePage creates journal entries under pages/journal/daily by default", () => {
    rebuildAllMeta(wikiRoot);
    const result = handleEnsurePage(wikiRoot, {
      type: "journal",
      title: "2026-04-19 Daily Journal",
      domain: "personal",
      areas: ["journal"],
    });

    expect(result.isOk()).toBe(true);
    if (result.isOk() && result.value.details?.resolved && !result.value.details.conflict) {
      expect(result.value.details.path).toBe("pages/journal/daily/2026-04-19-daily-journal.md");
      const content = readFileSync(path.join(wikiRoot, result.value.details.path), "utf8");
      expect(content).toContain("type: journal");
      expect(content).toContain("status: active");
      expect(content).toContain("## Focus");
      expect(content).toContain("## Follow-ups");
    }
  });

  it("handleEnsurePage resolves exact title and alias matches within the same scope", () => {
    mkdirSync(path.join(wikiRoot, "pages", "resources", "technical"), { recursive: true });
    writeFileSync(
      path.join(wikiRoot, "pages", "resources", "technical", "flake-patterns.md"),
      `---
type: concept
title: Flake Patterns
aliases: [nix flakes]
tags: [nixos]
hosts: []
domain: technical
areas: [nixos]
status: active
updated: 2026-04-19
source_ids: []
summary: Existing page
---
# Flake Patterns
`,
      "utf8",
    );
    rebuildAllMeta(wikiRoot);

    const exact = handleEnsurePage(wikiRoot, { type: "concept", title: "Flake Patterns", folder: "resources/technical" });
    const alias = handleEnsurePage(wikiRoot, { type: "concept", title: "nix flakes", folder: "resources/technical" });

    expect(exact.isOk()).toBe(true);
    expect(alias.isOk()).toBe(true);
    if (exact.isOk() && alias.isOk()) {
      expect(exact.value.details?.created).toBe(false);
      expect(alias.value.details?.created).toBe(false);
    }
  });

  it("handleWikiLint reports frontmatter, links, and ignores journal coverage requirements", () => {
    mkdirSync(path.join(wikiRoot, "pages", "resources", "technical"), { recursive: true });
    mkdirSync(path.join(wikiRoot, "pages", "journal", "daily"), { recursive: true });

    writeFileSync(
      path.join(wikiRoot, "pages", "resources", "technical", "bad.md"),
      `---
type: concept
title: Bad Page
domain: technical
areas: [nixos]
hosts: []
status: active
updated: 2026-04-19
source_ids: []
summary: bad
---
# Bad Page

See [[missing-page]].
`,
      "utf8",
    );
    writeFileSync(
      path.join(wikiRoot, "pages", "journal", "daily", "2026-04-19.md"),
      `---
type: journal
title: 2026-04-19 Daily Journal
domain: personal
areas: [journal]
hosts: []
status: active
updated: 2026-04-19
summary: Daily note
---
# Daily Journal
`,
      "utf8",
    );

    const result = handleWikiLint(wikiRoot, "all");
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.details?.counts.brokenLinks).toBeGreaterThan(0);
      expect(result.value.details?.counts.coverage).toBe(1);
      const report = readFileSync(path.join(wikiRoot, "meta", "lint-report.md"), "utf8");
      expect(report).toContain("broken-link");
      expect(report).not.toContain("pages/journal/daily/2026-04-19.md` - No source_ids listed.");
    }
  });

  it("capture operations create raw source directories", () => {
    captureText(wikiRoot, "another note");
    const rawEntries = readdirSync(path.join(wikiRoot, "raw"));
    expect(rawEntries.some((entry) => entry.startsWith("SRC-"))).toBe(true);
  });
});
