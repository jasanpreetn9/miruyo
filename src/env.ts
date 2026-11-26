import { defineEnvVars } from '@sveltejs/kit/env';

export const variables = defineEnvVars({
	/**
	 * The AniList API client to sign in with (anilist.co/settings/developer).
	 * A client has one redirect URL, `<origin>/api/callback`, so localhost and
	 * production each need their own.
	 */
	PUBLIC_ANILIST_CLIENT_ID: {
		public: true,
		static: true,
		schema: (value) => {
			if (!value?.trim()) throw new Error('Set it to your AniList client id; see .env.example');
			return value.trim();
		}
	},
	/**
	 * The site's public origin, e.g. `https://miruyo.jnagra.com`: canonical
	 * links, share cards, the sitemap and robots.txt use it. Locally it
	 * defaults to localhost; a Cloudflare build (Workers Builds) refuses to
	 * go without it, rather than publish localhost links.
	 */
	PUBLIC_SITE_URL: {
		public: true,
		static: true,
		schema: (value) => {
			const raw = value?.trim();
			if (!raw) {
				// set by Cloudflare's Workers Builds, read at build time
				const { process } = globalThis as { process?: { env: Record<string, string | undefined> } };
				if (process?.env.WORKERS_CI) {
					throw new Error("Set it to the site's origin, like https://example.com");
				}
				return 'http://localhost:5173';
			}
			try {
				return new URL(raw).origin;
			} catch {
				throw new Error(`Set it to the site's origin, like https://example.com (got ${raw})`);
			}
		}
	},
	/**
	 * Dev only: an AniList token to start signed in with, for when the
	 * sign-in page won't load (Cloudflare's check in an embedded browser).
	 * Copy `anilist_token` from a signed-in browser's localStorage. Never set
	 * it on a deployment: public variables ship in the client bundle.
	 */
	PUBLIC_DEV_ANILIST_TOKEN: {
		public: true,
		static: true,
		schema: (value) => value?.trim() ?? ''
	},
	/**
	 * Set to `off` to skip the server's AniList fetch on public pages (see
	 * src/lib/server/public-load.ts): they then render as skeletons and load in
	 * the browser, and the AniList sitemaps answer 503. The e2e server sets it,
	 * since its tests mock AniList in the browser only.
	 */
	SSR_ANILIST: {
		schema: (value) => value?.trim() !== 'off'
	}
});
