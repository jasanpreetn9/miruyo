import { adaptMedia, type AdaptOptions } from '#lib/anilist/adapt.ts';
import type { MediaListStatus, MediaSeason, SeasonMedia } from '#lib/anilist/types.ts';
import type { Title } from '#lib/catalog/types.ts';
import { seasonOf, type SeasonRef } from './seasonal.ts';

// The season chart (AniChart's layout): everything premiering in a season,
// in format sections, as big cards with the countdown, source, synopsis,
// genres, score and popularity rank.

const ORDER: MediaSeason[] = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];

export const SEASON_NAMES: Record<MediaSeason, string> = {
	WINTER: 'Winter',
	SPRING: 'Spring',
	SUMMER: 'Summer',
	FALL: 'Fall'
};

export function shiftSeason({ season, year }: SeasonRef, by: number): SeasonRef {
	const index = year * 4 + ORDER.indexOf(season) + by;
	return { season: ORDER[((index % 4) + 4) % 4], year: Math.floor(index / 4) };
}

export function sameSeason(a: SeasonRef, b: SeasonRef): boolean {
	return a.season === b.season && a.year === b.year;
}

/** The season tabs: the one before, the shown one and the two after (AniChart's set, around now). */
export function seasonWindow(shown: SeasonRef): SeasonRef[] {
	return [-1, 0, 1, 2].map((by) => shiftSeason(shown, by));
}

/** The first year with a chart: AniList has next to nothing before it. */
export const FIRST_CHART_YEAR = 1940;
/** How many years past this one have a chart: little is announced further out. */
const YEARS_AHEAD = 2;

/**
 * Whether a season has a chart. Past the range there's nothing to show, and
 * far enough out its airing week overflows AniList's 32-bit timestamps.
 */
export function hasChart({ year }: SeasonRef, now: Date): boolean {
	return year >= FIRST_CHART_YEAR && year <= now.getFullYear() + YEARS_AHEAD;
}

/** `?season=fall&year=2026`; anything missing, invalid or without a chart means the current season. */
export function parseSeasonParams(params: Pick<URLSearchParams, 'get'>, now: Date): SeasonRef {
	const season = params.get('season')?.toUpperCase();
	const year = Number(params.get('year'));
	if (ORDER.includes(season as MediaSeason) && Number.isInteger(year)) {
		const ref = { season: season as MediaSeason, year };
		if (hasChart(ref, now)) return ref;
	}
	return seasonOf(now);
}

/** The /seasonal URL for a season; the current one needs no query. */
export function seasonHref(ref: SeasonRef, now: Date): string {
	return sameSeason(ref, seasonOf(now))
		? '/seasonal'
		: `/seasonal?season=${ref.season.toLowerCase()}&year=${ref.year}`;
}

// ── Cards ──

export type ScoreFace = 'good' | 'ok' | 'bad';

export interface SeasonCard {
	title: Title;
	/** "Ep 2 of 12 airing in", "Premieres", "Released"… */
	whenLabel: string;
	/** "18 hours, 31 mins", "Oct 12, 2026", "TBA". */
	when: string;
	/** Unix seconds of the next episode, for the "airing soonest" sort. */
	nextAt: number | null;
	/** "Sequel to The Apothecary Diaries Season 2", else "Source • Light Novel". */
	origin: string;
	synopsis: string;
	genres: string[];
	/** AniList's average score, 0–100; null when there isn't one yet. */
	score: number | null;
	face: ScoreFace | null;
	/** "#7 most popular" this season; null for leftovers and unranked titles. */
	popularRank: number | null;
	studio: string;
}

export type ChartSort = 'popularity' | 'score' | 'airing' | 'title';

export const CHART_SORTS: { key: ChartSort; label: string }[] = [
	{ key: 'popularity', label: 'Popularity' },
	{ key: 'score', label: 'Score' },
	{ key: 'airing', label: 'Airing soonest' },
	{ key: 'title', label: 'Title' }
];

export interface ChartSection {
	key: string;
	label: string;
	cards: SeasonCard[];
}

interface ChartOptions {
	season: SeasonRef;
	now: Date;
	titles?: AdaptOptions['titles'];
	sort?: ChartSort;
	/** Matches title, English title, studio and genres. */
	filter?: string;
	/** The viewer's live entry for a title, so cards show its status. */
	entry?: (mediaId: number) => { status: MediaListStatus; progress: number } | null | undefined;
}

const SOURCES: Record<string, string> = {
	ORIGINAL: 'Original',
	MANGA: 'Manga',
	LIGHT_NOVEL: 'Light Novel',
	VISUAL_NOVEL: 'Visual Novel',
	VIDEO_GAME: 'Video Game',
	WEB_NOVEL: 'Web Novel',
	NOVEL: 'Novel',
	DOUJINSHI: 'Doujinshi',
	ANIME: 'Anime',
	LIVE_ACTION: 'Live Action',
	GAME: 'Game',
	COMIC: 'Comic',
	MULTIMEDIA_PROJECT: 'Multimedia Project',
	PICTURE_BOOK: 'Picture Book',
	OTHER: 'Other'
};

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const LONG_MONTHS = [
	'January',
	'February',
	'March',
	'April',
	'May',
	'June',
	'July',
	'August',
	'September',
	'October',
	'November',
	'December'
];

