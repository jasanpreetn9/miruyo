import { humanizeFormat } from '#lib/anilist/humanize.ts';
import { scoreScale } from '#lib/anilist/score.ts';
import type {
	ActivityDay,
	AniListDate,
	CollectionEntry,
	MediaListStatus,
	ScoreFormat
} from '#lib/anilist/types.ts';
import { statusLabel } from '#lib/catalog/status.ts';
import { seasonOf } from './seasonal.ts';

// Stats (design 07). Computed from the viewer's list collection rather than
// AniList's User.statistics, whose breakdowns (formats, statuses, genres,
// scores) are often stale or empty — and a list can be filtered by time.

export type StatsRange = 'all' | 'year' | '12m';

export const STATS_RANGES: StatsRange[] = ['all', 'year', '12m'];

export function rangeLabel(range: StatsRange, now: Date): string {
	if (range === 'year') return String(now.getFullYear());
	if (range === '12m') return 'Last 12 months';
	return 'All time';
}

export function parseRange(value: string | null): StatsRange {
	return STATS_RANGES.find((r) => r === value) ?? 'all';
}

/**
 * Which colour a mark takes: the mode accent, a softer accent, or one of the
 * neutrals. The page maps these to the anime or manga palette.
 */
export type Tone = 'accent' | 'accent-soft' | 'ink' | 'dim' | 'mute';

export interface StatCard {
	icon: string;
	label: string;
	value: string;
	detail: string;
	/** Good news (green) vs. plain context (dim). */
	positive: boolean;
}

export interface ScoreBucket {
	/** 1–10. */
	score: number;
	count: number;
	/** Bars of 7 and up take the accent. */
	tone: Tone;
}

export interface Slice {
	label: string;
	count: number;
	/** 0–1 of the total. */
	share: number;
	tone: Tone;
}

export interface StatusSlice {
	status: MediaListStatus;
	label: string;
	count: number;
}

export interface GenreRow {
	genre: string;
	count: number;
	/** Mean of your scores in this genre, 10-point; null when none are scored. */
	mean: number | null;
	/** 0–1, relative to the top genre. */
	width: number;
	tone: Tone;
}

export interface MonthBar {
	/** Single-letter month, as on the design's axis. */
	label: string;
	/** "October 2026", for the tooltip. */
	name: string;
	count: number;
	tone: Tone;
}

export interface Stats {
	/** Titles in the range. */
	total: number;
	cards: StatCard[];
	/** 10-point; null when nothing in range is scored. */
	mean: number | null;
	deviation: number | null;
	scored: number;
	scores: ScoreBucket[];
	formats: Slice[];
	statuses: StatusSlice[];
	genres: GenreRow[];
	/** Titles finished per month, oldest first, ending with the current month. */
	months: MonthBar[];
}

interface Options {
	isAnime: boolean;
	range: StatsRange;
	scoreFormat?: ScoreFormat;
	now: Date;
}

const DAY_MS = 86_400_000;
const WEEK_MS = 7 * DAY_MS;

function toDate(d: AniListDate | null | undefined): Date | null {
	if (!d?.year) return null;
	return new Date(d.year, (d.month ?? 1) - 1, d.day ?? 1);
}

/** Start of the range, or null for all time. */
export function rangeStart(range: StatsRange, now: Date): Date | null {
	if (range === 'year') return new Date(now.getFullYear(), 0, 1);
	if (range === '12m') return new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());
	return null;
}

/**
 * Whether an entry belongs to a time range: you started or finished it in
 * the range. Entries with neither date fall back to when they were last
 * updated.
 */
function inRange(entry: CollectionEntry, start: Date | null): boolean {
	if (!start) return true;
	const dates = [toDate(entry.startedAt), toDate(entry.completedAt)].filter((d) => d !== null);
	if (!dates.length) return entry.updatedAt * 1000 >= start.getTime();
	return dates.some((d) => d >= start);
}

/** A score on AniList's 10-point axis (0 = unscored). */
export function toTenPoint(score: number, format?: ScoreFormat): number {
	if (!score) return 0;
	return (score / scoreScale(format).max) * 10;
}

/** Episodes (or chapters) consumed, counting each rewatch as a full run. */
function unitsOf(entry: CollectionEntry, isAnime: boolean): number {
	const total = (isAnime ? entry.media.episodes : entry.media.chapters) ?? entry.progress;
	return entry.progress + (entry.repeat ?? 0) * total;
}

function volumesOf(entry: CollectionEntry): number {
	const read = entry.progressVolumes ?? 0;
	return read + (entry.repeat ?? 0) * (entry.media.volumes ?? read);
}

const FORMAT_TONES: Tone[] = ['accent', 'ink', 'dim', 'mute'];
/** The donut shows the top few formats; the rest are grouped. */
const MAX_FORMATS = 4;
const MAX_GENRES = 7;

/** Status bar order, as in the design: finished first, then what's moving. */
const STATUS_ORDER: MediaListStatus[] = [
	'COMPLETED',
	'CURRENT',
	'REPEATING',
	'PLANNING',
	'PAUSED',
	'DROPPED'
];

