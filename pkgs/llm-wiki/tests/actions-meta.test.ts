import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  appendEvent,
  buildBacklinks,
  buildRegistry,
  buildWikiDigest,
  deriveWikiMetaArtifacts,
  handleWikiStatus,
  readEvents,
  rebuildAllMeta,
  scanPages,
} from "../extension/actions-meta.js";

describe("actions-meta", () => {
  let wikiRoot: string;

  beforeEach(() => {
    wikiRoot = mkdtempSync(path.join(os.tmpdir(), "llm-wiki-meta-"));
    mkdirSync(path.join(wikiRoot, "pages", "resources", "technical"), { recursive: true });
    mkdirSync(path.join(wikiRoot, "pages", "areas", "personal"), { recursive: true });
    mkdirSync(path.join(wikiRoot, "pages", "journal", "daily"), { recursive: true });
  });

  afterEach(() => {
    rmSync(wikiRoot, { recursive: true, force: true });
    delete process.env.PI_LLM_WIKI_HOST;
  });

  it("scanPages and buildRegistry preserve folder, domain, areas, and hosts", () => {
    writeFileSync(
      path.join(wikiRoot, "pages", "resources", "technical", "system-landscape.md"),
      `---
type: concept
title: System Landscape
tags: [nixos]
hosts: []
areas: [infrastructure, ai]
status: active
updated: 2026-04-19
source_ids: []
summary: Shared technical map
---
# System Landscape

See [[areas/personal/personal-identity]].
`,
      "utf8",
    );
    writeFileSync(
      path.join(wikiRoot, "pages", "areas", "personal", "personal-identity.md"),
      `---
type: identity
title: Personal Identity
domain: personal
tags: [identity]
hosts: []
areas: [identity]
status: active
updated: 2026-04-19
source_ids: []
summary: Stable personal notes
---
# Personal Identity
`,
      "utf8",
    );

    const pages = scanPages(wikiRoot);
    const registry = buildRegistry(pages);

    expect(registry.pages).toHaveLength(2);
    expect(registry.pages[0]).toMatchObject({
      folder: "areas/personal",
      domain: "personal",
      areas: ["identity"],
    });
    expect(registry.pages[1]).toMatchObject({
      folder: "resources/technical",
      domain: "technical",
      areas: ["infrastructure", "ai"],
    });
  });

  it("buildBacklinks and deriveWikiMetaArtifacts compute links and index metadata", () => {
    writeFileSync(
      path.join(wikiRoot, "pages", "resources", "technical", "system-landscape.md"),
      `---
type: concept
title: System Landscape
domain: technical
tags: [nixos]
hosts: []
areas: [infrastructure]
status: active
updated: 2026-04-19
source_ids: []
summary: Shared technical map
---
# System Landscape

See [[areas/personal/personal-identity]].
`,
      "utf8",
    );
    writeFileSync(
      path.join(wikiRoot, "pages", "areas", "personal", "personal-identity.md"),
      `---
type: identity
title: Personal Identity
domain: personal
tags: [identity]
hosts: []
areas: [identity]
status: active
updated: 2026-04-19
source_ids: []
summary: Stable personal notes
---
# Personal Identity
`,
      "utf8",
    );

    const pages = scanPages(wikiRoot);
    const artifacts = deriveWikiMetaArtifacts(pages, []);
    const backlinks = buildBacklinks(artifacts.registry);

    expect(backlinks.byPath["pages/areas/personal/personal-identity.md"]?.inbound).toContain(
      "pages/resources/technical/system-landscape.md",
    );
    expect(artifacts.index).toContain("[domain: technical]");
    expect(artifacts.index).toContain("[areas: infrastructure]");
    expect(artifacts.index).toContain("## Identity Pages");
  });

  it("rebuildAllMeta writes registry, backlinks, index, and log", () => {
    writeFileSync(
      path.join(wikiRoot, "pages", "journal", "daily", "2026-04-19.md"),
      `---
type: journal
title: 2026-04-19 Daily Journal
domain: personal
tags: [journal]
hosts: []
areas: [journal]
status: active
updated: 2026-04-19
summary: Daily note
---
# Daily Journal
`,
      "utf8",
    );
    appendEvent(wikiRoot, {
      ts: "2026-04-19T12:00:00Z",
      kind: "rebuild",
      title: "Rebuilt wiki metadata",
      pagePaths: ["pages/journal/daily/2026-04-19.md"],
    });

    const { registry } = rebuildAllMeta(wikiRoot);
    expect(registry.pages[0]).toMatchObject({ type: "journal", domain: "personal", areas: ["journal"] });
    expect(existsSync(path.join(wikiRoot, "meta", "registry.json"))).toBe(true);
    expect(existsSync(path.join(wikiRoot, "meta", "backlinks.json"))).toBe(true);
    expect(existsSync(path.join(wikiRoot, "meta", "index.md"))).toBe(true);
    expect(existsSync(path.join(wikiRoot, "meta", "log.md"))).toBe(true);
    expect(readFileSync(path.join(wikiRoot, "meta", "log.md"), "utf8")).toContain("Rebuilt wiki metadata");
  });

  it("handleWikiStatus reports domain counts and visible pages for the current host", () => {
    process.env.PI_LLM_WIKI_HOST = "pad-nixos";
    writeFileSync(
      path.join(wikiRoot, "pages", "resources", "technical", "host-note.md"),
      `---
type: concept
title: Host Note
domain: technical
tags: [host]
hosts: [pad-nixos]
areas: [infrastructure]
status: active
updated: 2026-04-19
source_ids: []
summary: Host specific note
---
# Host Note
`,
      "utf8",
    );
    writeFileSync(
      path.join(wikiRoot, "pages", "areas", "personal", "personal-identity.md"),
      `---
type: identity
title: Personal Identity
domain: personal
tags: [identity]
hosts: []
areas: [identity]
status: active
updated: 2026-04-19
source_ids: []
summary: Stable personal notes
---
# Personal Identity
`,
      "utf8",
    );
    rebuildAllMeta(wikiRoot);

    const result = handleWikiStatus(wikiRoot);
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.details).toMatchObject({
        host: "pad-nixos",
        visible: 2,
        domains: { personal: 1, technical: 1 },
      });
      expect(result.value.text).toContain("Domains: personal=1, technical=1");
    }
  });

  it("buildWikiDigest filters by host and excludes identity and journal pages", () => {
    process.env.PI_LLM_WIKI_HOST = "pad-nixos";
    writeFileSync(
      path.join(wikiRoot, "pages", "resources", "technical", "shared.md"),
      `---
type: concept
title: Shared Technical Note
domain: technical
tags: [shared]
hosts: []
areas: [infrastructure]
status: active
updated: 2026-04-19
source_ids: []
summary: Shared summary
---
# Shared

${"word ".repeat(50)}
`,
      "utf8",
    );
    writeFileSync(
      path.join(wikiRoot, "pages", "resources", "technical", "laptop.md"),
      `---
type: concept
title: Laptop Technical Note
domain: technical
tags: [host]
hosts: [pad-nixos]
areas: [infrastructure]
status: active
updated: 2026-04-19
source_ids: []
summary: Laptop summary
---
# Laptop

${"word ".repeat(60)}
`,
      "utf8",
    );
    writeFileSync(
      path.join(wikiRoot, "pages", "journal", "daily", "2026-04-19.md"),
      `---
type: journal
title: 2026-04-19 Daily Journal
domain: personal
tags: [journal]
hosts: []
areas: [journal]
status: active
updated: 2026-04-19
summary: Daily note
---
# Daily Journal
`,
      "utf8",
    );
    writeFileSync(
      path.join(wikiRoot, "pages", "areas", "personal", "personal-identity.md"),
      `---
type: identity
title: Personal Identity
domain: personal
tags: [identity]
hosts: []
areas: [identity]
status: active
updated: 2026-04-19
source_ids: []
summary: Stable personal notes
---
# Personal Identity
`,
      "utf8",
    );

    const digest = buildWikiDigest(wikiRoot);
    expect(digest).toContain("Shared Technical Note");
    expect(digest).toContain("Laptop Technical Note");
    expect(digest).not.toContain("Personal Identity");
    expect(digest).not.toContain("Daily Journal");
  });

  it("appendEvent and readEvents round-trip JSONL events", () => {
    appendEvent(wikiRoot, {
      ts: "2026-04-19T12:00:00Z",
      kind: "page-create",
      title: "Created page",
      pagePaths: ["pages/resources/technical/system-landscape.md"],
    });

    const events = readEvents(wikiRoot);
    expect(events).toHaveLength(1);
    expect(events[0]?.kind).toBe("page-create");
  });
});
