import { describe, expect, it } from 'vitest';

describe('SvelteKit 3', () => {
	// $app/stores is a stub in SvelteKit 3 that throws when used
	// (app_stores_removed); a dependency that used it took production down
	// on Nov 2, 2026.
	const sources = import.meta.glob('/src/**/*.{ts,svelte}', {
		query: '?raw',
		import: 'default',
		eager: true
	}) as Record<string, string>;

	it('nothing in the app imports $app/stores', () => {
		for (const [file, text] of Object.entries(sources)) {
			if (file.endsWith('.test.ts')) continue;
			expect(text, file).not.toMatch(/from ['"]\$app\/stores['"]/);
		}
	});
});
