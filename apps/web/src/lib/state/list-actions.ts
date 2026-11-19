import type { EntryInput } from '#lib/anilist/client.ts';
import type { MediaListStatus } from '#lib/anilist/types.ts';
import { plusOneOutcome } from '#lib/catalog/progress.ts';
import { statusLabel } from '#lib/catalog/status.ts';
import type { Title } from '#lib/catalog/types.ts';
import { entryFromTitle, list, type ListEntry } from './list.svelte.ts';
import { toast } from './toast.svelte.ts';

// The list changes people make from cards, rows and pages. Each applies at
// once (the store saves to AniList and rolls back on failure) and confirms
// with a toast that can undo it.

function failed(title: Title) {
	toast.show({ message: `Couldn't save ${title.title} to AniList`, tone: 'error' });
}

/** The saveable fields of an entry, to put it back as it was. */
function fieldsOf(entry: ListEntry): EntryInput {
	const { status, progress, progressVolumes, score, repeat, notes, startedAt, completedAt } = entry;
	const { onCustomLists: customLists } = entry;
	return {
		status,
		progress,
		...(progressVolumes != null && { progressVolumes }),
		...(score != null && { score }),
		...(repeat != null && { repeat }),
		...(notes != null && { notes }),
		...(startedAt && { startedAt }),
		...(completedAt && { completedAt }),
		...(customLists && { customLists })
	};
}

/**
 * Undo a change. `previous` null means the change added the title, so undo
 * takes it off again — once AniList has given the new entry an id.
 */
async function undo(title: Title, previous: ListEntry | null, saving: Promise<boolean>) {
	if (!previous) {
		await saving;
		await list.remove(title.id);
		return;
	}
	await list.update(title.id, fieldsOf(previous), previous);
}

/** "Steins;Gate · EP 9 / 24" */
function progressMessage(title: Title, progress: number): string {
	return `${title.title} · ${title.unit} ${progress} / ${title.total ?? '?'}`;
}

/**
 * +1 episode/chapter from anywhere in the app, with an Undo toast. Reaching
 * the total moves the title to Completed right away; a +1 on something
 * planned starts it. Past what has aired it says when the episode airs and
 * logs it only on "Log anyway". Resolves to whether the change was saved.
 */
export async function plusOne(title: Title, beyondAired = false): Promise<boolean> {
	const base = entryFromTitle(title);
	const current = list.entryFor(title);
	const outcome = plusOneOutcome(current, title.total);
	if (!outcome) return false;
	const next = title.next;
	if (!beyondAired && next && outcome.progress >= next.ep) {
		toast.show({
			message: `${title.unit} ${next.ep} hasn't aired yet`,
			action: { label: 'Log anyway', run: () => void plusOne(title, true) }
		});
		return false;
	}
	const previous = current ? { ...current } : null;
	// a +1 on something planned means it's started
	const patch = outcome.completes
		? { progress: outcome.progress, status: 'COMPLETED' as const }
		: outcome.starts
			? { progress: outcome.progress, status: 'CURRENT' as const }
			: { progress: outcome.progress };
	const saving = list.update(title.id, patch, base);
	toast.show({
		message:
			outcome.completes && current
				? `${title.title} moved to Completed`
				: progressMessage(title, outcome.progress),
		action: { label: 'Undo', run: () => void undo(title, previous, saving) }
	});
	const ok = await saving;
	if (!ok) failed(title);
	return ok;
}

/** −1 episode/chapter, with an Undo toast. Does nothing at 0 or off the list. */
export async function minusOne(title: Title): Promise<boolean> {
	const current = list.entryFor(title);
	if (!current || current.progress <= 0) return false;
	const previous = { ...current };
	const progress = current.progress - 1;
	const saving = list.update(title.id, { progress }, entryFromTitle(title));
	toast.show({
		message: progressMessage(title, progress),
		action: { label: 'Undo', run: () => void undo(title, previous, saving) }
	});
	const ok = await saving;
	if (!ok) failed(title);
	return ok;
}

/**
 * Adds the title to the list with `status`, or moves it there, and says so:
 * "Added X to Planning" / "Moved X to Watching", with Undo.
 */
export async function changeStatus(title: Title, status: MediaListStatus): Promise<boolean> {
	const current = list.entryFor(title);
	if (current?.status === status) return true;
	const previous = current ? { ...current } : null;
	const saving = list.setStatus(title.id, status, entryFromTitle(title));
	const label = statusLabel(status, title.isAnime);
	toast.show({
		message: previous ? `Moved ${title.title} to ${label}` : `Added ${title.title} to ${label}`,
		action: { label: 'Undo', run: () => void undo(title, previous, saving) }
	});
	const ok = await saving;
	if (!ok) failed(title);
	return ok;
}

/**
 * Confirms a save made in the editor: "Added…", "Moved… to …" or "Saved…",
 * with Undo back to `previous` (null = it wasn't on the list).
 */
export function confirmSaved(
	title: Title,
	previous: ListEntry | null,
	status: MediaListStatus
): void {
	const label = statusLabel(status, title.isAnime);
	const message = !previous
		? `Added ${title.title} to ${label}`
		: previous.status !== status
			? `Moved ${title.title} to ${label}`
			: `Saved ${title.title}`;
	toast.show({
		message,
		action: { label: 'Undo', run: () => void undo(title, previous, Promise.resolve(true)) }
	});
}

/** Takes the title off the list ("Removed X from your list"); Undo adds it back as it was. */
export async function removeFromList(title: Title, base?: ListEntry | null): Promise<boolean> {
	const current = list.get(title.id) ?? base ?? null;
	const previous = current ? { ...current } : null;
	const ok = await list.remove(title.id, base);
	if (!ok) {
		toast.show({ message: `Couldn't remove ${title.title} from AniList`, tone: 'error' });
		return false;
	}
	toast.show({
		message: `Removed ${title.title} from your list`,
		action: previous
			? {
					label: 'Undo',
					// a new entry with the same fields (AniList gives it a new id)
					run: () => void list.update(title.id, fieldsOf(previous), null)
				}
			: undefined
	});
	return true;
}
