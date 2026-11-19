import { adaptMedia, type TitlePreference } from '#lib/anilist/adapt.ts';
import { formatTimeUntil } from '#lib/anilist/humanize.ts';
import { formatScore } from '#lib/anilist/score.ts';
import type {
	AniListMedia,
	CollectionEntry,
	MediaListStatus,
	ScoreFormat
} from '#lib/anilist/types.ts';
import { LIST_STATUSES, statusLabel } from '#lib/catalog/status.ts';
import { newEpisodesFor } from '#lib/catalog/progress.ts';
import type { Title } from '#lib/catalog/types.ts';

export type ListSort = 'toWatch' | 'updated' | 'title' | 'score' | 'progress' | 'airing';

export const LIST_SORTS: {
	key: ListSort;
	label: string;
	animeOnly?: boolean;
	/** Only on Watching and Rewatching. */
	inProgressOnly?: boolean;
}[] = [
	{ key: 'toWatch', label: 'Most to watch', inProgressOnly: true },
	{ key: 'updated', label: 'Last updated' },
	{ key: 'title', label: 'Title' },
	{ key: 'score', label: 'Score' },
	{ key: 'progress', label: 'Progress' },
	{ key: 'airing', label: 'Next episode', animeOnly: true }
];

const inProgressTab = (tab: MediaListStatus) => tab === 'CURRENT' || tab === 'REPEATING';

/** The sorts offered on a tab. */
export function sortsFor(tab: MediaListStatus, isAnime: boolean) {
	return LIST_SORTS.filter(
		(s) => (isAnime || !s.animeOnly) && (inProgressTab(tab) || !s.inProgressOnly)
	);
}

/** Watching and Rewatching open on Most to watch (Home's order); the rest on Last updated. */
export function defaultSortFor(tab: MediaListStatus): ListSort {
	return inProgressTab(tab) ? 'toWatch' : 'updated';
}

/** The viewer's current values for a title — local edits over what AniList sent. */
export interface LiveEntry {
	status: MediaListStatus;
	progress: number;
	score?: number;
}

export interface ListRow {
	title: Title;
	entry: CollectionEntry;
	status: MediaListStatus;
	progress: number;
	score: number;
	/** "2 new · EP 9 in 2d 4h", "16 left", or format · season. */
	note: string;
	noteColor: string;
	updated: string;
}

export interface ListView {
	tabs: { status: MediaListStatus; label: string; count: number }[];
	rows: ListRow[];
	/** Formats on this tab, for the Format filter. */
	formats: string[];
	/** The genres, countries and years on the tab, for its filters (newest year first). */
	genres: string[];
	countries: string[];
	years: number[];
	summary: string;
}

