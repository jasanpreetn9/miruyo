import { error, type ServerLoadEvent } from '@sveltejs/kit';
import { SSR_ANILIST } from '$app/env/private';
import { isAniListError } from '#lib/anilist/client.ts';

// Public pages (a title, the season chart, the schedule) render their
// signed-out data on the server, so search engines and link previews see the
// page itself instead of a skeleton. The viewer's own data (list state,
// preferred titles, 18+) still loads in the browser, as before.

/**
 * The page is the same for everyone, so the CDN can share it: fresh for ten
 * minutes, then served stale for up to a day while it refreshes. That keeps
 * crawlers and link previews from spending AniList's rate limit.
 */
export const PUBLIC_CACHE = 'public, max-age=0, s-maxage=600, stale-while-revalidate=86400';

/** A navigation's data request: always null here, so it can be kept for a day. */
export const DATA_REQUEST_CACHE = 'public, max-age=0, s-maxage=86400';

/**
 * Fetches a page's public data for the first render, or null when there's
 * nothing to add: on client-side navigation (the page fetches in the browser,
 * so a click never waits on this server), when SSR_ANILIST is off, and when
 * AniList fails (the page
 * then loads as it did before, with its own retry). AniList's 404 is the
 * page's 404.
 */
export async function loadPublic<T>(
	event: Pick<ServerLoadEvent, 'isDataRequest' | 'setHeaders'>,
	fetch: () => Promise<T>
): Promise<T | null> {
	// a client-side navigation's data request answers the same null to everyone,
	// so the CDN keeps it rather than waking the server each time
	if (event.isDataRequest) {
		event.setHeaders({ 'cache-control': DATA_REQUEST_CACHE });
		return null;
	}
	if (!SSR_ANILIST) return null;
	try {
		const data = await fetch();
		event.setHeaders({ 'cache-control': PUBLIC_CACHE });
		return data;
	} catch (err) {
		if (isAniListError(err, 'api') && err.status === 404) error(404, 'Not found');
		console.error('Server render without AniList data:', err);
		return null;
	}
}
