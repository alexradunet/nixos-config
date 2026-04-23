import { mkdtempSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { captureText } from "../extension/actions-capture.ts";
import { handleIngestFinalize, handleIngestPrepare } from "../extension/actions-ingest.ts";

describe("ingest actions", () => {
  let wikiRoot: string;

  beforeEach(() => {
    wikiRoot = mkdtempSync(path.join(os.tmpdir(), "llm-wiki-ingest-"));
    mkdirSync(path.join(wikiRoot, "raw"), { recursive: true });
    mkdirSync(path.join(wikiRoot, "pages", "sources"), { recursive: true });
    mkdirSync(path.join(wikiRoot, "meta"), { recursive: true });
  });

  afterEach(() => {
    rmSync(wikiRoot, { recursive: true, force: true });
  });

  it("prepare lists captured packets with deterministic paths", () => {
    const capture = captureText(
      wikiRoot,
      "A source worth integrating",
      { title: "Source One", kind: "note", domain: "technical" },
      new Date("2026-04-23T10:00:00Z"),
    );

    expect(capture.isOk()).toBe(true);
    const prepared = handleIngestPrepare(wikiRoot, { status: "captured" });
    expect(prepared.isOk()).toBe(true);

    if (prepared.isOk()) {
      expect(prepared.value.details?.count).toBe(1);
      expect(prepared.value.details?.sources[0]).toMatchObject({
        sourceId: "SRC-2026-04-23-001",
        title: "Source One",
        kind: "note",
        status: "captured",
        packetDir: "raw/SRC-2026-04-23-001",
        manifestPath: "raw/SRC-2026-04-23-001/manifest.json",
        extractedPath: "raw/SRC-2026-04-23-001/extracted.md",
        sourcePagePath: "pages/sources/SRC-2026-04-23-001.md",
        sourcePageExists: true,
      });
    }
  });

  it("finalize marks source manifests and source pages as integrated", () => {
    const capture = captureText(
      wikiRoot,
      "A source worth integrating",
      { title: "Source One", kind: "note", domain: "technical" },
      new Date("2026-04-23T10:00:00Z"),
    );
    expect(capture.isOk()).toBe(true);

    const finalize = handleIngestFinalize(wikiRoot, { sourceIds: ["SRC-2026-04-23-001"] });
    expect(finalize.isOk()).toBe(true);

    if (finalize.isOk()) {
      expect(finalize.value.details?.finalized).toEqual(["SRC-2026-04-23-001"]);
      expect(finalize.value.details?.skipped).toEqual([]);
    }

    const manifest = JSON.parse(readFileSync(path.join(wikiRoot, "raw", "SRC-2026-04-23-001", "manifest.json"), "utf8")) as {
      status: string;
      integratedAt?: string;
    };
    expect(manifest.status).toBe("integrated");
    expect(manifest.integratedAt).toBeTruthy();

    const page = readFileSync(path.join(wikiRoot, "pages", "sources", "SRC-2026-04-23-001.md"), "utf8");
    expect(page).toContain("status: integrated");

    const prepared = handleIngestPrepare(wikiRoot, { status: "captured" });
    expect(prepared.isOk()).toBe(true);
    if (prepared.isOk()) {
      expect(prepared.value.details?.count).toBe(0);
    }
  });
});
