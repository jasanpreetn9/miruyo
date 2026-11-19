import { describe, expect, it } from 'vitest';
import type { AniListSavedEntry } from '#lib/anilist/types.ts';
import {
	changes,
	customListNames,
	dateToInput,
	draftFrom,
	fieldEdited,
	inputToDate,
	isDirty,
	offersCompletion,
	todayInput,
	withCustomList,
	withProgress,
	withStatus,
	withVolumes
} from './draft.ts';

const TODAY = '2026-10-07';
const anime = { total: 28, volumes: null };
const ongoing = { total: null, volumes: null };

const entry: AniListSavedEntry = {
	id: 7,
	mediaId: 1,
	status: 'CURRENT',
	progress: 7,
	progressVolumes: null,
	score: 9.5,
	repeat: 0,
	notes: 'Rewatch EP 1',
	private: false,
	startedAt: { year: 2026, month: 10, day: 2 },
	completedAt: { year: null, month: null, day: null }
};

describe('dates', () => {
	it('converts complete AniList dates to and from date inputs', () => {
		expect(dateToInput({ year: 2026, month: 3, day: 9 })).toBe('2026-03-09');
		expect(inputToDate('2026-03-09')).toEqual({ year: 2026, month: 3, day: 9 });
	});

	it('treats partial or empty dates as unset', () => {
		expect(dateToInput({ year: 2026, month: null, day: null })).toBe('');
		expect(dateToInput(null)).toBe('');
		expect(inputToDate('')).toEqual({ year: null, month: null, day: null });
	});

	it('formats today in local time', () => {
		expect(todayInput(new Date(2026, 0, 5))).toBe('2026-01-05');
	});
});

describe('draftFrom', () => {
	it('copies an existing entry', () => {
		expect(draftFrom(entry)).toEqual({
			status: 'CURRENT',
			progress: 7,
			progressVolumes: 0,
			score: 9.5,
			startedAt: '2026-10-02',
			completedAt: '',
			repeat: 0,
			notes: 'Rewatch EP 1',
			private: false,
			customLists: []
		});
	});

	it('starts a new entry as Planning, or from what the card already knew', () => {
		expect(draftFrom(null).status).toBe('PLANNING');
		expect(draftFrom(null, { status: 'PAUSED', progress: 3 })).toMatchObject({
			status: 'PAUSED',
			progress: 3
		});
	});
});

describe('smart defaults', () => {
	it('starting fills the start date with today, but keeps one already set', () => {
		expect(withStatus(draftFrom(null), 'CURRENT', anime, TODAY).startedAt).toBe(TODAY);
		expect(withStatus(draftFrom(entry), 'CURRENT', anime, TODAY).startedAt).toBe('2026-10-02');
	});

	it('completing fills progress to the total and the finish date', () => {
		const done = withStatus(draftFrom(entry), 'COMPLETED', anime, TODAY);
		expect(done).toMatchObject({ status: 'COMPLETED', progress: 28, completedAt: TODAY });
	});

	it('completing a manga fills volumes too, and leaves unknown totals alone', () => {
		const manga = withStatus(
			{ ...draftFrom(null), progress: 90 },
			'COMPLETED',
			{ total: 93, volumes: 8 },
			TODAY
		);
		expect(manga).toMatchObject({ progress: 93, progressVolumes: 8 });
		expect(
			withStatus({ ...draftFrom(null), progress: 40 }, 'COMPLETED', ongoing, TODAY).progress
		).toBe(40);
	});

	it('offers completion at the last episode, never completes on its own', () => {
		const atEnd = withProgress(draftFrom(entry), 28, anime);
		expect(atEnd.status).toBe('CURRENT');
		expect(offersCompletion(atEnd, anime)).toBe(true);
		expect(offersCompletion(withProgress(draftFrom(entry), 27, anime), anime)).toBe(false);
		expect(offersCompletion(atEnd, ongoing)).toBe(false);
	});

	it('clamps progress and volumes to their totals', () => {
		expect(withProgress(draftFrom(entry), 99, anime).progress).toBe(28);
		expect(withProgress(draftFrom(entry), -3, anime).progress).toBe(0);
		expect(withProgress(draftFrom(entry), 500, ongoing).progress).toBe(500);
		expect(withVolumes(draftFrom(null), 12, { total: null, volumes: 8 }).progressVolumes).toBe(8);
	});
});

describe('changes', () => {
	it('sends only what changed, with dates in AniList form', () => {
		const initial = draftFrom(entry);
		const draft = { ...withStatus(initial, 'COMPLETED', anime, TODAY), notes: 'Loved it' };
		expect(changes(initial, draft)).toEqual({
			status: 'COMPLETED',
			progress: 28,
			completedAt: { year: 2026, month: 10, day: 7 },
			notes: 'Loved it'
		});
	});

	it('clears a date by sending an all-null date', () => {
		const initial = draftFrom(entry);
		expect(changes(initial, { ...initial, startedAt: '' })).toEqual({
			startedAt: { year: null, month: null, day: null }
		});
	});

	it('knows when nothing changed', () => {
		const initial = draftFrom(entry);
		expect(isDirty(initial, { ...initial })).toBe(false);
		expect(isDirty(initial, { ...initial, private: true })).toBe(true);
	});
});

describe('custom lists', () => {
	const onLists = {
		...entry,
		customLists: [
			{ name: 'Rewatch someday', enabled: true },
			{ name: 'Comfort shows', enabled: false }
		]
	};
	const order = ['Rewatch someday', 'Comfort shows', 'Empty one'];

	it('reads the lists an entry is on', () => {
		expect(draftFrom(onLists).customLists).toEqual(['Rewatch someday']);
		expect(draftFrom(entry).customLists).toEqual([]);
	});

	it('toggles a list, keeping the account order', () => {
		const initial = draftFrom(onLists);
		const added = withCustomList(initial, 'Empty one', order);
		expect(added.customLists).toEqual(['Rewatch someday', 'Empty one']);
		expect(withCustomList(added, 'Rewatch someday', order).customLists).toEqual(['Empty one']);
	});

	it('sends the whole set only when it changed', () => {
		const initial = draftFrom(onLists);
		const added = withCustomList(initial, 'Empty one', order);
		expect(changes(initial, added)).toEqual({ customLists: ['Rewatch someday', 'Empty one'] });
		// on and off again is no change
		expect(isDirty(initial, withCustomList(added, 'Empty one', order))).toBe(false);
	});

	it('counts lists as edited by what is in them, not by the array', () => {
		const initial = draftFrom(onLists);
		const toggledBack = withCustomList(
			withCustomList(initial, 'Empty one', order),
			'Empty one',
			order
		);
		expect(toggledBack.customLists).not.toBe(initial.customLists);
		expect(fieldEdited('customLists', toggledBack, initial)).toBe(false);
		expect(fieldEdited('customLists', withCustomList(initial, 'Empty one', order), initial)).toBe(
			true
		);
		expect(fieldEdited('notes', { ...initial, notes: 'x' }, initial)).toBe(true);
	});

	it("lists the account's lists, empty ones too, then any only the entry knows", () => {
		expect(customListNames(['Comfort shows', 'Empty one'], onLists)).toEqual([
			'Comfort shows',
			'Empty one',
			'Rewatch someday'
		]);
		expect(customListNames(null, null)).toEqual([]);
	});
});
