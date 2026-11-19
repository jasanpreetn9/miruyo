import type { EntryInput } from '#lib/anilist/client.ts';
import type { AniListDate, AniListSavedEntry, MediaListStatus } from '#lib/anilist/types.ts';

// The list editor works on a draft: edits stay local until Save, and only
// the fields that actually changed are sent to AniList.

export interface EntryDraft {
	status: MediaListStatus;
	progress: number;
	progressVolumes: number;
	score: number;
	/** YYYY-MM-DD, or '' when not set — the value of an <input type="date">. */
	startedAt: string;
	completedAt: string;
	repeat: number;
	notes: string;
	private: boolean;
	/** The custom lists it's on, by name, in the account's order. */
	customLists: string[];
}

/** What the editor needs to know about the title itself. */
export interface DraftTotals {
	/** Episodes (anime) or chapters (manga); null when unknown/ongoing. */
	total: number | null;
	/** Manga volumes; null when unknown. */
	volumes: number | null;
}

const pad = (n: number) => String(n).padStart(2, '0');

/** A complete AniList date as YYYY-MM-DD; partial or empty dates → ''. */
export function dateToInput(date: AniListDate | null | undefined): string {
	if (!date?.year || !date.month || !date.day) return '';
	return `${date.year}-${pad(date.month)}-${pad(date.day)}`;
}

export function inputToDate(value: string): AniListDate {
	const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
	if (!m) return { year: null, month: null, day: null };
	return { year: Number(m[1]), month: Number(m[2]), day: Number(m[3]) };
}

/** Today in the viewer's local time, as YYYY-MM-DD. */
export function todayInput(now = new Date()): string {
	return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

/** The draft for an existing entry, or for a title not on the list yet (Planning). */
export function draftFrom(
	entry: AniListSavedEntry | null,
	fallback?: { status: MediaListStatus; progress: number }
): EntryDraft {
	return {
		status: entry?.status ?? fallback?.status ?? 'PLANNING',
		progress: entry?.progress ?? fallback?.progress ?? 0,
		progressVolumes: entry?.progressVolumes ?? 0,
		score: entry?.score ?? 0,
		startedAt: dateToInput(entry?.startedAt),
		completedAt: dateToInput(entry?.completedAt),
		repeat: entry?.repeat ?? 0,
		notes: entry?.notes ?? '',
		private: entry?.private ?? false,
		customLists: (entry?.customLists ?? []).filter((l) => l.enabled).map((l) => l.name)
	};
}

/** Whether two sets of custom list names are the same, whatever their order. */
export function sameLists(a: string[], b: string[]): boolean {
	const key = (names: string[]) => [...names].sort().join('\n');
	return key(a) === key(b);
}

/**
 * Whether one draft field differs from another: by value, and custom lists
 * by the names in them (they're a new array after every toggle).
 */
export function fieldEdited<K extends keyof EntryDraft>(
	key: K,
	a: EntryDraft,
	b: EntryDraft
): boolean {
	return key === 'customLists' ? !sameLists(a.customLists, b.customLists) : a[key] !== b[key];
}

/**
 * Puts the entry on a custom list, or takes it off, keeping `order` (the
 * account's order of its lists).
 */
export function withCustomList(draft: EntryDraft, name: string, order: string[]): EntryDraft {
	const on = new Set(draft.customLists);
	if (on.has(name)) on.delete(name);
	else on.add(name);
	return { ...draft, customLists: order.filter((n) => on.has(n)) };
}

/**
 * Every custom list of the title's type, in the account's order: its own
 * settings (empty lists too), then any the entry names that aren't there.
 */
export function customListNames(
	account: string[] | null | undefined,
	entry: AniListSavedEntry | null
): string[] {
	const names = [...(account ?? [])];
	for (const l of entry?.customLists ?? []) if (!names.includes(l.name)) names.push(l.name);
	return names;
}

/**
 * Picking a status, with the design's smart defaults: starting fills the start
 * date with today; completing fills progress to the total and the finish date.
 */
export function withStatus(
	draft: EntryDraft,
	status: MediaListStatus,
	totals: DraftTotals,
	today = todayInput()
): EntryDraft {
	const next = { ...draft, status };
	if (status === 'CURRENT' && !next.startedAt) next.startedAt = today;
	if (status === 'COMPLETED') {
		if (totals.total) next.progress = totals.total;
		if (totals.volumes) next.progressVolumes = totals.volumes;
		if (!next.completedAt) next.completedAt = today;
		// no start date is guessed here: it began earlier, on a day we don't know
	}
	return next;
}

/** Progress, clamped to 0…total; never changes the status on its own. */
export function withProgress(draft: EntryDraft, progress: number, totals: DraftTotals): EntryDraft {
	const max = totals.total ?? Number.MAX_SAFE_INTEGER;
	return { ...draft, progress: Math.max(0, Math.min(max, Math.round(progress))) };
}

export function withVolumes(draft: EntryDraft, volumes: number, totals: DraftTotals): EntryDraft {
	const max = totals.volumes ?? Number.MAX_SAFE_INTEGER;
	return { ...draft, progressVolumes: Math.max(0, Math.min(max, Math.round(volumes))) };
}

/** True when the last episode/chapter is reached but the entry isn't Completed yet. */
export function offersCompletion(draft: EntryDraft, totals: DraftTotals): boolean {
	return !!totals.total && draft.progress >= totals.total && draft.status !== 'COMPLETED';
}

/** Only the fields that differ from `initial`, in SaveMediaListEntry's terms. */
export function changes(initial: EntryDraft, draft: EntryDraft): EntryInput {
	const patch: EntryInput = {};
	if (draft.status !== initial.status) patch.status = draft.status;
	if (draft.progress !== initial.progress) patch.progress = draft.progress;
	if (draft.progressVolumes !== initial.progressVolumes)
		patch.progressVolumes = draft.progressVolumes;
	if (draft.score !== initial.score) patch.score = draft.score;
	if (draft.startedAt !== initial.startedAt) patch.startedAt = inputToDate(draft.startedAt);
	if (draft.completedAt !== initial.completedAt) patch.completedAt = inputToDate(draft.completedAt);
	if (draft.repeat !== initial.repeat) patch.repeat = draft.repeat;
	if (draft.notes !== initial.notes) patch.notes = draft.notes;
	if (draft.private !== initial.private) patch.private = draft.private;
	if (!sameLists(draft.customLists, initial.customLists)) patch.customLists = draft.customLists;
	return patch;
}

export function isDirty(initial: EntryDraft, draft: EntryDraft): boolean {
	return Object.keys(changes(initial, draft)).length > 0;
}
