import { describe, expect, it, vi } from 'vitest';

const calls: string[] = [];
let release: () => void = () => {};
vi.mock('#lib/anilist/client.ts', () => ({
	fetchListCollection: vi.fn((_: number, type: string) => {
		calls.push(type);
		// the first list holds until released
		return type === 'ANIME' ? new Promise((r) => (release = () => r([]))) : Promise.resolve([]);
	}),
	fetchRecommendations: vi.fn(async () => new Map()),
	fetchRelations: vi.fn(async () => new Map())
}));

const { loadForYou } = await import('./for-you.svelte.ts');

describe('loadForYou', () => {
	it('asks for the other list without waiting for this one', async () => {
		const loading = loadForYou({ userId: 1, type: 'ANIME', showAdult: false, day: '2026-11-17' });
		await Promise.resolve();
		// both asked for before either answers
		expect(calls.toSorted()).toEqual(['ANIME', 'MANGA']);
		release();
		expect((await loading).coldStart).toBe(true);
	});
});
