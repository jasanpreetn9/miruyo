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
	 * the browser. The e2e server sets it, since its tests mock AniList in the
	 * browser only.
	 */
	SSR_ANILIST: {
		schema: (value) => value?.trim() !== 'off'
	}
});
