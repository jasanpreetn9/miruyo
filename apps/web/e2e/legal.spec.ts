import { test, expect } from '@playwright/test';
import { gotoHydrated } from './hydrated.ts';
import { mockPublicTrending } from './mock-auth.ts';

const PAGES = [
	{ path: '/privacy', heading: 'Privacy Policy' },
	{ path: '/terms', heading: 'Terms of Use' },
	{ path: '/cookies', heading: 'Cookies & Storage' },
	{ path: '/support', heading: 'Support' }
];

for (const { path, heading } of PAGES) {
	test(`${heading} renders signed out, and links to the other documents`, async ({ page }) => {
		await page.setViewportSize({ width: 1440, height: 900 });
		await gotoHydrated(page, path);
		await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible();

		const nav = page.getByRole('navigation', { name: 'Legal documents' });
		await expect(nav.getByRole('link', { name: heading })).toHaveAttribute('aria-current', 'page');
		for (const other of PAGES.filter((p) => p.path !== path)) {
			await expect(nav.getByRole('link', { name: other.heading })).toHaveAttribute(
				'href',
				other.path
			);
		}
	});
}

test('Cookies & Storage lists every local storage key the app uses', async ({ page }) => {
	await gotoHydrated(page, '/cookies');
	const keys = await import('../src/lib/storage-keys.ts');
	for (const key of Object.values(keys)) {
		await expect(page.getByRole('cell', { name: key, exact: true })).toBeVisible();
	}
});

test('login links to the Terms and Privacy Policy', async ({ page }) => {
	await mockPublicTrending(page);
	await page.setViewportSize({ width: 1440, height: 900 });
	await gotoHydrated(page, '/login');

	await page.getByRole('link', { name: 'Terms of Use' }).click();
	await expect(page).toHaveURL('/terms');

	// a fresh load rather than goBack, which can leave /terms (and its own
	// Privacy Policy link) on screen while /login comes back
	await gotoHydrated(page, '/login');
	await page.getByRole('link', { name: 'Privacy Policy' }).click();
	await expect(page).toHaveURL('/privacy');
});

test('analytics load only in production: the dev server sends nothing', async ({ page }) => {
	const analytics: string[] = [];
	page.on('request', (r) => {
		if (/\/_vercel\/|vercel-scripts\.com/.test(r.url())) analytics.push(r.url());
	});
	await page.goto('/privacy');
	await expect(page.getByText('Vercel Web Analytics and Speed Insights')).toBeVisible();
	await page.waitForLoadState('networkidle');
	expect(analytics).toEqual([]);
});

test('the privacy policy names Cloudflare, and the sign-in callback keeps its beacon out', async ({
	page,
	request
}) => {
	await page.goto('/privacy');
	await expect(
		page.locator('li', { hasText: 'Cloudflare sits in front of the site' })
	).toContainText('Web Analytics');

	// Cloudflare's proxy injects its beacon into every page; the CSP lets it run
	// everywhere but the callback, whose address carries the AniList token
	const csp = async (path: string) =>
		(await request.get(path)).headers()['content-security-policy'] ?? '';
	expect(await csp('/')).toContain('https://static.cloudflareinsights.com');
	expect(await csp('/')).toContain('https://cloudflareinsights.com');
	expect(await csp('/api/callback')).not.toContain('cloudflareinsights');
});

test('every page sends the security headers, opener isolation included', async ({ request }) => {
	for (const path of ['/', '/browse', '/api/callback']) {
		const headers = (await request.get(path)).headers();
		expect(headers['cross-origin-opener-policy'], path).toBe('same-origin');
		expect(headers['strict-transport-security'], path).toMatch(
			/^max-age=63072000; includeSubDomains/
		);
		expect(headers['x-content-type-options'], path).toBe('nosniff');
		expect(headers['x-frame-options'], path).toBe('DENY');
	}
});
