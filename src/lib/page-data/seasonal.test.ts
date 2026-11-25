import { describe, expect, it, vi } from 'vitest';
import { makeMedia } from '#lib/anilist/fixtures.ts';
import type { AiringSlot } from '#lib/anilist/types.ts';
import {
	buildCalendar,
	upcomingFirst,
	mondayOf,
	parseWeekParam,
	seasonOf,
	seasonStart,
	SERVER_AIRINGS,
	serverWeek,
	slimForSchedule,
	timezoneLabel,
	toWeekParam,
	weekLabel
} from './seasonal.ts';

// The calendar works in local time; pin it so the tests mean the same
// everywhere. Top level, before any Date below is made.
vi.stubEnv('TZ', 'Asia/Tokyo');

const at = (y: number, m: number, d: number, h = 0, min = 0) => new Date(y, m - 1, d, h, min);
const unix = (date: Date) => Math.floor(date.getTime() / 1000);

describe('weeks and seasons', () => {
	it('finds the local Monday of a week', () => {
		expect(toWeekParam(mondayOf(at(2026, 10, 7, 18)))).toBe('2026-10-05'); // Wed
		expect(toWeekParam(mondayOf(at(2026, 10, 11, 23)))).toBe('2026-10-05'); // Sun
		expect(toWeekParam(mondayOf(at(2026, 10, 12)))).toBe('2026-10-12'); // Mon
	});

	it('reads the week param, falling back to this week', () => {
		const now = at(2026, 10, 7);
		expect(toWeekParam(parseWeekParam('2026-10-14', now))).toBe('2026-10-12');
		expect(toWeekParam(parseWeekParam('nope', now))).toBe('2026-10-05');
		expect(toWeekParam(parseWeekParam(null, now))).toBe('2026-10-05');
	});

	it('uses AniList seasons (December is next year’s Winter)', () => {
		expect(seasonOf(at(2026, 12, 20))).toEqual({ season: 'WINTER', year: 2027 });
		expect(seasonOf(at(2026, 2, 1))).toEqual({ season: 'WINTER', year: 2026 });
		expect(seasonOf(at(2026, 10, 7))).toEqual({ season: 'FALL', year: 2026 });
		expect(toWeekParam(seasonStart({ season: 'FALL', year: 2026 }))).toBe('2026-09-28');
	});

	it('labels the week and the timezone', () => {
		expect(weekLabel(mondayOf(at(2026, 10, 7)))).toBe('Fall 2026 · week of Oct 5');
		expect(timezoneLabel(at(2026, 10, 7))).toBe('Times in GMT+9'.replace('GMT', 'UTC'));
	});
});

