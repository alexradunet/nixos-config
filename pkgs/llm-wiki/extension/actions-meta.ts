import { appendFileSync, existsSync, mkdirSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { atomicWriteFile } from "./lib/filesystem.js";
import { parseFrontmatter } from "./lib/frontmatter.js";
import { nowIso, ok } from "./lib/utils.js";
import {
	appliesToHost,
	countWords,
	extractHeadings,
	extractWikiLinks,
	formatAreasSuffix,
	formatDomainSuffix,
	formatHostsSuffix,
	getCurrentHost,
	getPageFolder,
	inferDomainFromFolder,
	normalizeAreas,
	normalizeDomain,
	normalizeHosts,
	normalizeWikiLink,
} from "./paths.js";
import type {
	ActionResult,
	BacklinksData,
	RegistryData,
	RegistryEntry,
	WikiEvent,
	WikiMetaArtifacts,
	WikiPageType,
	WikiStatusDetails,
} from "./types.js";
import { PAGE_TYPES } from "./types.js";

function asString(value: unknown, fallback = ""): string {
	return typeof value === "string" ? value : fallback;
}

function pickField(frontmatter: Record<string, unknown>, ...keys: string[]): unknown {
	for (const key of keys) {
		if (key in frontmatter) return frontmatter[key];
	}
	return undefined;
}

function asStringArray(value: unknown): string[] {
	if (Array.isArray(value)) return value.filter((entry): entry is string => typeof entry === "string");
	if (typeof value === "string" && value.trim()) return [value.trim()];
	return [];
}

interface ParsedPage {
	relativePath: string;
	frontmatter: Record<string, unknown>;
	body: string;
	headings: string[];
	rawLinks: string[];
	normalizedLinks: string[];
	wordCount: number;
}

function walkMdFiles(dir: string, results: string[]): void {
	let entries: import("node:fs").Dirent[];
	try {
		entries = readdirSync(dir, { withFileTypes: true }) as import("node:fs").Dirent[];
	} catch {
		return;
	}
	for (const entry of entries) {
		const fullPath = path.join(dir, entry.name as string);
		if (entry.isDirectory()) {
			walkMdFiles(fullPath, results);
		} else if (entry.isFile() && entry.name.endsWith(".md")) {
			results.push(fullPath);
		}
	}
}

export function scanPages(wikiRoot: string): ParsedPage[] {
	const pagesDir = path.join(wikiRoot, "pages");
	if (!existsSync(pagesDir)) return [];

	const files: string[] = [];
	walkMdFiles(pagesDir, files);
	files.sort();

	return files.map((filePath) => {
		const raw = readFileSync(filePath, "utf-8");
		const { attributes, body } = parseFrontmatter(raw);
		const headings = extractHeadings(body);
		const rawLinks = extractWikiLinks(body);
		const normalizedLinks = rawLinks.map((link) => normalizeWikiLink(link)).filter((link): link is string => link !== undefined);
		return {
			relativePath: path.relative(wikiRoot, filePath).replace(/\\/g, "/"),
			frontmatter: attributes,
			body,
			headings,
			rawLinks,
			normalizedLinks,
			wordCount: countWords(body),
		};
	});
}

export function buildRegistry(pages: ParsedPage[]): RegistryData {
	const entries: RegistryEntry[] = pages.map((page) => {
		const frontmatter = page.frontmatter;
		const type = (PAGE_TYPES.includes(frontmatter.type as WikiPageType) ? frontmatter.type : "concept") as WikiPageType;
		const title = asString(frontmatter.title) || path.basename(page.relativePath, ".md");
		const folder = getPageFolder(page.relativePath);
		const domain = normalizeDomain(asString(pickField(frontmatter, "domain"))) ?? inferDomainFromFolder(folder);
		return {
			type,
			path: page.relativePath,
			folder,
			title,
			aliases: asStringArray(frontmatter.aliases),
			summary: asString(frontmatter.summary),
			status: asString(frontmatter.status, "draft") as RegistryEntry["status"],
			tags: asStringArray(frontmatter.tags),
			hosts: normalizeHosts(asStringArray(frontmatter.hosts)),
			...(domain ? { domain } : {}),
			areas: normalizeAreas(asStringArray(frontmatter.areas)),
			updated: asString(frontmatter.updated),
			sourceIds: asStringArray(pickField(frontmatter, "sourceIds", "source_ids")),
			linksOut: page.normalizedLinks,
			headings: page.headings,
			wordCount: page.wordCount,
		};
	});

	entries.sort((a, b) => a.path.localeCompare(b.path));
	return { version: 1, generatedAt: nowIso(), pages: entries };
}

export function buildBacklinks(registry: RegistryData): BacklinksData {
	const pathSet = new Set(registry.pages.map((page) => page.path));
	const byPath: Record<string, { inbound: string[]; outbound: string[] }> = {};

	for (const entry of registry.pages) {
		if (!byPath[entry.path]) byPath[entry.path] = { inbound: [], outbound: [] };
	}

	for (const entry of registry.pages) {
		const outbound = [...new Set(entry.linksOut.filter((link) => pathSet.has(link)))].sort();
		byPath[entry.path].outbound = outbound;
		for (const target of outbound) {
			if (!byPath[target]) byPath[target] = { inbound: [], outbound: [] };
			byPath[target].inbound.push(entry.path);
		}
	}

	for (const key of Object.keys(byPath)) {
		byPath[key].inbound = [...new Set(byPath[key].inbound)].sort();
	}

	return { version: 1, generatedAt: nowIso(), byPath };
}

export function renderIndex(registry: RegistryData): string {
	const lines: string[] = ["# Wiki Index", "", `Generated: ${nowIso()}`, ""];

	const sectionOrder: WikiPageType[] = [
		"source",
		"concept",
		"entity",
		"synthesis",
		"analysis",
		"evolution",
		"procedure",
		"decision",
		"identity",
		"journal",
	];
	const sectionLabel: Record<WikiPageType, string> = {
		source: "Source Pages",
		concept: "Concept Pages",
		entity: "Entity Pages",
		synthesis: "Synthesis Pages",
		analysis: "Analysis Pages",
		evolution: "Evolution Pages",
		procedure: "Procedure Pages",
		decision: "Decision Pages",
		identity: "Identity Pages",
		journal: "Journal Pages",
	};

	for (const type of sectionOrder) {
		const entries = registry.pages.filter((page) => page.type === type);
		if (entries.length === 0) continue;
		lines.push(`## ${sectionLabel[type]}`, "");
		for (const entry of entries) {
			const displayPath = entry.path.replace(/^pages\//, "").replace(/\.md$/, "");
			const label = entry.title || displayPath;
			const summary = entry.summary ? ` — ${entry.summary}` : "";
			lines.push(
				`- [[${displayPath}|${label}]]${formatDomainSuffix(entry.domain)}${formatAreasSuffix(entry.areas)}${formatHostsSuffix(entry.hosts)}${summary}`,
			);
		}
		lines.push("");
	}

	return lines.join("\n");
}

export function renderLog(events: WikiEvent[]): string {
	if (events.length === 0) return "# Wiki Log\n\n_No events yet._\n";

	const lines = ["# Wiki Log", ""];
	for (const event of events) {
		const timestamp = event.ts.replace("T", " ").replace(/:\d{2}(\.\d+)?Z$/, " UTC");
		lines.push(`## [${timestamp}] ${event.kind} | ${event.title}`);
		if (event.sourceIds && event.sourceIds.length > 0) lines.push(`- Sources: ${event.sourceIds.join(", ")}`);
		if (event.pagePaths && event.pagePaths.length > 0) lines.push(`- Pages: ${event.pagePaths.join(", ")}`);
		lines.push("");
	}
	return lines.join("\n");
}

export function deriveWikiMetaArtifacts(pages: ParsedPage[], events: WikiEvent[]): WikiMetaArtifacts {
	const registry = buildRegistry(pages);
	const backlinks = buildBacklinks(registry);
	return { registry, backlinks, index: renderIndex(registry), log: renderLog(events) };
}

export function rebuildAllMeta(wikiRoot: string): { registry: RegistryData; backlinks: BacklinksData } {
	const metaDir = path.join(wikiRoot, "meta");
	mkdirSync(metaDir, { recursive: true });

	const pages = scanPages(wikiRoot);
	const events = readEventsSync(wikiRoot);
	const artifacts = deriveWikiMetaArtifacts(pages, events);

	atomicWriteFile(path.join(metaDir, "registry.json"), JSON.stringify(artifacts.registry, null, 2));
	atomicWriteFile(path.join(metaDir, "backlinks.json"), JSON.stringify(artifacts.backlinks, null, 2));
	atomicWriteFile(path.join(metaDir, "index.md"), artifacts.index);
	atomicWriteFile(path.join(metaDir, "log.md"), artifacts.log);

	return { registry: artifacts.registry, backlinks: artifacts.backlinks };
}

export function loadRegistry(wikiRoot: string): RegistryData {
	const registryPath = path.join(wikiRoot, "meta", "registry.json");
	try {
		return JSON.parse(readFileSync(registryPath, "utf-8")) as RegistryData;
	} catch {
		return rebuildAllMeta(wikiRoot).registry;
	}
}

function eventsPath(wikiRoot: string): string {
	return path.join(wikiRoot, "meta", "events.jsonl");
}

function readEventsSync(wikiRoot: string): WikiEvent[] {
	try {
		return readFileSync(eventsPath(wikiRoot), "utf-8")
			.split("\n")
			.filter((line) => line.trim())
			.map((line) => JSON.parse(line) as WikiEvent);
	} catch {
		return [];
	}
}

export function appendEvent(wikiRoot: string, event: WikiEvent): void {
	const metaDir = path.join(wikiRoot, "meta");
	mkdirSync(metaDir, { recursive: true });
	appendFileSync(path.join(metaDir, "events.jsonl"), `${JSON.stringify(event)}\n`, "utf-8");
}

export function readEvents(wikiRoot: string): WikiEvent[] {
	return readEventsSync(wikiRoot);
}

function countByDomain(pages: RegistryEntry[]): Record<string, number> {
	const counts: Record<string, number> = {};
	for (const page of pages) {
		const key = page.domain ?? "unspecified";
		counts[key] = (counts[key] ?? 0) + 1;
	}
	return counts;
}

export function handleWikiStatus(wikiRoot: string): ActionResult<WikiStatusDetails> {
	const pagesDir = path.join(wikiRoot, "pages");
	if (!existsSync(pagesDir)) {
		return ok({ text: "Wiki not initialized.", details: { initialized: false, root: wikiRoot, host: getCurrentHost() } });
	}

	const registry = loadRegistry(wikiRoot);
	const host = getCurrentHost();
	const visiblePages = registry.pages.filter((page) => appliesToHost(page.hosts, host));
	const total = registry.pages.length;
	const sourceCount = registry.pages.filter((page) => page.type === "source").length;
	const journalCount = registry.pages.filter((page) => page.type === "journal").length;
	const canonicalCount = total - sourceCount - journalCount;
	const capturedCount = registry.pages.filter((page) => page.type === "source" && page.status === "captured").length;
	const integratedCount = registry.pages.filter((page) => page.type === "source" && page.status === "integrated").length;
	const domains = countByDomain(visiblePages);
	const domainText = Object.entries(domains)
		.sort((a, b) => a[0].localeCompare(b[0]))
		.map(([domain, count]) => `${domain}=${count}`)
		.join(", ");

	const text = [
		`Wiki root: ${wikiRoot}`,
		`Host: ${host}`,
		`Pages: ${total} total (${sourceCount} source, ${canonicalCount} canonical, ${journalCount} journal)`,
		`Visible here: ${visiblePages.length}`,
		`Sources: ${capturedCount} captured, ${integratedCount} integrated`,
		domainText ? `Domains: ${domainText}` : undefined,
	]
		.filter(Boolean)
		.join("\n");

	return ok({
		text,
		details: {
			initialized: true,
			host,
			root: wikiRoot,
			total,
			visible: visiblePages.length,
			source: sourceCount,
			canonical: canonicalCount,
			journal: journalCount,
			captured: capturedCount,
			integrated: integratedCount,
			domains,
		},
	});
}

export function buildWikiDigest(wikiRoot: string): string {
	const registryPath = path.join(wikiRoot, "meta", "registry.json");
	const pagesDir = path.join(wikiRoot, "pages");
	if (!existsSync(registryPath) && !existsSync(pagesDir)) return "";

	const host = getCurrentHost();
	const registry = loadRegistry(wikiRoot);
	const active = registry.pages
		.filter((page) => !["source", "identity", "journal"].includes(page.type))
		.filter((page) => page.status === "active")
		.filter((page) => appliesToHost(page.hosts, host))
		.sort((a, b) => b.wordCount - a.wordCount)
		.slice(0, 15);

	if (active.length === 0) return "";

	const lines = [`\n\n[WIKI MEMORY DIGEST for ${host}]`];
	for (const entry of active) {
		const summary = entry.summary ? ` — ${entry.summary}` : "";
		lines.push(
			`- ${entry.title} (${entry.type})${formatDomainSuffix(entry.domain)}${formatAreasSuffix(entry.areas)}${formatHostsSuffix(entry.hosts)}${summary}`,
		);
	}
	return lines.join("\n");
}
