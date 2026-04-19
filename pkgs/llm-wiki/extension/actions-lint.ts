import path from "node:path";
import { atomicWriteFile } from "./lib/filesystem.js";
import { ok } from "./lib/utils.js";
import { buildBacklinks, buildRegistry, scanPages } from "./actions-meta.js";
import { normalizeDomain, normalizeWikiLink } from "./paths.js";
import { PAGE_TYPES, type WikiPageType } from "./types.js";
import { type LintMode, REQUIRED_FRONTMATTER_FIELDS } from "./rules.js";
import type { ActionResult, BacklinksData, LintDetails, LintIssue, RegistryData } from "./types.js";

function normalizeHeadingRef(value: string): string {
	return value.trim().toLowerCase().replace(/\s+/g, " ");
}

function lintLinks(pages: ReturnType<typeof scanPages>, registry: RegistryData): LintIssue[] {
	const known = new Set(registry.pages.map((page) => page.path));
	const headingsByPath = new Map(
		pages.map((page) => [page.relativePath, new Set(page.headings.map((heading) => normalizeHeadingRef(heading)))]),
	);
	const issues: LintIssue[] = [];
	for (const page of pages) {
		for (const raw of page.rawLinks) {
			const normalized = normalizeWikiLink(raw);
			if (!normalized || !known.has(normalized)) {
				issues.push({
					kind: "broken-link",
					severity: "warning",
					path: page.relativePath,
					message: `Broken link: [[${raw}]]`,
				});
				continue;
			}
			const [, fragment] = raw.split("#", 2);
			if (fragment) {
				const headings = headingsByPath.get(normalized);
				if (!headings?.has(normalizeHeadingRef(fragment))) {
					issues.push({
						kind: "broken-link",
						severity: "warning",
						path: page.relativePath,
						message: `Broken heading link: [[${raw}]]`,
					});
				}
			}
		}
	}
	return issues;
}

function lintOrphans(registry: RegistryData, backlinks: BacklinksData): LintIssue[] {
	return registry.pages
		.filter((page) => page.type !== "source")
		.filter((page) => {
			const record = backlinks.byPath[page.path];
			return record && record.inbound.length === 0 && record.outbound.length === 0;
		})
		.map((page) => ({
			kind: "orphan",
			severity: "warning" as const,
			path: page.path,
			message: "No inbound or outbound wiki links.",
		}));
}

const SOURCE_STATUSES = new Set(["captured", "integrated", "superseded"]);
const CANONICAL_STATUSES = new Set(["draft", "active", "contested", "superseded", "archived"]);
const ORIGIN_TYPES = new Set(["text", "file", "url"]);

function pushFrontmatterIssue(issues: LintIssue[], pathValue: string, message: string): void {
	issues.push({
		kind: "frontmatter",
		severity: "error",
		path: pathValue,
		message,
	});
}

function isStringArray(value: unknown): value is string[] {
	return Array.isArray(value) && value.every((entry) => typeof entry === "string");
}

function lintFrontmatter(pages: ReturnType<typeof scanPages>): LintIssue[] {
	const issues: LintIssue[] = [];
	for (const page of pages) {
		const rawType = page.frontmatter.type;
		if (typeof rawType !== "string") {
			pushFrontmatterIssue(issues, page.relativePath, "Missing: type");
			continue;
		}
		if (!PAGE_TYPES.includes(rawType as WikiPageType)) {
			pushFrontmatterIssue(issues, page.relativePath, `Invalid type: ${rawType}`);
			continue;
		}

		const type = rawType as WikiPageType;
		const required = REQUIRED_FRONTMATTER_FIELDS[type];
		for (const field of required) {
			if (!(field in page.frontmatter)) {
				pushFrontmatterIssue(issues, page.relativePath, `Missing: ${field}`);
			}
		}

		const title = page.frontmatter.title;
		if (title !== undefined && (typeof title !== "string" || title.trim() === "")) {
			pushFrontmatterIssue(issues, page.relativePath, "Field title must be a non-empty string.");
		}

		const domain = page.frontmatter.domain;
		if (domain !== undefined && (typeof domain !== "string" || normalizeDomain(domain) !== domain.trim().toLowerCase())) {
			pushFrontmatterIssue(issues, page.relativePath, `Invalid domain: ${String(domain)}`);
		}

		for (const field of ["aliases", "tags", "hosts", "areas", "source_ids"] as const) {
			const value = page.frontmatter[field];
			if (value !== undefined && !isStringArray(value)) {
				pushFrontmatterIssue(issues, page.relativePath, `Field ${field} must be an array of strings.`);
			}
		}

		if (type === "source") {
			const sourceId = page.frontmatter.source_id;
			if (sourceId !== undefined && (typeof sourceId !== "string" || sourceId.trim() === "")) {
				pushFrontmatterIssue(issues, page.relativePath, "Field source_id must be a non-empty string.");
			}
			const status = page.frontmatter.status;
			if (status !== undefined && (typeof status !== "string" || !SOURCE_STATUSES.has(status))) {
				pushFrontmatterIssue(issues, page.relativePath, `Invalid source status: ${String(status)}`);
			}
			const originType = page.frontmatter.origin_type;
			if (originType !== undefined && (typeof originType !== "string" || !ORIGIN_TYPES.has(originType))) {
				pushFrontmatterIssue(issues, page.relativePath, `Invalid origin_type: ${String(originType)}`);
			}
			const capturedAt = page.frontmatter.captured_at;
			if (capturedAt !== undefined && (typeof capturedAt !== "string" || capturedAt.trim() === "")) {
				pushFrontmatterIssue(issues, page.relativePath, "Field captured_at must be a non-empty string.");
			}
			const originValue = page.frontmatter.origin_value;
			if (originValue !== undefined && (typeof originValue !== "string" || originValue.trim() === "")) {
				pushFrontmatterIssue(issues, page.relativePath, "Field origin_value must be a non-empty string.");
			}
			continue;
		}

		const status = page.frontmatter.status;
		if (status !== undefined && (typeof status !== "string" || !CANONICAL_STATUSES.has(status))) {
			pushFrontmatterIssue(issues, page.relativePath, `Invalid canonical status: ${String(status)}`);
		}
		const updated = page.frontmatter.updated;
		if (updated !== undefined && (typeof updated !== "string" || updated.trim() === "")) {
			pushFrontmatterIssue(issues, page.relativePath, "Field updated must be a non-empty string.");
		}
		const summary = page.frontmatter.summary;
		if (summary !== undefined && typeof summary !== "string") {
			pushFrontmatterIssue(issues, page.relativePath, "Field summary must be a string.");
		}
	}
	return issues;
}

