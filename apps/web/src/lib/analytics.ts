import { dev } from '$app/env';
import { afterNavigate } from '$app/navigation';
import { page } from '$app/state';
import { inject, pageview } from '@vercel/analytics';
import { injectSpeedInsights } from '@vercel/speed-insights';
import { isUntracked } from './untracked.ts';

// Vercel Web Analytics (anonymous page views: no cookies, nothing that
// identifies anyone) and Speed Insights (how fast pages load). Both are
// served from this site's own /_vercel/ paths, so the CSP's 'self' covers
// them, and both run only in production: dev and the e2e server load
// nothing.
//
// Our own SvelteKit 3 integration on the packages' plain entry points. Their
// /sveltekit ones subscribe to $app/stores, which SvelteKit 3 keeps only as
// a stub that throws (app_stores_removed), and took production down. Here
// SvelteKit's afterNavigate reports each page instead, with its route from
// $app/state (/title/[id]) so the dashboard groups a page's visits whatever
// the id, and tells Speed Insights the route too.
//
// Every event's address is cleaned before it's sent. The sign-in callback's
// fragment carries the AniList token (/api/callback#access_token=…), so that
// page is never reported; and query strings hold what people type (Browse's
// ?q=), so they're dropped everywhere.

/** `url` without its query or fragment, or null for a page that's never reported. */
export function cleanUrl(url: string): string | null {
	try {
		// absolute as the scripts send it; a bare path stays a path
		const u = new URL(url, 'https://relative.invalid');
		if (isUntracked(u.pathname)) return null;
		return u.origin === 'https://relative.invalid' ? u.pathname : u.origin + u.pathname;
	} catch {
		// not a URL we can read: don't send it
		return null;
	}
}

/** An event with its address cleaned, or null to drop it. */
function clean<E extends { url: string }>(event: E): E | null {
	const url = cleanUrl(event.url);
	return url ? { ...event, url } : null;
}

/**
 * Starts both in production. Call once, while the root layout initialises
 * (afterNavigate needs a component).
 */
export function startAnalytics(): void {
	if (dev) return;
	// page views come from afterNavigate below, not the script's own tracking
	inject({ mode: 'production', framework: 'sveltekit', disableAutoTrack: true, beforeSend: clean });
	const speed = injectSpeedInsights({ framework: 'sveltekit', beforeSend: clean });

	// runs after the first page loads and after every navigation
	afterNavigate(({ to }) => {
		if (!to?.url || cleanUrl(to.url.href) === null) return;
		// on the first load `to.route` can be empty; $app/state's page has it by now
		const route = to.route.id ?? page.route.id;
		speed?.setRoute(route);
		pageview({ route, path: to.url.pathname });
	});
}