const MONTH_LETTERS = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

const number = new Intl.NumberFormat('en-US');

function fixed1(value: number): string {
	return value.toFixed(1);
}

export function buildStats(entries: CollectionEntry[], opts: Options): Stats {
	const { isAnime, range, scoreFormat, now } = opts;
	const start = rangeStart(range, now);
	const shown = entries.filter((e) => inRange(e, start));

	// ── Scores ──
	const scored = shown.map((e) => toTenPoint(e.score, scoreFormat)).filter((s) => s > 0);
	const mean = scored.length ? scored.reduce((a, s) => a + s, 0) / scored.length : null;
	const deviation =
		mean === null
			? null
			: Math.sqrt(scored.reduce((a, s) => a + (s - mean) ** 2, 0) / scored.length);
	const buckets = Array.from({ length: 10 }, () => 0);
	for (const s of scored) buckets[Math.min(10, Math.max(1, Math.round(s))) - 1]++;
	const scores: ScoreBucket[] = buckets.map((count, i) => ({
		score: i + 1,
		count,
		tone: i + 1 >= 7 ? 'accent' : 'mute'
	}));

	// ── Formats ──
	const formatCounts = new Map<string, number>();
	for (const e of shown) {
		const label = humanizeFormat(e.media.format);
		formatCounts.set(label, (formatCounts.get(label) ?? 0) + 1);
	}
	let formatList = [...formatCounts].sort((a, b) => b[1] - a[1]);
	if (formatList.length > MAX_FORMATS) {
		const rest = formatList.slice(MAX_FORMATS - 1).reduce((a, [, c]) => a + c, 0);
		formatList = [...formatList.slice(0, MAX_FORMATS - 1), ['Other', rest]];
	}
	const formats: Slice[] = formatList.map(([label, count], i) => ({
		label,
		count,
		share: shown.length ? count / shown.length : 0,
		tone: FORMAT_TONES[i]
	}));

	// ── Statuses ──
	const statusCounts = new Map<MediaListStatus, number>();
	for (const e of shown) statusCounts.set(e.status, (statusCounts.get(e.status) ?? 0) + 1);
	const statuses: StatusSlice[] = STATUS_ORDER.filter((s) => statusCounts.get(s)).map((status) => ({
		status,
		label: statusLabel(status, isAnime),
		count: statusCounts.get(status) ?? 0
	}));

	// ── Genres ──
	const genreStats = new Map<string, { count: number; sum: number; scored: number }>();
	for (const e of shown) {
		const s = toTenPoint(e.score, scoreFormat);
		for (const genre of e.media.genres ?? []) {
			const g = genreStats.get(genre) ?? { count: 0, sum: 0, scored: 0 };
			g.count++;
			if (s) {
				g.sum += s;
				g.scored++;
			}
			genreStats.set(genre, g);
		}
	}
	const topGenres = [...genreStats]
		.sort((a, b) => b[1].count - a[1].count || a[0].localeCompare(b[0]))
		.slice(0, MAX_GENRES);
	const topCount = topGenres[0]?.[1].count ?? 1;
	const genres: GenreRow[] = topGenres.map(([genre, g], i) => ({
		genre,
		count: g.count,
		mean: g.scored ? g.sum / g.scored : null,
		width: g.count / topCount,
		tone: i === 0 ? 'accent' : 'accent-soft'
	}));

	// ── Finished per month (last 12, whatever the range) ──
	const months: MonthBar[] = Array.from({ length: 12 }, (_, i) => {
		const d = new Date(now.getFullYear(), now.getMonth() - 11 + i, 1);
		return {
			label: MONTH_LETTERS[d.getMonth()],
			name: d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }),
			count: 0,
			tone: 'mute'
		};
	});
	const firstMonth = new Date(now.getFullYear(), now.getMonth() - 11, 1);
	for (const e of entries) {
		const done = toDate(e.completedAt);
		if (!done || done < firstMonth || done > now) continue;
		const i =
			(done.getFullYear() - firstMonth.getFullYear()) * 12 +
			done.getMonth() -
			firstMonth.getMonth();
		if (i >= 0 && i < 12) months[i].count++;
	}
	// every month with something finished in the accent; empty ones stay quiet
	for (const m of months) if (m.count > 0) m.tone = 'accent';

	// ── Cards ──
	const season = seasonOf(now);
	const finishedThisSeason = entries.filter((e) => {
		const done = toDate(e.completedAt);
		if (!done || done > now) return false;
		const s = seasonOf(done);
		return s.season === season.season && s.year === season.year;
	}).length;

	const units = shown.reduce((a, e) => a + unitsOf(e, isAnime), 0);
	const perWeek = unitsPerWeek(shown, units, start, now);
	const siteScores = shown
		.filter((e) => e.score > 0 && e.media.averageScore)
		.map((e) => (e.media.averageScore ?? 0) / 10);
	const siteMean = siteScores.length
		? siteScores.reduce((a, s) => a + s, 0) / siteScores.length
		: null;

	const totalCard: StatCard = {
		icon: isAnime ? 'movie' : 'menu_book',
		label: isAnime ? 'Total anime' : 'Total manga',
		value: number.format(shown.length),
		detail: finishedThisSeason
			? `+${finishedThisSeason} finished this season`
			: 'None finished this season',
		positive: finishedThisSeason > 0
	};
	const unitsCard: StatCard = {
		icon: isAnime ? 'play_circle' : 'auto_stories',
		label: isAnime ? 'Episodes watched' : 'Chapters read',
		value: number.format(units),
		detail: perWeek === null ? '' : `≈ ${number.format(perWeek)} per week`,
		positive: false
	};
	const meanCard: StatCard = {
		icon: 'star',
		label: 'Mean score',
		value: mean === null ? '—' : fixed1(mean),
		detail: siteMean === null ? 'Nothing scored yet' : `AniList mean ${fixed1(siteMean)}`,
		positive: false
	};

	let thirdCard: StatCard;
	if (isAnime) {
		const minutes = shown.reduce((a, e) => a + unitsOf(e, true) * (e.media.duration ?? 0), 0);
		thirdCard = {
			icon: 'schedule',
			label: 'Days watched',
			value: fixed1(minutes / 1440),
			detail: `${number.format(Math.round(minutes / 60))} hours`,
			positive: false
		};
	} else {
		const volumes = shown.reduce((a, e) => a + volumesOf(e), 0);
		const series = shown.filter((e) => (e.progressVolumes ?? 0) > 0).length;
		thirdCard = {
			icon: 'library_books',
			label: 'Volumes read',
			value: number.format(volumes),
			detail: series ? `Across ${number.format(series)} series` : 'No volumes tracked',
			positive: false
		};
	}

	return {
		total: shown.length,
		cards: [totalCard, unitsCard, thirdCard, meanCard],
		mean,
		deviation,
		scored: scored.length,
		scores,
		formats,
		statuses,
		genres,
		months
	};
}