describe('buildCalendar', () => {
	const monday = mondayOf(at(2026, 10, 7));
	const now = at(2026, 10, 7, 18, 20); // Wed 18:20
	const slot = (id: number, date: Date, episode = 9, mediaId = id): AiringSlot => ({
		id,
		episode,
		airingAt: unix(date),
		media: makeMedia({ id: mediaId })
	});
	const slots = [
		slot(1, at(2026, 10, 7, 23, 0), 9, 100), // Wed, later today
		slot(2, at(2026, 10, 7, 12, 0), 4, 101), // Wed, aired
		slot(3, at(2026, 10, 9, 23, 0), 7, 102), // Fri
		slot(4, at(2026, 10, 12, 1, 0), 1, 103) // next Monday: outside the week
	];

	it('puts slots on local days, in time order, with today and the NOW line', () => {
		const days = buildCalendar(slots, monday, { now });
		expect(days.map((d) => d.name)).toEqual(['Mon', 'Tue', 'Today', 'Thu', 'Fri', 'Sat', 'Sun']);
		expect(days[2].label).toBe('Oct 7');
		expect(days[2].slots.map((s) => [s.time, s.aired, s.countdown])).toEqual([
			['12:00', true, 'EP 4 · aired'],
			['23:00', false, 'EP 9 · 4h 40m']
		]);
		expect(days[2].nowIndex).toBe(1);
		expect(days[2].slots[1].soon).toBe(true);
		expect(days[4].slots[0]).toMatchObject({ countdown: 'EP 7 · 2d 4h', soon: false });
		expect(days.flatMap((d) => d.slots)).toHaveLength(3);
	});

	it('reads like AniChart and marks the week’s next episode', () => {
		const days = buildCalendar(slots, monday, { now });
		expect(days[2].weekday).toBe('Wednesday');
		expect(days[2].slots.map((s) => [s.status, s.until, s.next])).toEqual([
			['Ep 4 aired at 12:00', '', false],
			['Ep 9 airing at 23:00', '4h 40m', true]
		]);
		expect(days[4].slots[0].next).toBe(false);
	});

	it('shows today first and the days already past last', () => {
		const days = upcomingFirst(buildCalendar(slots, monday, { now }));
		expect(days.map((d) => [d.name, d.past])).toEqual([
			['Today', false],
			['Thu', false],
			['Fri', false],
			['Sat', false],
			['Sun', false],
			['Mon', true],
			['Tue', true]
		]);
		const other = upcomingFirst(buildCalendar(slots, mondayOf(at(2026, 10, 14)), { now }));
		expect(other.map((d) => d.name)).toEqual(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
		expect(other.flatMap((d) => d.slots).some((s) => s.next)).toBe(false);
	});

	it('has no today or NOW line in another week', () => {
		const days = buildCalendar(slots, mondayOf(at(2026, 10, 14)), { now });
		expect(days.some((d) => d.isToday || d.nowIndex !== null)).toBe(false);
	});

	it('marks the viewer’s shows, offers +1 once out, and can show only those', () => {
		const entry = (id: number) =>
			id === 101
				? { status: 'CURRENT' as const, progress: 3 }
				: id === 100
					? { status: 'CURRENT' as const, progress: 8 }
					: id === 102
						? { status: 'PLANNING' as const, progress: 0 }
						: null;
		const days = buildCalendar(slots, monday, { now, entry });
		const [aired, later] = days[2].slots;
		expect(aired).toMatchObject({ mine: true, canAddOne: true });
		expect(later).toMatchObject({ mine: true, canAddOne: false });
		expect(days[4].slots[0].mine).toBe(false); // Planning isn't "watching"
		expect(days[2].hasMine).toBe(true);

		const mine = buildCalendar(slots, monday, { now, entry, mineOnly: true });
		expect(mine.flatMap((d) => d.slots).map((s) => s.title.id)).toEqual([101, 100]);
	});
});

describe('slimForSchedule', () => {
	it('keeps every airing card the same, leaving out what a card never shows', () => {
		const monday = mondayOf(at(2026, 10, 7));
		const now = at(2026, 10, 7, 18, 20);
		const slots: AiringSlot[] = [
			{ id: 1, episode: 9, airingAt: unix(at(2026, 10, 7, 23)), media: makeMedia({ id: 100 }) },
			{ id: 2, episode: 4, airingAt: unix(at(2026, 10, 9, 12)), media: makeMedia({ id: 101 }) }
		];
		const slim = slimForSchedule(slots);
		expect(slim[0].media.genres).toEqual([]);
		expect(slim[0].media.studios.nodes).toEqual([]);
		// what an airing card reads (+page.svelte's airingCard and CoverImage)
		const shown = (s: AiringSlot[]) =>
			buildCalendar(s, monday, { now, titles: 'english' }).flatMap((d) =>
				d.slots.map(({ title, ...slot }) => ({
					...slot,
					title: {
						id: title.id,
						title: title.title,
						total: title.total,
						accent: title.accent,
						placeholder: title.placeholder,
						coverUrl: title.coverUrl,
						thumbUrl: title.thumbUrl,
						thumbSmallUrl: title.thumbSmallUrl
					}
				}))
			);
		expect(shown(slim)).toEqual(shown(slots));
	});
});

describe('serverWeek', () => {
	const now = at(2026, 10, 7, 18, 20);
	const week = Array.from({ length: 120 }, (_, i) => ({
		id: i,
		episode: 1,
		airingAt: unix(at(2026, 10, 5)) + i * 3600,
		media: makeMedia({ id: 1000 + i })
	}));

	it('renders the next airings from a day ago, slimmed', () => {
		const slots = serverWeek(week, now);
		expect(slots).toHaveLength(SERVER_AIRINGS);
		expect(slots[0].airingAt).toBeGreaterThanOrEqual(unix(now) - 86400);
		expect(slots[0].airingAt - 3600).toBeLessThan(unix(now) - 86400);
		expect(slots[0].media.genres).toEqual([]);
	});

	it("renders a past week's first airings", () => {
		expect(serverWeek(week, at(2026, 11, 1)).map((s) => s.id)).toEqual(
			week.slice(0, SERVER_AIRINGS).map((s) => s.id)
		);
	});
});
