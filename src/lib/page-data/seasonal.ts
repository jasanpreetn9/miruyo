import { adaptMedia, type TitlePreference } from '#lib/anilist/adapt.ts';
import { formatTimeUntil, humanizeSeason } from '#lib/anilist/humanize.ts';
import type { AiringSlot, MediaListStatus, MediaSeason } from '#lib/anilist/types.ts';
import type { Title } from '#lib/catalog/types.ts';

// The weekly airing calendar, in the viewer's own timezone (the runtime's
// local time): Monday to Sunday, slots stacked by air time.

const DAY_NAMES = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const WEEKDAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const pad = (n: number) => String(n).padStart(2, '0');

/** Local midnight of the Monday of `date`'s week. */
export function mondayOf(date: Date): Date {
	const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
	const back = (d.getDay() + 6) % 7; // Mon = 0 … Sun = 6
	d.setDate(d.getDate() - back);
	return d;
}

export function addDays(date: Date, days: number): Date {
	const d = new Date(date);
	d.setDate(d.getDate() + days);
	return d;
}

/** YYYY-MM-DD for the week param. */
export function toWeekParam(monday: Date): string {
	return `${monday.getFullYear()}-${pad(monday.getMonth() + 1)}-${pad(monday.getDate())}`;
}

/** The Monday of the week in `?week=YYYY-MM-DD`, or of `now`'s week. */
export function parseWeekParam(value: string | null, now: Date): Date {
	const m = value && /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
	if (!m) return mondayOf(now);
	const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
	return Number.isNaN(d.getTime()) ? mondayOf(now) : mondayOf(d);
}

export interface SeasonRef {
	season: MediaSeason;
	year: number;
}

/** AniList's season for a date: Dec–Feb is Winter (of the new year), Mar–May Spring, … */
export function seasonOf(date: Date): SeasonRef {
	const month = date.getMonth();
	const year = date.getFullYear();
	if (month === 11) return { season: 'WINTER', year: year + 1 };
	if (month <= 1) return { season: 'WINTER', year };
	if (month <= 4) return { season: 'SPRING', year };
	if (month <= 7) return { season: 'SUMMER', year };
	return { season: 'FALL', year };
}

const SEASON_START_MONTH: Record<MediaSeason, number> = {
	WINTER: 0,
	SPRING: 3,
	SUMMER: 6,
	FALL: 9
};

/** The Monday of the week a season starts (Jan / Apr / Jul / Oct 1st). */
export function seasonStart({ season, year }: SeasonRef): Date {
	return mondayOf(new Date(year, SEASON_START_MONTH[season], 1));
}

/** "Fall 2026 · week of Oct 5". */
export function weekLabel(monday: Date): string {
	// the week's season is the one most of its days are in
	const { season, year } = seasonOf(addDays(monday, 3));
	return `${humanizeSeason(season)} ${year} · week of ${MONTHS[monday.getMonth()]} ${monday.getDate()}`;
}

/** "Times in CEST (UTC+2)" — the runtime's own timezone. */
export function timezoneLabel(date: Date): string {
	const name =
		new Intl.DateTimeFormat('en-US', { timeZoneName: 'short' })
			.formatToParts(date)
			.find((p) => p.type === 'timeZoneName')?.value ?? '';
	const offset = -date.getTimezoneOffset();
	const hours = Math.trunc(Math.abs(offset) / 60);
	const minutes = Math.abs(offset) % 60;
	const utc = `UTC${offset >= 0 ? '+' : '−'}${hours}${minutes ? `:${pad(minutes)}` : ''}`;
	return name && !name.startsWith('GMT') ? `Times in ${name} (${utc})` : `Times in ${utc}`;
}

export interface CalendarSlot {
	key: number;
	title: Title;
	episode: number;
	airingAt: number;
	/** Local "HH:MM". */
	time: string;
	aired: boolean;
	/** On the viewer's list as Watching/Rewatching. */
	mine: boolean;
	/** "EP 9 · 2d 4h" or "EP 9 · aired". */
	countdown: string;
	/** "Ep 4 aired at 12:00" / "Ep 9 airing at 23:00" (AniChart's wording). */
	status: string;
	/** Time left, e.g. "4h 40m"; '' once aired. */
	until: string;
	/** The week's next episode to air (only in the week that contains now). */
	next: boolean;
	/** Airs within a day — the countdown turns the accent colour. */
	soon: boolean;
	/** Mine, out, and not yet watched: offer +1. */
	canAddOne: boolean;
}

export interface CalendarDay {
	date: Date;
	/** "Today", or "Mon"… */
	name: string;
	/** "Wednesday". */
	weekday: string;
	/** Before today, in the week that contains now. */
	past: boolean;
	/** "Oct 5". */
	label: string;
	isToday: boolean;
	slots: CalendarSlot[];
	/** Today only: where the NOW line goes (before this slot); slots.length = after all. */
	nowIndex: number | null;
	hasMine: boolean;
}

