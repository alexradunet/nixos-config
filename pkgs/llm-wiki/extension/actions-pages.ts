import { mkdirSync } from "node:fs";
import path from "node:path";
import { atomicWriteFile } from "./lib/filesystem.js";
import { stringifyFrontmatter } from "./lib/frontmatter.js";
import { err, nowIso, ok } from "./lib/utils.js";
import { appendEvent, loadRegistry } from "./actions-meta.js";
import {
	buildPagePath,
	dedupeSlug,
	getAllowedDomains,
	isDomainAllowed,
	normalizeAreas,
	normalizeDomain,
	normalizeHosts,
	normalizePageFolder,
	slugifyTitle,
	todayStamp,
} from "./paths.js";
import type { ActionResult, CanonicalPageFrontmatter, CanonicalPageType, EnsurePageDetails } from "./types.js";

interface EnsurePageParams {
	type: CanonicalPageType;
	title: string;
	aliases?: string[];
	tags?: string[];
	hosts?: string[];
	domain?: string;
	areas?: string[];
	folder?: string;
	summary?: string;
}

export function handleEnsurePage(wikiRoot: string, params: EnsurePageParams): ActionResult<EnsurePageDetails> {
	const registry = loadRegistry(wikiRoot);
	const normalizedTitle = params.title.trim().toLowerCase();
	const normalizedAliases = new Set((params.aliases ?? []).map((alias) => alias.trim().toLowerCase()));
	const normalizedDomain = normalizeDomain(params.domain);

	const allowedDomains = getAllowedDomains();
	if (!isDomainAllowed(normalizedDomain, allowedDomains)) {
		return err(
			`Domain "${normalizedDomain ?? "unspecified"}" is not accessible in this session. ` +
				`Allowed domains: ${allowedDomains?.join(", ") ?? "all"}.`,
		);
	}

	const normalizedFolder = normalizePageFolder(params.folder) ?? (params.type === "journal" ? "journal/daily" : normalizedDomain);

	const matches = registry.pages.filter((page) => {
		if (page.type !== params.type) return false;
		if (normalizedDomain && page.domain !== normalizedDomain) return false;
		if (normalizedFolder && page.folder !== normalizedFolder) return false;
		const names = [page.title, ...page.aliases].map((value) => value.trim().toLowerCase());
		return names.includes(normalizedTitle) || [...normalizedAliases].some((alias) => names.includes(alias));
	});

	if (matches.length > 1) {
		return ok({
			text: `Conflict: ${matches.length} pages matched "${params.title}". Candidates: ${matches.map((page) => page.path).join(", ")}`,
			details: {
				resolved: false,
				created: false,
				conflict: true,
				candidates: matches.map((page) => ({ path: page.path, title: page.title })),
			},
		});
	}

	if (matches.length === 1 && matches[0]) {
		const page = matches[0];
		return ok({
			text: `Resolved existing page: ${page.path}`,
			details: { resolved: true, created: false, conflict: false, path: page.path, title: page.title, type: page.type },
		});
	}

	const existingSlugs = registry.pages
		.filter((page) => page.type === params.type)
		.filter((page) => !normalizedFolder || page.folder === normalizedFolder)
		.map((page) => path.basename(page.path, ".md"));
	const slug = dedupeSlug(slugifyTitle(params.title), existingSlugs);
	const relPath = buildPagePath(slug, normalizedFolder);
	const absPath = path.join(wikiRoot, relPath);

	const fm: CanonicalPageFrontmatter = {
		type: params.type,
		title: params.title,
		aliases: params.aliases ?? [],
		tags: params.tags ?? [],
		hosts: normalizeHosts(params.hosts),
		...(normalizedDomain ? { domain: normalizedDomain } : {}),
		areas: normalizeAreas(params.areas),
		status: params.type === "journal" ? "active" : "draft",
		updated: todayStamp(),
		source_ids: [],
		summary: params.summary ?? "",
	};
	const body = (
		params.type === "journal"
			? [
				`# ${params.title}`,
				"",
				"## Focus",
				"",
				"## Notes",
				"",
				"## Wins",
				"",
				"## Friction",
				"",
				"## Follow-ups",
				"",
			]
			: [
				`# ${params.title}`,
				"",
				"## Current understanding",
				"",
				"## Evidence",
				"",
				"## Tensions / caveats",
				"",
				"## Open questions",
				"",
				"## Related pages",
				"",
			]
	).join("\n");

	mkdirSync(path.dirname(absPath), { recursive: true });
	atomicWriteFile(absPath, stringifyFrontmatter(fm, body));

	appendEvent(wikiRoot, {
		ts: nowIso(),
		kind: "page-create",
		title: `Created ${params.type}: ${params.title}`,
		pagePaths: [relPath],
	});

	return ok({
		text: `Created page: ${relPath}`,
		details: { resolved: true, created: true, conflict: false, path: relPath, title: params.title, type: params.type },
	});
}
