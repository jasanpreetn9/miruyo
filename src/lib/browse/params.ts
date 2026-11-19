import type { MediaSeason, MediaType } from '#lib/anilist/types.ts';

// Browse's whole state lives in the URL (?q=…&genre=…&sort=…), so results can
// be shared, reloaded, and walked back with the browser's back button. This
// module converts URL ↔ state ↔ AniList query variables, and nothing else.

export type BrowseSort = 'popularity' | 'score' | 'trending' | 'newest';
export type BrowseView = 'grid' | 'list';
export type Country = 'JP' | 'KR' | 'CN';

export interface BrowseState {
	q: string;
	genres: string[];
	tags: string[];
	/** Genres and tags a title mustn't have (?not_genre=Romance). */
	notGenres: string[];
	notTags: string[];
	/** AniList MediaFormat values, e.g. TV, MOVIE, MANGA. */
	formats: string[];
	/** AniList MediaStatus, e.g. RELEASING; '' = any. */
	status: string;
	/** Anime only. */
	season: MediaSeason | '';
	year: number | null;
	/** Manga only. */
	country: Country | '';
	/** 0–10 in half steps; 0 and 10 mean "no bound". */
	scoreMin: number;
	scoreMax: number;
	hideOnList: boolean;
	sort: BrowseSort;
	view: BrowseView;
}

export const SCORE_MAX = 10;

export const DEFAULT_STATE: BrowseState = {
	q: '',
	genres: [],
	tags: [],
	notGenres: [],
	notTags: [],
	formats: [],
	status: '',
	season: '',
	year: null,
	country: '',
	scoreMin: 0,
	scoreMax: SCORE_MAX,
	hideOnList: false,
	sort: 'popularity',
	view: 'grid'
};

export const SORTS: { key: BrowseSort; label: string; anilist: string }[] = [
	{ key: 'popularity', label: 'Popularity', anilist: 'POPULARITY_DESC' },
	{ key: 'score', label: 'Score', anilist: 'SCORE_DESC' },
	{ key: 'trending', label: 'Trending', anilist: 'TRENDING_DESC' },
	{ key: 'newest', label: 'Newest', anilist: 'START_DATE_DESC' }
];

export const ANIME_FORMATS: { key: string; label: string }[] = [
	{ key: 'TV', label: 'TV' },
	{ key: 'MOVIE', label: 'Movie' },
	{ key: 'OVA', label: 'OVA' },
	{ key: 'ONA', label: 'ONA' },
	{ key: 'TV_SHORT', label: 'TV Short' },
	{ key: 'SPECIAL', label: 'Special' }
];

// Manhwa and manhua aren't AniList formats — they're manga from Korea and
// China, so they're under Country of origin instead.
export const MANGA_FORMATS: { key: string; label: string }[] = [
	{ key: 'MANGA', label: 'Manga' },
	{ key: 'NOVEL', label: 'Light novel' },
	{ key: 'ONE_SHOT', label: 'One-shot' }
];

export const STATUSES: { key: string; label: string }[] = [
	{ key: 'RELEASING', label: 'Releasing' },
	{ key: 'FINISHED', label: 'Finished' },
	{ key: 'NOT_YET_RELEASED', label: 'Not yet released' },
	{ key: 'HIATUS', label: 'Hiatus' },
	{ key: 'CANCELLED', label: 'Cancelled' }
];

export const SEASONS: { key: MediaSeason; label: string }[] = [
	{ key: 'WINTER', label: 'Winter' },
	{ key: 'SPRING', label: 'Spring' },
	{ key: 'SUMMER', label: 'Summer' },
	{ key: 'FALL', label: 'Fall' }
];

export const COUNTRIES: { key: Country; label: string; long: string }[] = [
	{ key: 'JP', label: 'JP', long: 'Japan' },
	{ key: 'KR', label: 'KR', long: 'Korea (manhwa)' },
	{ key: 'CN', label: 'CN', long: 'China (manhua)' }
];

function formatsFor(isAnime: boolean) {
	return isAnime ? ANIME_FORMATS : MANGA_FORMATS;
}

function clampScore(value: number): number {
	if (!Number.isFinite(value)) return 0;
	return Math.min(SCORE_MAX, Math.max(0, Math.round(value * 2) / 2));
}

/**
 * Reads Browse state from the URL. Unknown or mode-inappropriate values are
 * dropped (e.g. a manga format while browsing anime), so a hand-edited or
 * stale link can't produce an impossible query.
 */
