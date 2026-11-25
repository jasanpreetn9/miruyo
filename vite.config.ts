/// <reference types="vitest/config" />
import tailwindcss from '@tailwindcss/vite';
import adapter from '@sveltejs/adapter-cloudflare';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => ({
	plugins: [
		tailwindcss(),
		sveltekit({
			compilerOptions: {
				// Force runes mode for the project, except for libraries. Can be removed in svelte 6.
				runes: ({ filename }) =>
					filename.split(/[/\\]/).includes('node_modules') ? undefined : true
			},
			adapter: adapter(),
			// one JS and one CSS file rather than a chunk per route: a first visit
			// is a few requests instead of ~38 (crawlers that run JS cache nothing)
			output: { bundleStrategy: 'single' },
			// SvelteKit hashes its own inline scripts. Hashes, not nonces: public
			// pages are cached at the edge (src/hooks.server.ts), and a
			// nonce shared by every visitor protects nothing. Inline styles stay
			// allowed: covers and accents are style attributes. The other security
			// headers are set in src/hooks.server.ts.
			csp: {
				mode: 'hash',
				directives: {
					'default-src': ['self'],
					// Svelte's server-rendered <img onload> just records the event for
					// hydration to replay; that one handler is allowed by its hash
					'script-src': [
						'self',
						// Cloudflare Web Analytics: its proxy injects the beacon into every
						// page (kept off the sign-in callback: src/lib/untracked.ts)
						'https://static.cloudflareinsights.com',
						'unsafe-hashes',
						'sha256-7dQwUgLau1NFCCGjfn9FsYptB6ZtWxJin6VohGIu20I='
					],
					'style-src': ['self', 'unsafe-inline', 'https://fonts.googleapis.com'],
					'font-src': ['self', 'https://fonts.gstatic.com'],
					// covers and avatars come from AniList's CDN (and YouTube's for trailers)
					'img-src': ['self', 'data:', 'blob:', 'https:'],
					// …and the beacon reports page views here
					'connect-src': ['self', 'https://graphql.anilist.co', 'https://cloudflareinsights.com'],
					'object-src': ['none'],
					'base-uri': ['self'],
					'form-action': ['self'],
					'frame-ancestors': ['none']
				}
			},
			// e2e's dev server generates into its own folder: sharing .svelte-kit
			// would rewrite the running `npm run dev`'s env (its dev token) too
			outDir: loadEnv(mode, '.', 'KIT_').KIT_OUT_DIR || '.svelte-kit'
		})
	],
	test: {
		// unit tests only — Playwright specs in e2e/ run via `npm run test:e2e`
		include: ['src/**/*.test.ts']
	}
}));
