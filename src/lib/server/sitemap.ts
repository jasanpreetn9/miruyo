// sitemap.xml is an index of smaller sitemaps: the site's own pages, then the
// title pages people search for by name. Staff, character and studio pages are
// left out, and robots.txt keeps crawlers off them: they'd lead a crawler
// through most of AniList for little search traffic. Titles come from AniList, most popular first, 500 to a sitemap: one request that
// asks for ten pages of 50 at once (each its own aliased Page).

import { anilistQuery } from '#lib/anilist/client.ts';
import { SITE_URL, SITEMAP_PATHS } from '#lib/seo.ts';

/** AniList's largest page. */
const PER_PAGE = 50;
/** Pages fetched per sitemap (one request). */
const PAGES_PER_SITEMAP = 10;
export const URLS_PER_SITEMAP = PER_PAGE * PAGES_PER_SITEMAP;

/** One kind of page the sitemaps list, from one AniList Page field. */
interface Source {
	/** The Page field and its arguments, e.g. `media(type: ANIME, …)`. */
	field: string;
	/** The ids' fields; `updatedAt` (unix seconds) becomes the page's lastmod. */
	select: string;
	/** Where the page lives on miruyo. */
	path: (id: number) => string;
	/** How many sitemaps of this kind: the top N × 500 by popularity. */
	sitemaps: number;
}

const SOURCES = {
	// the best-known anime and manga; 18+ titles are noindex, so left out
	anime: {
		field: 'media(type: ANIME, isAdult: false, sort: POPULARITY_DESC)',
		select: 'id updatedAt',
		path: (id) => `/title/${id}`,
		sitemaps: 6
	},
	// what's airing and what's next, however new: what the schedule and the
	// season chart are for, and the most searched while they air
	airing: {
		field:
			'media(type: ANIME, isAdult: false, status_in: [RELEASING, NOT_YET_RELEASED], sort: POPULARITY_DESC)',
		select: 'id updatedAt',
		path: (id) => `/title/${id}`,
		sitemaps: 2
	},
	manga: {
		field: 'media(type: MANGA, isAdult: false, sort: POPULARITY_DESC)',
		select: 'id updatedAt',
		path: (id) => `/title/${id}`,
		sitemaps: 4
	}
} satisfies Record<string, Source>;

type Kind = keyof typeof SOURCES;

/** One url in a sitemap. */
export interface SitemapEntry {
	path: string;
	/** Unix seconds. */
	updatedAt?: number;
}

/** The sitemaps the index lists, by name: `pages`, `anime-1`, `anime-2`… */
export const SITEMAP_NAMES: string[] = [
	'pages',
	...Object.entries(SOURCES).flatMap(([kind, source]) =>
		Array.from({ length: source.sitemaps }, (_, i) => `${kind}-${i + 1}`)
	)
];

/** `anime-2` → the anime source's second sitemap; null for an unknown name. */
export function parseSitemapName(name: string): { kind: Kind; index: number } | null {
	const match = /^([a-z]+)-([1-9]\d*)$/.exec(name);
	if (!match || !Object.hasOwn(SOURCES, match[1])) return null;
	const kind = match[1] as Kind;
	const index = Number(match[2]);
	return index <= SOURCES[kind].sitemaps ? { kind, index } : null;
}

/** The query for one sitemap: ten aliased pages of one source. */
export function sitemapQuery(kind: Kind, index: number): string {
	const { field, select } = SOURCES[kind];
	const first = (index - 1) * PAGES_PER_SITEMAP + 1;
	const pages = Array.from(
		{ length: PAGES_PER_SITEMAP },
		(_, i) => `p${i}: Page(page: ${first + i}, perPage: ${PER_PAGE}) { ${field} { ${select} } }`
	);
	return `query Sitemap {\n${pages.join('\n')}\n}`;
}

type SitemapResponse = Record<
	string,
	Record<string, Array<{ id: number; updatedAt?: number } | null> | null> | null
>;

/** One sitemap's urls, in popularity order, without repeats. */
export async function fetchSitemap(kind: Kind, index: number): Promise<SitemapEntry[]> {
	const data = await anilistQuery<SitemapResponse>(sitemapQuery(kind, index), {}, null);
	const { path } = SOURCES[kind];
	const seen = new Set<number>();
	const entries: SitemapEntry[] = [];
	for (let i = 0; i < PAGES_PER_SITEMAP; i++) {
		const page = data[`p${i}`];
		for (const item of Object.values(page ?? {})[0] ?? []) {
			if (!item || seen.has(item.id)) continue;
			seen.add(item.id);
			entries.push({ path: path(item.id), updatedAt: item.updatedAt });
		}
	}
	return entries;
}

/** The site's own public pages. */
export function pageEntries(): SitemapEntry[] {
	return SITEMAP_PATHS.map((path) => ({ path }));
}

function escapeXml(text: string): string {
	return text.replace(/[<>&'"]/g, (c) => `&#${c.charCodeAt(0)};`);
}

function lastmod(updatedAt: number | undefined): string {
	return updatedAt ? `<lastmod>${new Date(updatedAt * 1000).toISOString()}</lastmod>` : '';
}

export function urlsetXml(entries: SitemapEntry[]): string {
	return [
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
		...entries.map(
			(e) => `\t<url><loc>${escapeXml(SITE_URL + e.path)}</loc>${lastmod(e.updatedAt)}</url>`
		),
		'</urlset>',
		''
	].join('\n');
}

export function indexXml(names: string[]): string {
	return [
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
		...names.map((name) => `\t<sitemap><loc>${SITE_URL}/sitemaps/${name}.xml</loc></sitemap>`),
		'</sitemapindex>',
		''
	].join('\n');
}

/**
 * A day fresh on the CDN, then served stale for a week while it refreshes:
 * crawlers fetch sitemaps often, and each one costs an AniList request.
 */
export const SITEMAP_CACHE = 'public, max-age=0, s-maxage=86400, stale-while-revalidate=604800';
