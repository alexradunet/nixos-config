import type { RegistryEntry, WikiPageType } from "./types.js";

export const REQUIRED_FRONTMATTER_FIELDS: Record<WikiPageType, readonly string[]> = {
	source: ["type", "source_id", "title", "status", "captured_at", "origin_type", "origin_value", "source_ids"],
	concept: ["type", "title", "status", "updated", "source_ids", "summary"],
	entity: ["type", "title", "status", "updated", "source_ids", "summary"],
	synthesis: ["type", "title", "status", "updated", "source_ids", "summary"],
	analysis: ["type", "title", "status", "updated", "source_ids", "summary"],
	evolution: ["type", "title", "status", "updated", "source_ids", "summary"],
	procedure: ["type", "title", "status", "updated", "source_ids", "summary"],
	decision: ["type", "title", "status", "updated", "source_ids", "summary"],
	identity: ["type", "title", "status", "updated", "source_ids", "summary"],
	journal: ["type", "title", "status", "updated", "summary"],
};

export const SEARCH_FIELD_WEIGHTS = {
	exactTitle: 120,
	exactAlias: 110,
	exactDomain: 55,
	exactArea: 52,
	exactSummary: 50,
	exactSourceId: 45,
	exactPath: 40,
	exactHeading: 35,
	tokenTitle: 18,
	tokenAlias: 14,
	tokenDomain: 10,
	tokenArea: 10,
	tokenSummary: 8,
	tokenHeading: 6,
	tokenSourceId: 5,
	tokenTag: 4,
	tokenPath: 3,
} as const;

export type LintMode = "links" | "orphans" | "frontmatter" | "duplicates" | "coverage" | "staleness" | "all";

export interface SearchableRegistryEntry {
	title: RegistryEntry["title"];
	aliases: RegistryEntry["aliases"];
	domain: RegistryEntry["domain"];
	areas: RegistryEntry["areas"];
	summary: RegistryEntry["summary"];
	headings: RegistryEntry["headings"];
	tags: RegistryEntry["tags"];
	sourceIds: RegistryEntry["sourceIds"];
	path: RegistryEntry["path"];
}
