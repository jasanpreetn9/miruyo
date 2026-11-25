import type { Handle } from '@sveltejs/kit/hooks';
import { isUntracked, withoutCloudflareAnalytics } from '#lib/untracked.ts';

/** Sent with every page; the Content-Security-Policy is in vite.config.ts. */
const SECURITY_HEADERS = {
	// older browsers ignore CSP's frame-ancestors
	'X-Frame-Options': 'DENY',
	'X-Content-Type-Options': 'nosniff',
	'Referrer-Policy': 'strict-origin-when-cross-origin',
	'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=()',
	// two years; no `preload`, which would commit the whole parent domain to
	// the browsers' HTTPS-only list (PageSpeed asks for it, but it's a domain call)
	'Strict-Transport-Security': 'max-age=63072000; includeSubDomains',
	// a page another site opens can't reach back into this one through
	// window.opener (sign-in is a redirect to AniList, not a popup, so nothing
	// here needs an opener)
	'Cross-Origin-Opener-Policy': 'same-origin'
};

/**
 * Cloudflare's cache in front of the Worker. A Worker's own responses aren't
 * cached by the CDN on their own, so public pages (a title, Seasonal,
 * Schedule: the same for everyone, sent with `s-maxage`) are put here
 * explicitly, and served from here until they expire. Absent in dev and in
 * the tests, which run on Node.
 */
function edgeCache(): Cache | null {
	const storage = (globalThis as { caches?: { default?: Cache } }).caches;
	return storage?.default ?? null;
}

const SHARED_CACHE = /(^|,)\s*s-maxage=\d+/;

export const handle: Handle = async ({ event, resolve }) => {
	const cache = event.request.method === 'GET' ? edgeCache() : null;
	const hit = await cache?.match(event.request);
	if (hit) return hit;

	const response = await resolve(event);
	for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
		if (!response.headers.has(name)) response.headers.set(name, value);
	}
	// the sign-in callback carries the AniList token: no analytics beacon there
	const csp = response.headers.get('content-security-policy');
	if (csp && isUntracked(event.url.pathname)) {
		response.headers.set('content-security-policy', withoutCloudflareAnalytics(csp));
	}
	if (
		cache &&
		response.status === 200 &&
		SHARED_CACHE.test(response.headers.get('cache-control') ?? '')
	) {
		await cache.put(event.request, response.clone());
	}
	return response;
};
