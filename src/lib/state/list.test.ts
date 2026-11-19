import { describe, expect, it, vi } from 'vitest';
import type { EntryInput } from '#lib/anilist/client.ts';
import type { AniListSavedEntry } from '#lib/anilist/types.ts';
import type { Title } from '#lib/catalog/types.ts';
import { entryFromTitle, ListStore, type ListApi, type ListEntry } from './list.svelte.ts';

function saved(mediaId: number, input: EntryInput, id = 99): AniListSavedEntry {
	return {
		id,
		mediaId,
		status: input.status ?? 'CURRENT',
		progress: input.progress ?? 0,
		progressVolumes: null,
		score: 0,
		repeat: 0,
		notes: null,
		private: false,
		startedAt: { year: null, month: null, day: null },
		completedAt: { year: null, month: null, day: null }
	};
}

function deferred<T>() {
	let resolve!: (v: T) => void;
	let reject!: (e: unknown) => void;
	const promise = new Promise<T>((res, rej) => {
		resolve = res;
		reject = rej;
	});
	return { promise, resolve, reject };
}

function makeStore(api: Partial<ListApi> = {}) {
	const store = new ListStore({
		save: vi.fn(async (mediaId: number, input: EntryInput) => saved(mediaId, input)),
		remove: vi.fn(async () => true),
		...api
	});
	store.sync = true;
	return store;
}

const base: ListEntry = { id: 7, mediaId: 1, status: 'CURRENT', progress: 5 };