export function parseBrowseParams(
	params: Pick<URLSearchParams, 'get' | 'getAll'>,
	isAnime: boolean
): BrowseState {
	const formatKeys = new Set(formatsFor(isAnime).map((f) => f.key));
	const statusKeys = new Set(STATUSES.map((s) => s.key));
	const seasonKeys = new Set<string>(SEASONS.map((s) => s.key));
	const countryKeys = new Set<string>(COUNTRIES.map((c) => c.key));
	const sortKeys = new Set<string>(SORTS.map((s) => s.key));

	const year = Number(params.get('year'));
	const scoreMin = clampScore(Number(params.get('min') ?? 0));
	const scoreMax = clampScore(Number(params.get('max') ?? SCORE_MAX));
	const season = params.get('season') ?? '';
	const country = params.get('country') ?? '';
	const sort = params.get('sort') ?? '';
	const genres = params.getAll('genre');
	const tags = params.getAll('tag');

	return {
		q: params.get('q') ?? '',
		genres,
		tags,
		// in and out at once can't both hold: in wins
		notGenres: params.getAll('not_genre').filter((g) => !genres.includes(g)),
		notTags: params.getAll('not_tag').filter((t) => !tags.includes(t)),
		formats: params.getAll('format').filter((f) => formatKeys.has(f)),
		status: statusKeys.has(params.get('status') ?? '') ? params.get('status')! : '',
		season: isAnime && seasonKeys.has(season) ? (season as MediaSeason) : '',
		year: isAnime && Number.isInteger(year) && year > 1900 ? year : null,
		country: !isAnime && countryKeys.has(country) ? (country as Country) : '',
		scoreMin: Math.min(scoreMin, scoreMax),
		scoreMax: Math.max(scoreMin, scoreMax),
		hideOnList: params.get('hide') === '1',
		sort: sortKeys.has(sort) ? (sort as BrowseSort) : DEFAULT_STATE.sort,
		view: params.get('view') === 'list' ? 'list' : 'grid'
	};
}

/** The URL query for `state`, leaving defaults out so links stay short. */
export function toSearchParams(state: BrowseState): URLSearchParams {
	const p = new URLSearchParams();
	if (state.q.trim()) p.set('q', state.q.trim());
	for (const g of state.genres) p.append('genre', g);
	for (const t of state.tags) p.append('tag', t);
	for (const g of state.notGenres) p.append('not_genre', g);
	for (const t of state.notTags) p.append('not_tag', t);
	for (const f of state.formats) p.append('format', f);
	if (state.status) p.set('status', state.status);
	if (state.season) p.set('season', state.season);
	if (state.year) p.set('year', String(state.year));
	if (state.country) p.set('country', state.country);
	if (state.scoreMin > 0) p.set('min', String(state.scoreMin));
	if (state.scoreMax < SCORE_MAX) p.set('max', String(state.scoreMax));
	if (state.hideOnList) p.set('hide', '1');
	if (state.sort !== DEFAULT_STATE.sort) p.set('sort', state.sort);
	if (state.view !== DEFAULT_STATE.view) p.set('view', state.view);
	return p;
}

export interface QueryContext {
	type: MediaType;
	/** onList filtering needs a signed-in viewer. */
	signedIn: boolean;
	/** When false, 18+ titles are left out of results. */
	showAdult: boolean;
	page?: number;
	perPage?: number;
}

/** AniList variables for BROWSE_QUERY. Unset filters are left out entirely. */
export function toQueryVariables(state: BrowseState, ctx: QueryContext): Record<string, unknown> {
	const nonEmpty = (list: string[]) => (list.length ? list : null);
	const variables: Record<string, unknown> = {
		page: ctx.page ?? 1,
		perPage: ctx.perPage ?? 30,
		type: ctx.type,
		search: state.q.trim() || null,
		genres: nonEmpty(state.genres),
		tags: nonEmpty(state.tags),
		notGenres: nonEmpty(state.notGenres),
		notTags: nonEmpty(state.notTags),
		formats: nonEmpty(state.formats),
		status: state.status || null,
		season: ctx.type === 'ANIME' ? state.season || null : null,
		seasonYear: ctx.type === 'ANIME' ? state.year : null,
		country: ctx.type === 'MANGA' ? state.country || null : null,
		// AniList's bounds are exclusive and on a 100-point scale
		scoreAbove: state.scoreMin > 0 ? Math.round(state.scoreMin * 10) - 1 : null,
		scoreBelow: state.scoreMax < SCORE_MAX ? Math.round(state.scoreMax * 10) + 1 : null,
		onList: ctx.signedIn && state.hideOnList ? false : null,
		isAdult: ctx.showAdult ? null : false,
		sort: [SORTS.find((s) => s.key === state.sort)!.anilist]
	};
	// Unset filters are left out rather than sent as null: AniList answers
	// `format_in: null` with a 500 and a null score bound with a 400.
	for (const key of Object.keys(variables)) {
		if (variables[key] === null) delete variables[key];
	}
	return variables;
}

export interface FilterChip {
	/** Stable key for keyed each blocks. */
	key: string;
	label: string;
	/** The state with just this filter removed. */
	without: Partial<BrowseState>;
}

const formatScore = (n: number) => n.toFixed(1);