export interface ListOptions {
	tab: MediaListStatus;
	/**
	 * A custom list's titles: the rows are these, whatever their status (the
	 * tab is ignored), and each says its status.
	 */
	only?: ReadonlySet<number>;
	/** Titles set to "hide from status lists" on AniList: on their custom lists only. */
	hidden?: ReadonlySet<number>;
	filter?: string;
	sort?: ListSort;
	/** A humanized format ("TV", "Movie"), or '' for all. */
	format?: string;
	/** A genre ("Action"), or '' for all. */
	genre?: string;
	/** A country of origin ("KR"), or '' for all. */
	country?: string;
	/** A year (listYear), or null for all. */
	year?: number | null;
	isAnime: boolean;
	titles?: TitlePreference;
	scoreFormat?: ScoreFormat;
	/** Local edits made this visit (the shared list store). */
	live?: (mediaId: number) => LiveEntry | undefined;
	/** Titles taken off the list this visit. */
	removed?: (mediaId: number) => boolean;
	/** Unix seconds; for relative times and countdowns. */
	now: number;
	/** For "Aug 30" vs "2025". */
	timeZone?: string;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** "Just now", "12m ago", "2h ago", "Yesterday", "3d ago", "Aug 30", "2025". */
export function relativeTime(unixSeconds: number, now: number, timeZone?: string): string {
	const diff = Math.max(0, now - unixSeconds);
	if (diff < 60) return 'Just now';
	if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
	if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
	if (diff < 2 * 86400) return 'Yesterday';
	if (diff < 7 * 86400) return `${Math.floor(diff / 86400)}d ago`;
	const parts = (seconds: number) =>
		Object.fromEntries(
			new Intl.DateTimeFormat('en-US', {
				year: 'numeric',
				month: 'numeric',
				day: 'numeric',
				timeZone
			})
				.formatToParts(new Date(seconds * 1000))
				.map((p) => [p.type, Number(p.value)])
		) as { year: number; month: number; day: number };
	const then = parts(unixSeconds);
	return then.year === parts(now).year
		? `${MONTHS[then.month - 1]} ${then.day}`
		: String(then.year);
}

/** "just now", "yesterday"; dates keep their capital ("Aug 30"). */
const lowerFirst = (s: string) => (s === 'Just now' || s === 'Yesterday' ? s.toLowerCase() : s);

/**
 * The row's second line: airing context while watching (for manga, when you
 * last read it, or a hiatus), else format and season/status.
 */
function rowNote(
	title: Title,
	status: MediaListStatus,
	progress: number,
	isAnime: boolean,
	now: number,
	updated: string
): { note: string; noteColor: string } {
	const next = title.next;
	if (status === 'CURRENT' && isAnime && next?.at) {
		const fresh = next.ep - 1 - progress;
		const when = formatTimeUntil(next.at - now);
		// the same words as Home: "new", "Caught up"
		return fresh > 0
			? { note: `${fresh} new · EP ${next.ep} in ${when}`, noteColor: '#4ED98A' }
			: { note: `Caught up · EP ${next.ep} in ${when}`, noteColor: 'var(--color-muted)' };
	}
	// finished airing, still watching: what's left to watch
	const left = newEpisodesFor(title, progress);
	if (status === 'CURRENT' && isAnime && left) {
		return { note: `${left} left`, noteColor: '#4ED98A' };
	}
	if (status === 'CURRENT' && !isAnime) {
		// every ongoing series says "Releasing"; when you last read it tells rows apart
		return title.status === 'Hiatus'
			? { note: 'On hiatus', noteColor: '#F5B83D' }
			: { note: `Updated ${lowerFirst(updated)}`, noteColor: 'var(--color-muted)' };
	}
	return {
		note: [title.format, isAnime ? title.season : title.status].filter(Boolean).join(' · '),
		noteColor: 'var(--color-dim)'
	};
}

/** The year a title came out, as AniList's list filter reads it: its season's, or its start date's. */
export function listYear(media: Pick<AniListMedia, 'seasonYear' | 'startDate'>): number | null {
	return media.seasonYear ?? media.startDate?.year ?? null;
}

/** "Japan", "South Korea"…, for a country of origin code; unknown ones stay a code. */
export function countryName(code: string): string {
	return COUNTRY_NAMES[code] ?? code;
}

const COUNTRY_NAMES: Record<string, string> = {
	JP: 'Japan',
	KR: 'South Korea',
	CN: 'China',
	TW: 'Taiwan'
};

/** Most new episodes first, then whatever airs soonest, then the most recently updated. */
function byToWatch(a: ListRow, b: ListRow): number {
	const na = newEpisodesFor(a.title, a.progress) ?? 0;
	const nb = newEpisodesFor(b.title, b.progress) ?? 0;
	if (na !== nb) return nb - na;
	const aa = a.title.next?.at ?? Infinity;
	const ab = b.title.next?.at ?? Infinity;
	if (aa !== ab) return aa - ab;
	return b.entry.updatedAt - a.entry.updatedAt;
}

const BY: Record<ListSort, (a: ListRow, b: ListRow) => number> = {
	toWatch: byToWatch,
	updated: (a, b) => b.entry.updatedAt - a.entry.updatedAt,
	title: (a, b) => a.title.title.localeCompare(b.title.title),
	score: (a, b) => b.score - a.score || a.title.title.localeCompare(b.title.title),
	progress: (a, b) => b.progress - a.progress,
	// soonest next episode first; nothing scheduled goes last
	airing: (a, b) => (a.title.next?.at ?? Infinity) - (b.title.next?.at ?? Infinity)
};

/** Builds My List for one tab: counts for every tab, the filtered and sorted rows, a summary. */
export function buildListView(entries: CollectionEntry[], options: ListOptions): ListView {
	const { tab, isAnime, now } = options;
	const filter = options.filter?.trim().toLowerCase() ?? '';

	const all: ListRow[] = [];
	for (const entry of entries) {
		if (options.removed?.(entry.mediaId)) continue;
		const live = options.live?.(entry.mediaId);
		const status = live?.status ?? entry.status;
		const progress = live?.progress ?? entry.progress;
		const title = adaptMedia(entry.media, { status, progress }, { titles: options.titles });
		const updated = relativeTime(entry.updatedAt, now, options.timeZone);
		all.push({
			title,
			entry,
			status,
			progress,
			score: live?.score ?? entry.score,
			...rowNote(title, status, progress, isAnime, now, updated),
			updated
		});
	}

	const counts = new Map<MediaListStatus, number>();
	const onStatusLists = all.filter((r) => !options.hidden?.has(r.title.id));
	for (const row of onStatusLists) counts.set(row.status, (counts.get(row.status) ?? 0) + 1);

	const onTab = options.only
		? all
				.filter((r) => options.only!.has(r.title.id))
				.map((r) => ({ ...r, note: `${statusLabel(r.status, isAnime)} · ${r.note}` }))
		: onStatusLists.filter((r) => r.status === tab);
	const rows = onTab
		.filter((r) => !options.format || r.title.format === options.format)
		.filter((r) => !options.genre || r.entry.media.genres.includes(options.genre))
		.filter((r) => !options.country || r.entry.media.countryOfOrigin === options.country)
		.filter((r) => options.year == null || listYear(r.entry.media) === options.year)
		.filter(
			(r) =>
				!filter ||
				r.title.title.toLowerCase().includes(filter) ||
				(r.title.en ?? '').toLowerCase().includes(filter)
		)
		.sort(BY[options.sort ?? defaultSortFor(tab)]);

	const titles = all.length;
	const units = all.reduce((sum, r) => sum + r.progress, 0);
	let summary: string;
	if (isAnime) {
		const minutes = all.reduce((sum, r) => sum + r.progress * (r.entry.media.duration ?? 24), 0);
		summary = `${titles.toLocaleString('en-US')} titles · ${units.toLocaleString('en-US')} episodes · ${(minutes / 1440).toFixed(1)} days watched`;
	} else {
		const scored = all.filter((r) => r.score > 0);
		const mean = scored.length ? scored.reduce((s, r) => s + r.score, 0) / scored.length : 0;
		summary = `${titles.toLocaleString('en-US')} titles · ${units.toLocaleString('en-US')} chapters${mean ? ` · mean score ${formatScore(Math.round(mean * 10) / 10, options.scoreFormat)}` : ''}`;
	}

	return {
		tabs: LIST_STATUSES.map((status) => ({
			status,
			label: statusLabel(status, isAnime),
			count: counts.get(status) ?? 0
		})),
		rows,
		formats: [...new Set(onTab.map((r) => r.title.format))].sort(),
		genres: [...new Set(onTab.flatMap((r) => r.entry.media.genres))].sort(),
		countries: [...new Set(onTab.flatMap((r) => r.entry.media.countryOfOrigin ?? []))].sort(),
		years: [...new Set(onTab.flatMap((r) => listYear(r.entry.media) ?? []))].sort((a, b) => b - a),
		summary
	};
}