describe('ListStore', () => {
	it('applies an edit immediately and keeps what AniList returns', async () => {
		const store = makeStore();
		const pending = store.increment(1, 24, base);
		expect(store.get(1)?.progress).toBe(6);
		await expect(pending).resolves.toBe(true);
		expect(store.get(1)).toMatchObject({ id: 99, progress: 6 });
	});

	it('only sends the changed fields', async () => {
		const save = vi.fn(async (mediaId: number, input: EntryInput) => saved(mediaId, input));
		const store = makeStore({ save });
		await store.setStatus(1, 'PAUSED', base);
		expect(save).toHaveBeenCalledWith(1, { status: 'PAUSED' });
	});

	it('rolls back when the save fails', async () => {
		const store = makeStore({ save: vi.fn().mockRejectedValue(new Error('nope')) });
		vi.spyOn(console, 'error').mockImplementation(() => {});
		await expect(store.increment(1, 24, base)).resolves.toBe(false);
		expect(store.get(1)?.progress).toBe(5);
	});

	it('removes a brand-new entry again when its first save fails', async () => {
		const store = makeStore({ save: vi.fn().mockRejectedValue(new Error('nope')) });
		vi.spyOn(console, 'error').mockImplementation(() => {});
		await store.setStatus(2, 'PLANNING');
		expect(store.get(2)).toBeUndefined();
	});

	it("doesn't roll back over a newer edit", async () => {
		const first = deferred<AniListSavedEntry>();
		const save = vi
			.fn()
			.mockReturnValueOnce(first.promise)
			.mockImplementationOnce(async (id: number, input: EntryInput) => saved(id, input));
		const store = makeStore({ save });
		vi.spyOn(console, 'error').mockImplementation(() => {});

		const a = store.increment(1, 24, base); // 6, slow and doomed
		await store.increment(1, 24); // 7, succeeds
		first.reject(new Error('late failure'));
		await a;
		expect(store.get(1)?.progress).toBe(7);
	});

	it('caps +1 at the total and never auto-completes', async () => {
		const store = makeStore();
		await store.increment(1, 6, base);
		expect(store.get(1)).toMatchObject({ progress: 6, status: 'CURRENT' });
		await expect(store.increment(1, 6)).resolves.toBe(false);
	});

	it('keeps counting when the total is unknown', async () => {
		const store = makeStore();
		await store.increment(1, null, { ...base, progress: 500 });
		expect(store.get(1)?.progress).toBe(501);
	});

	it("doesn't let a stale query overwrite an edit that's still saving", async () => {
		const slow = deferred<AniListSavedEntry>();
		const store = makeStore({ save: vi.fn().mockReturnValue(slow.promise) });
		const pending = store.increment(1, 24, base);
		store.seed([{ id: 7, mediaId: 1, status: 'CURRENT', progress: 5 }]);
		expect(store.get(1)?.progress).toBe(6);
		slow.resolve(saved(1, { progress: 6 }));
		await pending;
		store.seed([{ id: 7, mediaId: 1, status: 'CURRENT', progress: 9 }]);
		expect(store.get(1)?.progress).toBe(9);
	});

	it("doesn't let a query that started before an edit overwrite it after it saved", async () => {
		const store = makeStore();
		store.seed([base]);
		const since = store.stamp(); // a Home fetch starts here
		await store.increment(1, 24, base); // +1 saves and finishes first
		// …then the older response arrives
		store.seed([{ ...base, progress: 5 }], since);
		expect(store.get(1)?.progress).toBe(6);
		// a query started after the edit is taken in
		store.seed([{ ...base, progress: 8 }], store.stamp());
		expect(store.get(1)?.progress).toBe(8);
	});

	it("doesn't let a save from before a sign-out overwrite a newer edit", async () => {
		const slow = deferred<AniListSavedEntry>();
		const save = vi
			.fn()
			.mockReturnValueOnce(slow.promise)
			.mockImplementation(async (id: number, input: EntryInput) => saved(id, input));
		const store = makeStore({ save });
		const stale = store.increment(1, 24, base); // progress 6, pending
		store.clear(); // signed out
		await store.update(1, { progress: 2 }, { ...base, progress: 1 }); // new session's edit
		slow.resolve(saved(1, { progress: 6 }));
		await stale;
		expect(store.get(1)?.progress).toBe(2);
	});

	it('keeps a removed title off the list instead of falling back to its fetched entry', async () => {
		const store = makeStore();
		const title = { id: 1, me: { s: 'CURRENT', p: 5 } } as unknown as Title;
		store.seed([base]);
		await store.remove(1);
		expect(store.entryFor(title)).toBeNull();
		expect(store.isRemoved(1)).toBe(true);

		// adding it back starts fresh, not from the removed entry
		await store.setStatus(1, 'PLANNING', entryFromTitle(title));
		expect(store.isRemoved(1)).toBe(false);
		expect(store.entryFor(title)).toMatchObject({ status: 'PLANNING', progress: 0 });
	});

	it('keeps a removed title off the list when a copy from before the removal is seeded', async () => {
		const store = makeStore();
		store.seed([base]);
		const since = store.stamp(); // the copy served stale was requested here
		await store.remove(1);
		store.seed([base], since);
		expect(store.isRemoved(1)).toBe(true);
		// a copy requested after the removal no longer holds it
		store.seed([], store.stamp());
		expect(store.isRemoved(1)).toBe(true);
	});

	it('restores a removed title when the delete fails', async () => {
		const store = makeStore({ remove: vi.fn().mockRejectedValue(new Error('nope')) });
		vi.spyOn(console, 'error').mockImplementation(() => {});
		store.seed([base]);
		await store.remove(1);
		expect(store.isRemoved(1)).toBe(false);
		expect(store.get(1)).toMatchObject({ id: 7, progress: 5 });
	});

	it('stays local while signed out', async () => {
		const save = vi.fn();
		const store = makeStore({ save });
		store.sync = false;
		await store.increment(1, 24, base);
		expect(store.get(1)?.progress).toBe(6);
		expect(save).not.toHaveBeenCalled();
	});

	it('deletes by list entry id and restores on failure', async () => {
		const remove = vi.fn().mockRejectedValueOnce(new Error('nope')).mockResolvedValueOnce(true);
		const store = makeStore({ remove });
		vi.spyOn(console, 'error').mockImplementation(() => {});
		store.seed([base]);

		await expect(store.remove(1)).resolves.toBe(false);
		expect(store.get(1)).toMatchObject({ id: 7 });

		await expect(store.remove(1)).resolves.toBe(true);
		expect(remove).toHaveBeenLastCalledWith(7);
		expect(store.get(1)).toBeUndefined();
	});
});
