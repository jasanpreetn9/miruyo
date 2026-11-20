import { describe, expect, it } from 'vitest';
import { cleanUrl } from './analytics.ts';

describe('cleanUrl', () => {
	it('drops the query and fragment', () => {
		expect(cleanUrl('https://example.com/browse?q=frieren&genre=Drama#top')).toBe(
			'https://example.com/browse'
		);
		expect(cleanUrl('https://example.com/title/154587')).toBe('https://example.com/title/154587');
	});

	it('never reports the sign-in callback, whose fragment is the access token', () => {
		expect(
			cleanUrl('https://example.com/api/callback#access_token=secret&token_type=Bearer')
		).toBeNull();
		expect(cleanUrl('/api/callback?state=x')).toBeNull();
	});

	it('keeps a bare path a path', () => {
		expect(cleanUrl('/list?tab=completed')).toBe('/list');
	});

	it("doesn't confuse a similar path with the callback", () => {
		expect(cleanUrl('https://example.com/api/callbacks')).toBe('https://example.com/api/callbacks');
	});
});

describe('what analytics loads', () => {
	// $app/stores is a stub in SvelteKit 3 that throws when used
	// (app_stores_removed); the packages' /sveltekit entry points use it, and
	// loading them took production down.
	const sources = import.meta.glob('/src/**/*.{ts,svelte}', {
		query: '?raw',
		import: 'default',
		eager: true
	}) as Record<string, string>;

	it('uses the plain Vercel entry points, not their /sveltekit ones', () => {
		const analytics = sources['/src/lib/analytics.ts'];
		expect(analytics).toContain("from '@vercel/analytics'");
		expect(analytics).toContain("from '@vercel/speed-insights'");
		for (const [file, text] of Object.entries(sources)) {
			expect(text, file).not.toMatch(/@vercel\/(analytics|speed-insights)\/sveltekit/);
		}
	});

	it('nothing in the app imports $app/stores', () => {
		for (const [file, text] of Object.entries(sources)) {
			if (file.endsWith('.test.ts')) continue;
			expect(text, file).not.toMatch(/from ['"]\$app\/stores['"]/);
		}
	});
});