/** AniChart's countdown: "1 day, 6 hours", "18 hours, 31 mins", "35 mins". */
export function longDuration(seconds: number): string {
	const s = Math.max(0, Math.floor(seconds));
	const days = Math.floor(s / 86400);
	const hours = Math.floor((s % 86400) / 3600);
	const mins = Math.floor((s % 3600) / 60);
	const part = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;
	if (days)
		return [part(days, 'day', 'days'), hours ? part(hours, 'hour', 'hours') : '']
			.filter(Boolean)
			.join(', ');
	if (hours)
		return [part(hours, 'hour', 'hours'), mins ? part(mins, 'min', 'mins') : '']
			.filter(Boolean)
			.join(', ');
	return part(mins, 'min', 'mins');
}

export function scoreFace(score: number | null): ScoreFace | null {
	if (!score) return null;
	if (score >= 75) return 'good';
	if (score >= 60) return 'ok';
	return 'bad';
}

function dateLabel({ year, month, day }: SeasonMedia['startDate']): string | null {
	if (!year) return null;
	if (!month) return String(year);
	if (!day) return `${LONG_MONTHS[month - 1]} ${year}`;
	return `${MONTHS[month - 1]} ${day}, ${year}`;
}

function whenOf(
	m: SeasonMedia,
	nowSeconds: number
): Pick<SeasonCard, 'whenLabel' | 'when' | 'nextAt'> {
	const next = m.nextAiringEpisode;
	if (next) {
		const of = m.episodes ? ` of ${m.episodes}` : '';
		return {
			whenLabel: `Ep ${next.episode}${of} airing in`,
			when: longDuration(next.airingAt - nowSeconds),
			nextAt: next.airingAt
		};
	}
	const start = dateLabel(m.startDate);
	if (m.status === 'FINISHED') {
		return {
			whenLabel:
				m.format === 'MOVIE' ? 'Released' : m.episodes ? `${m.episodes} episodes · aired` : 'Aired',
			when: start ?? '—',
			nextAt: null
		};
	}
	if (m.status === 'NOT_YET_RELEASED') {
		return { whenLabel: 'Premieres', when: start ?? 'TBA', nextAt: null };
	}
	return { whenLabel: 'Airing', when: start ?? 'TBA', nextAt: null };
}

function prequelTitle(m: SeasonMedia, titles: AdaptOptions['titles']): string | null {
	const edge = m.relations?.edges.find(
		(e) => e.relationType === 'PREQUEL' && e.node.type === 'ANIME'
	);
	if (!edge) return null;
	const t = edge.node.title;
	return (titles === 'english' ? t.english : t.userPreferred) ?? t.english ?? t.romaji;
}

export function buildCard(
	m: SeasonMedia,
	{ season, now, titles = 'userPreferred', entry }: ChartOptions,
	{ leftover = false } = {}
): SeasonCard {
	const live = entry?.(m.id) ?? undefined;
	const title = adaptMedia(m, live ?? undefined, { titles });
	const sequelTo = prequelTitle(m, titles);
	const rank = leftover
		? undefined
		: m.rankings?.find(
				(r) =>
					r.type === 'POPULAR' && !r.allTime && r.season === season.season && r.year === season.year
			);
	return {
		title,
		...whenOf(m, Math.floor(now.getTime() / 1000)),
		origin: sequelTo
			? `Sequel to ${sequelTo}`
			: m.source
				? `Source • ${SOURCES[m.source] ?? m.source}`
				: 'Source • Unknown',
		synopsis: title.synopsis ?? '',
		genres: m.genres.slice(0, 3),
		score: m.averageScore || null,
		face: scoreFace(m.averageScore),
		popularRank: rank?.rank ?? null,
		studio: m.studios.nodes[0]?.name ?? ''
	};
}

const SECTIONS: { key: string; label: string; formats: string[] }[] = [
	{ key: 'tv', label: 'TV', formats: ['TV'] },
	{ key: 'short', label: 'TV Short', formats: ['TV_SHORT'] },
	{ key: 'leftovers', label: 'Leftovers', formats: [] },
	{ key: 'movie', label: 'Movie', formats: ['MOVIE'] },
	{ key: 'other', label: 'OVA / ONA / Special', formats: ['OVA', 'ONA', 'SPECIAL'] }
];

function sortCards(cards: SeasonCard[], sort: ChartSort): SeasonCard[] {
	const sorted = [...cards];
	if (sort === 'score') sorted.sort((a, b) => (b.score ?? -1) - (a.score ?? -1));
	if (sort === 'airing') sorted.sort((a, b) => (a.nextAt ?? Infinity) - (b.nextAt ?? Infinity));
	if (sort === 'title') sorted.sort((a, b) => a.title.title.localeCompare(b.title.title));
	// 'popularity' is AniList's own order
	return sorted;
}

function matches(card: SeasonCard, query: string): boolean {
	const q = query.trim().toLowerCase();
	if (!q) return true;
	return [card.title.title, card.title.en ?? '', card.studio, ...card.title.genres].some((s) =>
		s.toLowerCase().includes(q)
	);
}

/** The chart's sections, in AniChart's order; empty sections are left out. */
export function buildSeasonChart(
	media: SeasonMedia[],
	leftovers: SeasonMedia[],
	options: ChartOptions
): ChartSection[] {
	const { sort = 'popularity', filter = '' } = options;
	return SECTIONS.map(({ key, label, formats }) => {
		const source =
			key === 'leftovers' ? leftovers : media.filter((m) => formats.includes(m.format ?? ''));
		const cards = source
			.map((m) => buildCard(m, options, { leftover: key === 'leftovers' }))
			.filter((c) => matches(c, filter));
		return { key, label, cards: sortCards(cards, sort) };
	}).filter((s) => s.cards.length);
}
