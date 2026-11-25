// Pages no analytics may see, and the Cloudflare Web Analytics hosts the CSP
// allows everywhere else.
//
// The sign-in callback's fragment carries the AniList token
// (/api/callback#access_token=…). Cloudflare's analytics beacon, which
// Cloudflare injects into every page, is kept off it by that page's CSP
// (hooks.server.ts): the page scrubs the
// token from the address as soon as it runs, but the beacon could read it
// first.

/** The routes never reported, by path. */
export const UNTRACKED_PATHS = ['/api/callback'];

export function isUntracked(pathname: string): boolean {
	return UNTRACKED_PATHS.some((path) => pathname === path || pathname.startsWith(`${path}/`));
}

/** Cloudflare Web Analytics: its beacon script, and where it sends page views. */
export const CLOUDFLARE_ANALYTICS = {
	script: 'https://static.cloudflareinsights.com',
	report: 'https://cloudflareinsights.com'
} as const;

/** A Content-Security-Policy header with Cloudflare's analytics hosts taken out. */
export function withoutCloudflareAnalytics(csp: string): string {
	const hosts = new Set<string>(Object.values(CLOUDFLARE_ANALYTICS));
	return csp
		.split(';')
		.map((directive) =>
			directive
				.trim()
				.split(/\s+/)
				.filter((part) => !hosts.has(part))
				.join(' ')
		)
		.filter(Boolean)
		.join('; ');
}
