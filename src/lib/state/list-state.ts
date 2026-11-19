import { fetchListEntries } from '#lib/anilist/client.ts';
import { list, type SeedEntry } from './list.svelte.ts';
import { session } from './session.svelte.ts';

/**
 * Fetches the viewer's list entries for titles that arrived without them
 * (Browse results, a title's recommendations) and shares them with every
 * card. Only while signed in; failing just means no list state on those
 * cards, so errors are logged, not thrown.
 */
export async function loadListState(mediaIds: number[]): Promise<void> {
	const userId = session.user?.id;
	if (!userId || session.authState !== 'in' || !mediaIds.length) return;
	// titles edited while this is in flight keep their local values
	const since = list.stamp();
	try {
		const found = await fetchListEntries(userId, mediaIds);
		const entries: SeedEntry[] = found.map((e) => ({
			id: e.id,
			mediaId: e.mediaId,
			status: e.status,
			progress: e.progress
		}));
		list.seed(entries, since);
	} catch (err) {
		console.error('Failed to load list state:', err);
	}
}
