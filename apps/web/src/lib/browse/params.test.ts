import { describe, expect, it } from 'vitest';
import {
	activeFilters,
	activePreset,
	browseTitle,
	DEFAULT_STATE,
	forMode,
	isRanked,
	parseBrowseParams,
	toQueryVariables,
	toSearchParams,
	withoutFilters,
	type BrowseState
} from './params.ts';

const state = (overrides: Partial<BrowseState> = {}): BrowseState => ({
	...DEFAULT_STATE,
	...overrides
});

describe('parseBrowseParams', () => {
	it('reads defaults from an empty URL', () => {
		expect(parseBrowseParams(new URLSearchParams(), true)).toEqual(DEFAULT_STATE);
	});

	it('round-trips through the URL', () => {
		const anime = state({
			q: 'frieren',
			genres: ['Fantasy', 'Drama'],
			tags: ['Elf'],
			formats: ['TV', 'MOVIE'],
			status: 'RELEASING',
			season: 'FALL',
			year: 2026,
			scoreMin: 7,
			scoreMax: 9.5,
			hideOnList: true,
			sort: 'score',
			view: 'list'
		});
		expect(parseBrowseParams(toSearchParams(anime), true)).toEqual(anime);

		const manga = state({ country: 'KR', formats: ['MANGA'], status: 'FINISHED' });
		expect(parseBrowseParams(toSearchParams(manga), false)).toEqual(manga);
	});

	it('leaves defaults out of the URL', () => {
		expect(toSearchParams(DEFAULT_STATE).toString()).toBe('');
		expect(toSearchParams(state({ q: '  spaced  ' })).toString()).toBe('q=spaced');
	});

	it('drops values that are unknown or belong to the other mode', () => {
		const p = new URLSearchParams(
			'format=MANGA&format=TV&status=BOGUS&season=FALL&country=KR&sort=nope&view=cards'
		);
		const anime = parseBrowseParams(p, true);
		expect(anime.formats).toEqual(['TV']);
		expect(anime.status).toBe('');
		expect(anime.season).toBe('FALL');
		expect(anime.country).toBe('');
		expect(anime.sort).toBe('popularity');
		expect(anime.view).toBe('grid');

		const manga = parseBrowseParams(p, false);
		expect(manga.formats).toEqual(['MANGA']);
		expect(manga.season).toBe('');
		expect(manga.country).toBe('KR');
	});

	it('clamps and orders the score range', () => {
		const s = parseBrowseParams(new URLSearchParams('min=9.3&max=4'), true);
		expect(s.scoreMin).toBe(4);
		expect(s.scoreMax).toBe(9.5);
		expect(parseBrowseParams(new URLSearchParams('min=-3&max=42'), true)).toMatchObject({
			scoreMin: 0,
			scoreMax: 10
		});
	});
});

describe('toQueryVariables', () => {
	const ctx = { type: 'ANIME' as const, signedIn: true, showAdult: false };

	it('leaves unset filters out (AniList rejects some of them as null)', () => {
		expect(toQueryVariables(DEFAULT_STATE, ctx)).toEqual({
			page: 1,
			perPage: 30,
			type: 'ANIME',
			isAdult: false,
			sort: ['POPULARITY_DESC']
		});
	});

	it('maps the score range to AniList’s exclusive 100-point bounds', () => {
		const v = toQueryVariables(state({ scoreMin: 7, scoreMax: 9 }), ctx);
		expect(v.scoreAbove).toBe(69);
		expect(v.scoreBelow).toBe(91);
	});

	it('only filters by list when signed in', () => {
		expect(toQueryVariables(state({ hideOnList: true }), ctx).onList).toBe(false);
		expect(
			toQueryVariables(state({ hideOnList: true }), { ...ctx, signedIn: false })
		).not.toHaveProperty('onList');
	});

	it('only sends mode-specific filters for their mode', () => {
		const s = state({ season: 'FALL', year: 2026, country: 'JP' });
		const anime = toQueryVariables(s, ctx);
		expect(anime).toMatchObject({ season: 'FALL', seasonYear: 2026 });
		expect(anime).not.toHaveProperty('country');
		const manga = toQueryVariables(s, { ...ctx, type: 'MANGA' });
		expect(manga).toMatchObject({ country: 'JP' });
		expect(manga).not.toHaveProperty('season');
		expect(manga).not.toHaveProperty('seasonYear');
	});

	it('includes 18+ titles only when the account allows them', () => {
		expect(toQueryVariables(DEFAULT_STATE, { ...ctx, showAdult: true })).not.toHaveProperty(
			'isAdult'
		);
	});
});

