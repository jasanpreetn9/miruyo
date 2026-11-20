import { afterEach, describe, expect, it, vi } from 'vitest';
import {
	fetchSitemap,
	indexXml,
	parseSitemapName,
	SITEMAP_NAMES,
	sitemapQuery,
	urlsetXml
} from './sitemap.ts';

afterEach(() => vi.unstubAllGlobals());

describe('sitemap names', () => {
	it('lists the site’s pages first, then each kind’s sitemaps', () => {
		expect(SITEMAP_NAMES[0]).toBe('pages');
		expect(SITEMAP_NAMES).toContain('anime-1');
		expect(SITEMAP_NAMES).toContain('airing-1');
		expect(SITEMAP_NAMES).toContain('studios-1');
		expect(new Set(SITEMAP_NAMES).size).toBe(SITEMAP_NAMES.length);
	});

	it('parses only the names the index lists', () => {
		expect(parseSitemapName('anime-2')).toEqual({ kind: 'anime', index: 2 });
		expect(parseSitemapName('anime-0')).toBeNull();
		expect(parseSitemapName('anime-99')).toBeNull();
		expect(parseSitemapName('constructor-1')).toBeNull();
		expect(parseSitemapName('pages')).toBeNull();
		for (const name of SITEMAP_NAMES.slice(1)) expect(parseSitemapName(name)).not.toBeNull();
	});
});

describe('sitemapQuery', () => {
	it('asks for ten aliased pages of 50, from where the sitemap starts', () => {
		const query = sitemapQuery('anime', 2);
		expect(query.match(/: Page\(/g)).toHaveLength(10);
		expect(query).toContain('p0: Page(page: 11, perPage: 50)');
		expect(query).toContain('p9: Page(page: 20, perPage: 50)');
		expect(query).toContain('isAdult: false');
	});
});

describe('fetchSitemap', () => {
	it('turns the pages into urls, in order, without repeats', async () => {
		type Item = { id: number; updatedAt?: number } | null;
		const pages: Record<string, { media: Item[] | null }> = Object.fromEntries(
			Array.from({ length: 10 }, (_, i) => [`p${i}`, { media: i ? [] : null }])
		);
		pages.p0 = { media: [{ id: 1, updatedAt: 1700000000 }, { id: 2 }] };
		pages.p1 = { media: [{ id: 1, updatedAt: 1700000000 }, null, { id: 3 }] };
		const fetchMock = vi.fn(async () => Response.json({ data: pages }));
		vi.stubGlobal('fetch', fetchMock);

		expect(await fetchSitemap('anime', 1)).toEqual([
			{ path: '/title/1', updatedAt: 1700000000 },
			{ path: '/title/2', updatedAt: undefined },
			{ path: '/title/3', updatedAt: undefined }
		]);
		expect(fetchMock).toHaveBeenCalledOnce();
	});
});

describe('xml', () => {
	it('writes absolute urls, with lastmod when known', () => {
		const xml = urlsetXml([{ path: '/title/1', updatedAt: 1700000000 }, { path: '/seasonal' }]);
		expect(xml).toContain(
			'<url><loc>https://miruyo.jnagra.com/title/1</loc><lastmod>2023-11-14T22:13:20.000Z</lastmod></url>'
		);
		expect(xml).toContain('<url><loc>https://miruyo.jnagra.com/seasonal</loc></url>');
	});

	it('indexes each sitemap under /sitemaps', () => {
		expect(indexXml(['pages', 'anime-1'])).toContain(
			'<sitemap><loc>https://miruyo.jnagra.com/sitemaps/anime-1.xml</loc></sitemap>'
		);
	});
});
