import { defineConfig, devices } from '@playwright/test';

// The production smoke test (e2e-prod/): the real build, served by SvelteKit's
// preview, so code that only runs in production (analytics) runs too. The
// dev-server e2e suite can't see that code; a crash in it took production
// down on Nov 2, 2026 (app_stores_removed).
//
// Build first: `npm run build`, then `npm run test:prod`. Vercel's adapter
// needs Node 22 or 24 to finish (CI switches to 24); on newer Node its last
// step fails, but the build the preview serves is already written, so this
// still runs.
export default defineConfig({
	testDir: 'e2e-prod',
	webServer: {
		command: 'npx vite preview --port 5181 --strictPort',
		port: 5181,
		reuseExistingServer: false,
		// the server leaves AniList alone; the browser's AniList requests are
		// blocked in the tests, so nothing here depends on AniList being up
		env: { SSR_ANILIST: 'off' }
	},
	use: {
		baseURL: 'http://localhost:5181'
	},
	projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }]
});
