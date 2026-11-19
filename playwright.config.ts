import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
	testDir: 'e2e',
	// Its own port and always a fresh server: reusing a long-running `npm run
	// dev` on 5173 can serve stale modules (e.g. a file added since it
	// started) and fail tests that pass on a clean start.
	webServer: {
		command: 'npx vite dev --port 5180 --strictPort',
		port: 5180,
		reuseExistingServer: false,
		// a dev token in .env would sign every test in: the mocks decide that.
		// The mocks only reach the browser, so the server leaves AniList alone.
		// Its own outDir, so it doesn't rewrite a running dev server's env.
		env: { PUBLIC_DEV_ANILIST_TOKEN: '', SSR_ANILIST: 'off', KIT_OUT_DIR: '.svelte-kit-e2e' }
	},
	use: {
		baseURL: 'http://localhost:5180'
	},
	projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }]
});