describe('activeFilters', () => {
	it('makes a removable chip for every active filter', () => {
		const s = state({
			genres: ['Fantasy'],
			tags: ['Elf'],
			season: 'FALL',
			year: 2026,
			formats: ['TV'],
			status: 'RELEASING',
			scoreMin: 7,
			hideOnList: true
		});
		const chips = activeFilters(s, true);
		expect(chips.map((c) => c.label)).toEqual([
			'Fantasy',
			'Elf',
			'Fall 2026',
			'TV',
			'Releasing',
			'Score ≥ 7.0',
			'Not on my list'
		]);
		expect(chips[0].without).toEqual({ genres: [] });
		expect(chips[2].without).toEqual({ season: '', year: null });
	});

	it('labels a closed score range and the manga country', () => {
		const chips = activeFilters(state({ scoreMin: 6, scoreMax: 8.5, country: 'CN' }), false);
		expect(chips.map((c) => c.label)).toEqual(['China (manhua)', 'Score 6.0–8.5']);
	});

	it('has no chips for the search text, sort or view', () => {
		expect(activeFilters(state({ q: 'x', sort: 'score', view: 'list' }), true)).toEqual([]);
	});
});

describe('withoutFilters / forMode', () => {
	it('clears filters but keeps search, sort and view', () => {
		const s = state({ q: 'x', genres: ['Action'], sort: 'score', view: 'list', hideOnList: true });
		expect(withoutFilters(s)).toEqual(state({ q: 'x', sort: 'score', view: 'list' }));
	});

	it('drops the other mode’s fields when switching', () => {
		const anime = state({ season: 'FALL', year: 2026, formats: ['TV'], genres: ['Action'] });
		expect(forMode(anime, false)).toEqual(state({ genres: ['Action'] }));
	});
});

describe('browseTitle', () => {
	it('names the list a See all opened', () => {
		expect(browseTitle(state({ sort: 'trending' }), true)).toBe('Trending anime');
		expect(browseTitle(state({ status: 'RELEASING' }), false)).toBe('Popular releasing manga');
		expect(browseTitle(state({ status: 'RELEASING' }), true)).toBe('Popular airing anime');
		expect(browseTitle(state({ sort: 'score' }), true)).toBe('Top-rated anime');
		expect(browseTitle(state({ sort: 'newest' }), false)).toBe('Newest manga');
	});

	it('is plain Browse otherwise, and while searching', () => {
		expect(browseTitle(state(), true)).toBeNull();
		expect(browseTitle(state({ genres: ['Action'] }), true)).toBeNull();
		expect(browseTitle(state({ sort: 'trending', q: 'frieren' }), true)).toBeNull();
	});
});

describe('excluded genres and tags', () => {
	it('round-trip through the URL and reach AniList as *_not_in', () => {
		const s = state({ genres: ['Action'], notGenres: ['Romance'], notTags: ['Isekai'] });
		const params = toSearchParams(s);
		expect(params.toString()).toBe('genre=Action&not_genre=Romance&not_tag=Isekai');
		expect(parseBrowseParams(params, true)).toEqual(s);
		expect(toQueryVariables(s, { type: 'ANIME', signedIn: false, showAdult: false })).toMatchObject(
			{ genres: ['Action'], notGenres: ['Romance'], notTags: ['Isekai'] }
		);
	});

	it('a genre both in and out of the URL counts as in', () => {
		const parsed = parseBrowseParams(new URLSearchParams('genre=Drama&not_genre=Drama'), true);
		expect(parsed.genres).toEqual(['Drama']);
		expect(parsed.notGenres).toEqual([]);
	});

	it('show as "Not …" chips that remove just themselves', () => {
		const chips = activeFilters(state({ notGenres: ['Romance', 'Ecchi'] }), true);
		expect(chips.map((c) => c.label)).toEqual(['Not Romance', 'Not Ecchi']);
		expect(chips[0].without).toEqual({ notGenres: ['Ecchi'] });
	});

	it('are cleared with the other filters', () => {
		expect(withoutFilters(state({ notGenres: ['Romance'], notTags: ['Isekai'] }))).toEqual(
			DEFAULT_STATE
		);
	});
});

describe('presets and ranks', () => {
	it('names the preset a state is exactly, whatever its view', () => {
		expect(activePreset(DEFAULT_STATE, true)).toBe('popular');
		expect(activePreset(state({ sort: 'score', view: 'list' }), true)).toBe('top');
		expect(activePreset(state({ status: 'NOT_YET_RELEASED' }), false)).toBe('upcoming');
		// a filter on top makes it no preset
		expect(activePreset(state({ sort: 'score', genres: ['Drama'] }), true)).toBeNull();
	});

	it('calls the upcoming list by its name', () => {
		expect(browseTitle(state({ status: 'NOT_YET_RELEASED' }), true)).toBe('Upcoming anime');
	});

	it('ranks ordered lists, not searches or the newest', () => {
		expect(isRanked(state({ sort: 'score' }))).toBe(true);
		expect(isRanked(state({ sort: 'popularity', genres: ['Drama'] }))).toBe(true);
		expect(isRanked(state({ sort: 'score', q: 'frieren' }))).toBe(false);
		expect(isRanked(state({ sort: 'newest' }))).toBe(false);
	});
});