/** Every active filter as a removable chip (design: "chips mirror state"). */
export function activeFilters(state: BrowseState, isAnime: boolean): FilterChip[] {
	const chips: FilterChip[] = [];
	for (const g of state.genres) {
		chips.push({
			key: `genre:${g}`,
			label: g,
			without: { genres: state.genres.filter((x) => x !== g) }
		});
	}
	for (const t of state.tags) {
		chips.push({ key: `tag:${t}`, label: t, without: { tags: state.tags.filter((x) => x !== t) } });
	}
	for (const g of state.notGenres) {
		chips.push({
			key: `not_genre:${g}`,
			label: `Not ${g}`,
			without: { notGenres: state.notGenres.filter((x) => x !== g) }
		});
	}
	for (const t of state.notTags) {
		chips.push({
			key: `not_tag:${t}`,
			label: `Not ${t}`,
			without: { notTags: state.notTags.filter((x) => x !== t) }
		});
	}
	if (state.season || state.year) {
		const season = SEASONS.find((s) => s.key === state.season)?.label;
		chips.push({
			key: 'season',
			label: [season, state.year].filter(Boolean).join(' '),
			without: { season: '', year: null }
		});
	}
	if (state.country) {
		chips.push({
			key: 'country',
			label: COUNTRIES.find((c) => c.key === state.country)!.long,
			without: { country: '' }
		});
	}
	for (const f of state.formats) {
		const label = formatsFor(isAnime).find((x) => x.key === f)?.label ?? f;
		chips.push({
			key: `format:${f}`,
			label,
			without: { formats: state.formats.filter((x) => x !== f) }
		});
	}
	if (state.status) {
		chips.push({
			key: 'status',
			label: STATUSES.find((s) => s.key === state.status)?.label ?? state.status,
			without: { status: '' }
		});
	}
	if (state.scoreMin > 0 || state.scoreMax < SCORE_MAX) {
		chips.push({
			key: 'score',
			label:
				state.scoreMax < SCORE_MAX
					? `Score ${formatScore(state.scoreMin)}–${formatScore(state.scoreMax)}`
					: `Score ≥ ${formatScore(state.scoreMin)}`,
			without: { scoreMin: 0, scoreMax: SCORE_MAX }
		});
	}
	if (state.hideOnList) {
		chips.push({ key: 'hide', label: 'Not on my list', without: { hideOnList: false } });
	}
	return chips;
}

/**
 * What Browse calls itself: the list a "See all" opened ("Trending anime",
 * "Popular releasing manga"), or null for plain browsing and searches.
 */
export function browseTitle(state: BrowseState, isAnime: boolean): string | null {
	if (state.q) return null;
	const noun = isAnime ? 'anime' : 'manga';
	if (state.sort === 'trending') return `Trending ${noun}`;
	if (state.sort === 'score') return `Top-rated ${noun}`;
	if (state.sort === 'newest') return `Newest ${noun}`;
	if (state.status === 'RELEASING') return `Popular ${isAnime ? 'airing' : 'releasing'} ${noun}`;
	if (state.status === 'NOT_YET_RELEASED') return `Upcoming ${noun}`;
	return null;
}

export interface BrowsePreset {
	key: string;
	label: string;
	/** Everything but the view: a preset is a starting point, not a filter on top. */
	state: Partial<BrowseState>;
}

/**
 * Ready-made lists above the results, like AniList's search page: the
 * all-time popular (plain Browse), trending, top rated, what's out now and
 * what's coming.
 */
export function browsePresets(isAnime: boolean): BrowsePreset[] {
	return [
		{ key: 'popular', label: 'All-time popular', state: {} },
		{ key: 'trending', label: 'Trending', state: { sort: 'trending' } },
		{ key: 'top', label: 'Top rated', state: { sort: 'score' } },
		{ key: 'airing', label: isAnime ? 'Airing now' : 'Releasing', state: { status: 'RELEASING' } },
		{ key: 'upcoming', label: 'Upcoming', state: { status: 'NOT_YET_RELEASED' } }
	];
}

/** The preset `state` is exactly (whatever its view), or null. */
export function activePreset(state: BrowseState, isAnime: boolean): string | null {
	const same = (preset: BrowsePreset) =>
		toSearchParams({ ...state, view: DEFAULT_STATE.view }).toString() ===
		toSearchParams({ ...DEFAULT_STATE, ...preset.state }).toString();
	return browsePresets(isAnime).find(same)?.key ?? null;
}

/**
 * Results in a ranked order (by score, popularity or trending, with no search
 * text deciding it) carry their place: #1, #2…
 */
export function isRanked(state: BrowseState): boolean {
	return !state.q.trim() && state.sort !== 'newest';
}

/** Filters only, not the search text, sort or view. */
export function withoutFilters(state: BrowseState): BrowseState {
	return { ...DEFAULT_STATE, q: state.q, sort: state.sort, view: state.view };
}

/** Clears the fields that don't apply in the other mode (season/year vs. country, formats). */
export function forMode(state: BrowseState, isAnime: boolean): BrowseState {
	return parseBrowseParams(toSearchParams(state), isAnime);
}
