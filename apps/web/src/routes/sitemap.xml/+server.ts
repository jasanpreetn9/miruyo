import { indexXml, SITEMAP_NAMES } from '#lib/server/sitemap.ts';
import type { RequestHandler } from './$types';

// The index of the site's sitemaps (lib/server/sitemap.ts); robots.txt points here.
export const prerender = true;

export const GET: RequestHandler = () =>
	new Response(indexXml(SITEMAP_NAMES), { headers: { 'Content-Type': 'application/xml' } });
