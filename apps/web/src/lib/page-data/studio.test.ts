import { describe, expect, it } from 'vitest';
import { makePersonMedia } from '#lib/anilist/fixtures.ts';
import type { StudioPage } from '#lib/anilist/types.ts';
import { createStudioContent } from './studio.ts';

const studio = (overrides: Partial<StudioPage> = {}): StudioPage => ({
	id: 11,
	name: 'MADHOUSE',
	isAnimationStudio: true,
	siteUrl: 'https://anilist.co/studio/11',
	favourites: 20029,
	isFavourite: false,
	media: { pageInfo: { total: 500, hasNextPage: true }, edges: [] },
	...overrides
});

describe('createStudioContent', () => {
	it('says what the studio is, with its favourites and AniList link', () => {
		const content = createStudioContent(studio());
		expect(content).toMatchObject({
			id: 11,
			name: 'MADHOUSE',
			kind: 'Animation studio',
			favourites: '20k',
			isFavourite: false,
			anilistHref: 'https://anilist.co/studio/11',
			hasMore: true
		});
		expect(createStudioContent(studio({ isAnimationStudio: false })).kind).toBe('Studio');
		// a link that isn't AniList's falls back to its studio address
		expect(createStudioContent(studio({ siteUrl: 'https://evil.example/11' })).anilistHref).toBe(
			'https://anilist.co/studio/11'
		);
	});

	it('lists its titles once each, marking the ones it only produced', () => {
		const content = createStudioContent(
			studio({
				media: {
					pageInfo: { total: 3, hasNextPage: false },
					edges: [
						{ isMainStudio: true, node: makePersonMedia({ id: 1 }) },
						{ isMainStudio: false, node: makePersonMedia({ id: 2, format: 'MOVIE' }) },
						{ isMainStudio: true, node: makePersonMedia({ id: 1 }) }
					]
				}
			}),
			{ titles: 'english' }
		);
		expect(content.titles.map((t) => [t.key, t.caption, t.media.meta])).toEqual([
			['1', null, '2023 · TV'],
			['2', 'Producer', '2023 · Movie']
		]);
		expect(content.titles[0].media.title).toBe('English Title');
		expect(content.hasMore).toBe(false);
	});

	it('leaves 18+ titles out unless the account shows them', () => {
		const data = studio({
			media: {
				pageInfo: { total: 2, hasNextPage: false },
				edges: [
					{ isMainStudio: true, node: makePersonMedia({ id: 1 }) },
					{ isMainStudio: true, node: makePersonMedia({ id: 2, isAdult: true }) }
				]
			}
		});
		expect(createStudioContent(data).titles.map((t) => t.key)).toEqual(['1']);
		expect(createStudioContent(data, { adult: true }).titles.map((t) => t.key)).toEqual(['1', '2']);
	});
});
