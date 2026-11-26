import { error } from '@sveltejs/kit';
import { SSR_ANILIST } from '$app/env/private';
import {
	fetchSitemap,
	pageEntries,
	parseSitemapName,
	SITEMAP_CACHE,
	urlsetXml
} from '#lib/server/sitemap.ts';
import type { RequestHandler } from './$types';

// One sitemap from the index: the site's own pages, or 500 of AniList's most
// popular titles, staff, characters or studios.
export const GET: RequestHandler = async ({ params }) => {
	const headers = { 'Content-Type': 'application/xml', 'Cache-Control': SITEMAP_CACHE };
	if (params.name === 'pages') return new Response(urlsetXml(pageEntries()), { headers });

	const parsed = parseSitemapName(params.name);
	if (!parsed) error(404, 'Not found');
	if (!SSR_ANILIST) return unavailable();
	try {
		const entries = await fetchSitemap(parsed.kind, parsed.index);
		return new Response(urlsetXml(entries), { headers });
	} catch (err) {
		console.error('Sitemap without AniList data:', err);
		return unavailable();
	}
};

// a 503 tells the crawler to come back, where an empty sitemap would drop its
// pages; with SSR_ANILIST off the server doesn't ask AniList at all
const unavailable = () =>
	new Response('AniList is unavailable; try again later.', {
		status: 503,
		headers: { 'Retry-After': '3600', 'Cache-Control': 'no-store' }
	});
