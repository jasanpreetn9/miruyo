import {
	deleteEntry,
	onRefreshed,
	saveEntry,
	useEditClock,
	type EntryInput
} from '#lib/anilist/client.ts';
import type { AniListDate, AniListSavedEntry, MediaListStatus } from '#lib/anilist/types.ts';
import type { Title } from '#lib/catalog/types.ts';

/** One title on the viewer's list, in AniList's own terms. */
export interface ListEntry {
	/** AniList's list-entry id; null until AniList has returned one. */
	id: number | null;
	mediaId: number;
	status: MediaListStatus;
	progress: number;
	progressVolumes?: number | null;
	score?: number;
	repeat?: number;
	notes?: string | null;
	private?: boolean;
	startedAt?: AniListDate;
	completedAt?: AniListDate;
	/**
	 * The custom lists it's on, by name; undefined when not known. (Not
	 * `customLists`: saved entries spread in carry AniList's own shape.)
	 */
	onCustomLists?: string[];
}

/** A partial entry from a list query — e.g. HOME_QUERY's continue list. */
export type SeedEntry = Pick<ListEntry, 'id' | 'mediaId' | 'status' | 'progress'> &
	Partial<ListEntry>;

export interface ListApi {
	save(mediaId: number, input: EntryInput): Promise<AniListSavedEntry>;
	remove(entryId: number): Promise<boolean>;
}

function fromSaved(saved: AniListSavedEntry): ListEntry {
	return {
		id: saved.id,
		mediaId: saved.mediaId,
		status: saved.status,
		progress: saved.progress,
		progressVolumes: saved.progressVolumes,
		score: saved.score,
		repeat: saved.repeat,
		notes: saved.notes,
		private: saved.private,
		startedAt: saved.startedAt,
		completedAt: saved.completedAt
	};
}

/** The list entry a title arrived with (adaptMedia / the mock catalog). */
export function entryFromTitle(title: Title): ListEntry | null {
	if (!title.me) return null;
	return {
		id: null,
		mediaId: title.id,
		status: title.me.s,
		progress: title.me.p,
		progressVolumes: title.me.v ?? null,
		score: title.me.sc
	};
}

/**
 * Every list entry the app knows about, keyed by media id, so a change made
 * on one card shows on every other card for the same title. Edits apply
 * immediately and roll back if AniList rejects them.
 */
export class ListStore {
	entries = $state<Record<number, ListEntry>>({});
	/**
	 * Titles taken off the list this visit. Kept separately so entryFor()
	 * doesn't fall back to the (stale) entry the title was fetched with.
	 */
	removed = $state<Record<number, true>>({});
	/** Only save to AniList while signed in; signed out, edits stay local. */
	sync = $state(false);
	/**
	 * Goes up when a save changes which custom lists a title is on, so My
	 * List reloads its custom tabs (they come from the list collection).
	 */
	customListsVersion = $state(0);
	/**
	 * Goes up when a list collection served stale has been reloaded behind
	 * the page: pages that show one load it again (same key, so their rows
	 * stay), from the cache, at once.
	 */
	collectionsVersion = $state(0);

	#api: ListApi;
	/**
	 * A clock that ticks on every local edit and is never reset, so versions
	 * stay unique across clear() — a save that resolves after a sign-out can't
	 * be mistaken for a newer edit.
	 */
	#clock = 0;
	/** The clock value of each title's latest local edit. */
	#versions = new Map<number, number>();
	#inFlight = new Map<number, number>();

	constructor(api: ListApi) {
		this.#api = api;
	}

	get(mediaId: number): ListEntry | undefined {
		return this.entries[mediaId];
	}

	isRemoved(mediaId: number): boolean {
		return !!this.removed[mediaId];
	}

	/** This store's entry for the title, else the one the title was fetched with. */
	entryFor(title: Title): ListEntry | null {
		if (this.removed[title.id]) return null;
		return this.entries[title.id] ?? entryFromTitle(title);
	}

	isSaving(mediaId: number): boolean {
		return (this.#inFlight.get(mediaId) ?? 0) > 0;
	}

	/** Call before starting a list query; pass the result to seed(). */
	stamp(): number {
		return this.#clock;
	}

	#bump(mediaId: number): number {
		const version = ++this.#clock;
		this.#versions.set(mediaId, version);
		return version;
	}