/**
 * Average per week across the range — for all time, since the earliest date
 * on the list. Null when there's no span to average over.
 */
function unitsPerWeek(
	entries: CollectionEntry[],
	units: number,
	start: Date | null,
	now: Date
): number | null {
	let from = start;
	if (!from) {
		const times = entries
			.flatMap((e) => [toDate(e.startedAt), toDate(e.completedAt)])
			.filter((d) => d !== null)
			.map((d) => d.getTime());
		if (!times.length) return null;
		from = new Date(Math.min(...times));
	}
	const weeks = (now.getTime() - from.getTime()) / WEEK_MS;
	if (weeks < 1) return null;
	return Math.round(units / weeks);
}

// ── Daily activity heatmap ──

export const HEATMAP_WEEKS = 26;

export interface HeatCell {
	/** "Oct 3", for the tooltip. */
	date: string;
	amount: number;
	/** 0 = nothing, 1–4 = quartiles of active days. */
	level: number;
}

/**
 * The last 26 weeks as columns of Monday → Sunday, ending this week. Days
 * after today are null. `history` is AniList's activityHistory: one entry
 * per active day, dated at the start of that day.
 */
export function buildHeatmap(history: ActivityDay[], now: Date): (HeatCell | null)[][] {
	// AniList dates days at midnight in the account's timezone; reading them
	// at noon keeps them on the right calendar day here.
	const byDay = new Map<string, number>();
	for (const { date, amount } of history) {
		const key = dayKey(new Date(date * 1000 + DAY_MS / 2));
		byDay.set(key, (byDay.get(key) ?? 0) + amount);
	}

	const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
	const weekday = (today.getDay() + 6) % 7; // Monday = 0
	const first = new Date(
		today.getFullYear(),
		today.getMonth(),
		today.getDate() - weekday - (HEATMAP_WEEKS - 1) * 7
	);

	const amounts: number[] = [];
	const grid: (HeatCell | null)[][] = [];
	for (let w = 0; w < HEATMAP_WEEKS; w++) {
		const column: (HeatCell | null)[] = [];
		for (let d = 0; d < 7; d++) {
			const day = new Date(first.getFullYear(), first.getMonth(), first.getDate() + w * 7 + d);
			if (day > today) {
				column.push(null);
				continue;
			}
			const amount = byDay.get(dayKey(day)) ?? 0;
			if (amount) amounts.push(amount);
			column.push({
				date: day.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
				amount,
				level: 0
			});
		}
		grid.push(column);
	}

	// levels by quartile of the active days, so one huge import day doesn't
	// flatten the rest
	const sorted = amounts.sort((a, b) => a - b);
	const cut = (q: number) => sorted[Math.floor((sorted.length - 1) * q)];
	const thresholds = sorted.length ? [cut(0.25), cut(0.5), cut(0.75)] : [];
	for (const column of grid) {
		for (const cell of column) {
			if (!cell?.amount) continue;
			cell.level = 1 + thresholds.filter((t) => cell.amount > t).length;
		}
	}
	return grid;
}

function dayKey(d: Date): string {
	return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}