export interface CalendarOptions {
	now: Date;
	titles?: TitlePreference;
	/** The viewer's live entry for a title (status and progress), if on the list. */
	entry?: (mediaId: number) => { status: MediaListStatus; progress: number } | null | undefined;
	/** "My list only". */
	mineOnly?: boolean;
}

const WATCHING: MediaListStatus[] = ['CURRENT', 'REPEATING'];

/**
 * A week's airings as the server sends them. An airing card shows the title,
 * its cover and its episode count, so the rest of each title (genres,
 * studios, scores, dates, the next episode) is left out. The page carries
 * this data twice (as HTML and for the browser to take over), so every field
 * left out counts twice; the browser's own copy has them all.
 */
export function slimForSchedule(slots: AiringSlot[]): AiringSlot[] {
	return slots.map((slot) => ({
		...slot,
		media: {
			...slot.media,
			season: null,
			seasonYear: null,
			duration: null,
			chapters: null,
			volumes: null,
			averageScore: null,
			popularity: null,
			genres: [],
			countryOfOrigin: null,
			startDate: null,
			studios: { nodes: [] },
			nextAiringEpisode: null
		}
	}));
}

/** How many airings the server renders; the browser loads the rest of the week. */
export const SERVER_AIRINGS = 40;

/**
 * The airings the server renders: the next 40 from a day ago (the server
 * doesn't know the viewer's timezone, so "today" could have started up to a
 * day earlier), or a past week's first 40, slimmed to what a card shows. A
 * whole week (well over 100 cards, sent twice over) was about 290 KB a
 * visit; the browser's own copy fills in the rest.
 */
export function serverWeek(slots: AiringSlot[], now: Date): AiringSlot[] {
	const from = Math.floor(now.getTime() / 1000) - 86400;
	const upcoming = slots.filter((s) => s.airingAt >= from);
	return slimForSchedule((upcoming.length ? upcoming : slots).slice(0, SERVER_AIRINGS));
}

/** Seven days from `monday`, each with its airings in local time. */
export function buildCalendar(
	slots: AiringSlot[],
	monday: Date,
	options: CalendarOptions
): CalendarDay[] {
	const nowSeconds = Math.floor(options.now.getTime() / 1000);
	const today =
		mondayOf(options.now).getTime() === monday.getTime() ? (options.now.getDay() + 6) % 7 : -1;

	const days: CalendarDay[] = DAY_NAMES.map((name, i) => {
		const date = addDays(monday, i);
		return {
			date,
			name: i === today ? 'Today' : name,
			weekday: WEEKDAYS[i],
			past: today >= 0 && i < today,
			label: `${MONTHS[date.getMonth()]} ${date.getDate()}`,
			isToday: i === today,
			slots: [],
			nowIndex: null,
			hasMine: false
		};
	});

	for (const slot of slots) {
		const at = new Date(slot.airingAt * 1000);
		const index = Math.floor(
			mondayOf(at).getTime() === monday.getTime() ? (at.getDay() + 6) % 7 : -1
		);
		if (index < 0) continue;
		const entry = options.entry?.(slot.media.id) ?? null;
		const mine = !!entry && WATCHING.includes(entry.status);
		if (options.mineOnly && !mine) continue;
		const aired = slot.airingAt <= nowSeconds;
		const until = slot.airingAt - nowSeconds;
		const title = adaptMedia(slot.media, entry ?? undefined, { titles: options.titles });
		days[index].slots.push({
			key: slot.id,
			title,
			episode: slot.episode,
			airingAt: slot.airingAt,
			time: `${pad(at.getHours())}:${pad(at.getMinutes())}`,
			aired,
			mine,
			countdown: aired
				? `EP ${slot.episode} · aired`
				: `EP ${slot.episode} · ${formatTimeUntil(until)}`,
			status: `Ep ${slot.episode} ${aired ? 'aired' : 'airing'} at ${pad(at.getHours())}:${pad(at.getMinutes())}`,
			until: aired ? '' : formatTimeUntil(until),
			next: false,
			soon: !aired && until < 86400,
			canAddOne: mine && aired && (entry?.progress ?? 0) < slot.episode
		});
		if (mine) days[index].hasMine = true;
	}

	for (const day of days) {
		day.slots.sort((a, b) => a.airingAt - b.airingAt);
		if (day.isToday) {
			const next = day.slots.findIndex((s) => !s.aired);
			day.nowIndex = next < 0 ? day.slots.length : next;
		}
	}
	if (today >= 0) {
		const next = days.flatMap((d) => d.slots).find((s) => !s.aired);
		if (next) next.next = true;
	}
	return days;
}

/**
 * The order to show days in, AniChart-style: in the week that contains now,
 * today first, the rest of the week, then the days already past; other
 * weeks run Monday to Sunday.
 */
export function upcomingFirst(days: CalendarDay[]): CalendarDay[] {
	return [...days.filter((d) => !d.past), ...days.filter((d) => d.past)];
}