	/**
	 * Takes in fresh entries from a query. `since` is the stamp() taken when
	 * the query started: titles edited after that keep their local values,
	 * since the response predates the edit — even if the edit has already
	 * finished saving. Entries with a save in flight are always kept.
	 */
	seed(entries: SeedEntry[], since = Infinity): void {
		for (const entry of entries) {
			if (this.isSaving(entry.mediaId)) continue;
			if ((this.#versions.get(entry.mediaId) ?? 0) > since) continue;
			delete this.removed[entry.mediaId];
			this.entries[entry.mediaId] = { ...this.entries[entry.mediaId], ...entry };
		}
	}

	/**
	 * Applies `patch` now and saves it. `base` is the entry to start from when
	 * the store doesn't have one yet (usually entryFromTitle). Resolves to
	 * whether the change stuck.
	 */
	async update(mediaId: number, patch: EntryInput, base?: ListEntry | null): Promise<boolean> {
		const wasRemoved = this.isRemoved(mediaId);
		const current = wasRemoved ? null : (this.entries[mediaId] ?? base ?? null);
		const previous = current ? $state.snapshot(current) : null;
		const version = this.#bump(mediaId);

		delete this.removed[mediaId];
		this.entries[mediaId] = {
			id: null,
			mediaId,
			status: 'PLANNING',
			progress: 0,
			...previous,
			...patch
		};

		if (!this.sync) return true;

		this.#inFlight.set(mediaId, (this.#inFlight.get(mediaId) ?? 0) + 1);
		try {
			const saved = await this.#api.save(mediaId, patch);
			if (this.#versions.get(mediaId) === version) {
				this.entries[mediaId] = fromSaved(saved);
			} else if (this.entries[mediaId]) {
				// a newer edit is on its way; just keep the id AniList assigned
				this.entries[mediaId].id = saved.id;
			}
			return true;
		} catch (err) {
			console.error(`Failed to save list entry for media ${mediaId}:`, err);
			// roll back, unless a later edit has already superseded this one
			if (this.#versions.get(mediaId) === version) {
				if (previous) this.entries[mediaId] = previous;
				else delete this.entries[mediaId];
				if (wasRemoved) this.removed[mediaId] = true;
			}
			return false;
		} finally {
			this.#inFlight.set(mediaId, (this.#inFlight.get(mediaId) ?? 1) - 1);
		}
	}

	/**
	 * +1 episode/chapter, capped at `total` when known. Never changes the
	 * status — reaching the total only offers "Mark completed?".
	 */
	increment(mediaId: number, total: number | null, base?: ListEntry | null): Promise<boolean> {
		const current = this.isRemoved(mediaId) ? undefined : (this.entries[mediaId] ?? base);
		const progress = current?.progress ?? 0;
		const next = total ? Math.min(total, progress + 1) : progress + 1;
		if (next === progress) return Promise.resolve(false);
		return this.update(mediaId, { progress: next }, base);
	}

	setStatus(mediaId: number, status: MediaListStatus, base?: ListEntry | null): Promise<boolean> {
		return this.update(mediaId, { status }, base);
	}

	/** Takes the title off the list. Resolves to whether that stuck. */
	async remove(mediaId: number, base?: ListEntry | null): Promise<boolean> {
		if (this.isRemoved(mediaId)) return true;
		const current = this.entries[mediaId] ?? base ?? null;
		if (!current) return true;
		const previous = $state.snapshot(current);
		const version = this.#bump(mediaId);
		const restore = () => {
			if (this.#versions.get(mediaId) !== version) return;
			delete this.removed[mediaId];
			this.entries[mediaId] = previous;
		};
		delete this.entries[mediaId];
		this.removed[mediaId] = true;

		if (!this.sync) return true;
		if (previous.id === null) {
			console.error(`Can't delete media ${mediaId}: no list entry id yet.`);
			restore();
			return false;
		}

		this.#inFlight.set(mediaId, (this.#inFlight.get(mediaId) ?? 0) + 1);
		try {
			await this.#api.remove(previous.id);
			return true;
		} catch (err) {
			console.error(`Failed to delete list entry for media ${mediaId}:`, err);
			restore();
			return false;
		} finally {
			this.#inFlight.set(mediaId, (this.#inFlight.get(mediaId) ?? 1) - 1);
		}
	}

	/**
	 * Forgets every entry (sign-out). The clock keeps running and in-flight
	 * counts are kept, so saves still pending from before can't overwrite
	 * anything made after.
	 */
	clear(): void {
		this.entries = {};
		this.removed = {};
		this.#versions.clear();
	}
}

export const list = new ListStore({ save: saveEntry, remove: deleteEntry });
// each request remembers the edits it predates (requestStamp)
useEditClock(() => list.stamp());
onRefreshed(() => list.collectionsVersion++);
