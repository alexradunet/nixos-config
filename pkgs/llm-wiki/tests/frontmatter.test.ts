import { describe, expect, it } from "vitest";
import { parseFrontmatter, stringifyFrontmatter } from "../extension/lib/frontmatter.js";

describe("frontmatter", () => {
  it("serializes and parses structured frontmatter", () => {
    const markdown = stringifyFrontmatter(
      {
        type: "concept",
        title: "System Landscape",
        tags: ["nixos", "pi"],
        hosts: ["pad-nixos"],
        domain: "technical",
        areas: ["infrastructure", "ai"],
      },
      "# Body",
    );

    const parsed = parseFrontmatter(markdown);
    expect(parsed.attributes).toMatchObject({
      type: "concept",
      title: "System Landscape",
      tags: ["nixos", "pi"],
      hosts: ["pad-nixos"],
      domain: "technical",
      areas: ["infrastructure", "ai"],
    });
    expect(parsed.body).toBe("# Body");
  });

  it("parses comma-separated arrays for compatibility", () => {
    const parsed = parseFrontmatter(`---
aliases: foo, bar
tags: one, two
hosts: pad-nixos, evo-nixos
areas: infra, ai
---
body
`);

    expect(parsed.attributes.aliases).toEqual(["foo", "bar"]);
    expect(parsed.attributes.tags).toEqual(["one", "two"]);
    expect(parsed.attributes.hosts).toEqual(["pad-nixos", "evo-nixos"]);
    expect(parsed.attributes.areas).toEqual(["infra", "ai"]);
  });

  it("returns empty attributes for malformed frontmatter", () => {
    const parsed = parseFrontmatter(`---
: bad yaml
---
hello
`);
    expect(parsed.attributes).toEqual({});
    expect(parsed.body).toContain("hello");
  });
});