function lintDuplicates(registry: RegistryData): LintIssue[] {
	const seen = new Map<string, string>();
	const issues: LintIssue[] = [];
	for (const page of registry.pages.filter((entry) => entry.type !== "source")) {
		const normalizedTitle = page.title.trim().toLowerCase();
		const key = `${page.type}:${page.domain ?? "global"}:${normalizedTitle}`;
		const previousPath = seen.get(key);
		if (previousPath) {
			issues.push({
				kind: "duplicate",
				severity: "warning",
				path: page.path,
				message: `Duplicate title with ${previousPath}`,
			});
			continue;
		}
		seen.set(key, page.path);
	}
	return issues;
}

function lintCoverage(registry: RegistryData, backlinks: BacklinksData): LintIssue[] {
	const issues: LintIssue[] = [];
	for (const page of registry.pages) {
		if (page.type === "source") {
			const inbound = backlinks.byPath[page.path]?.inbound ?? [];
			if (inbound.filter((pathValue) => !pathValue.includes("/sources/")).length === 0) {
				issues.push({
					kind: "coverage",
					severity: "info",
					path: page.path,
					message: "Source not cited by any canonical page.",
				});
			}
			continue;
		}

		if (page.type === "journal") {
			continue;
		}

		if (page.sourceIds.length === 0) {
			issues.push({
				kind: "coverage",
				severity: "warning",
				path: page.path,
				message: "No source_ids listed.",
			});
		}
	}
	return issues;
}

function lintStaleness(registry: RegistryData): LintIssue[] {
	return registry.pages
		.filter((page) => page.type === "source" && page.status === "captured")
		.map((page) => ({
			kind: "staleness",
			severity: "info" as const,
			path: page.path,
			message: "Source still in captured state.",
		}));
}

function buildCounts(issues: LintIssue[]) {
	return {
		total: issues.length,
		brokenLinks: issues.filter((issue) => issue.kind === "broken-link").length,
		orphans: issues.filter((issue) => issue.kind === "orphan").length,
		frontmatter: issues.filter((issue) => issue.kind === "frontmatter").length,
		duplicates: issues.filter((issue) => issue.kind === "duplicate").length,
		coverage: issues.filter((issue) => issue.kind === "coverage").length,
		staleness: issues.filter((issue) => issue.kind === "staleness").length,
	};
}

function renderReport(mode: string, issues: LintIssue[], counts: ReturnType<typeof buildCounts>): string {
	const lines = ["# Lint Report", "", `Mode: ${mode}`, `Total: ${counts.total}`, ""];
	for (const issue of issues) {
		lines.push(`- **${issue.severity}** [${issue.kind}] \`${issue.path}\` - ${issue.message}`);
	}
	lines.push("");
	return lines.join("\n");
}

const LINT_CHECKS: Record<
	Exclude<LintMode, "all">,
	(pages: ReturnType<typeof scanPages>, registry: RegistryData, backlinks: BacklinksData) => LintIssue[]
> = {
	links: (pages, registry) => lintLinks(pages, registry),
	orphans: (_pages, registry, backlinks) => lintOrphans(registry, backlinks),
	frontmatter: (pages) => lintFrontmatter(pages),
	duplicates: (_pages, registry) => lintDuplicates(registry),
	coverage: (_pages, registry, backlinks) => lintCoverage(registry, backlinks),
	staleness: (_pages, registry) => lintStaleness(registry),
};

export function handleWikiLint(wikiRoot: string, mode: LintMode = "all"): ActionResult<LintDetails> {
	const pages = scanPages(wikiRoot);
	const registry = buildRegistry(pages);
	const backlinks = buildBacklinks(registry);
	const selectedModes = mode === "all" ? (Object.keys(LINT_CHECKS) as Array<Exclude<LintMode, "all">>) : [mode];
	const issues = selectedModes.flatMap((selectedMode) => LINT_CHECKS[selectedMode](pages, registry, backlinks));

	const counts = buildCounts(issues);
	atomicWriteFile(path.join(wikiRoot, "meta", "lint-report.md"), renderReport(mode, issues, counts));

	return ok({
		text: `Lint: ${counts.total} issues (links=${counts.brokenLinks} orphans=${counts.orphans} fm=${counts.frontmatter} dup=${counts.duplicates} cov=${counts.coverage} stale=${counts.staleness})`,
		details: { counts, issues },
	});
}
