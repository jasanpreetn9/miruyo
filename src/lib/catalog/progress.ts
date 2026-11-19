import type { MediaListStatus } from '#lib/anilist/types.ts';
import { isInProgress } from './status.ts';
import type { Title } from './types.ts';

export interface PlusOne {
	progress: number;
	/** True when this +1 reaches the total: the entry moves to Completed. */
	completes: boolean;
	/** True for a +1 on a Planning entry: you've started it, so it moves to Watching. */
	starts: boolean;
}

/**
 * What a +1 does. Reaching the last episode/chapter of something in
 * progress completes it (with an Undo toast, everywhere in the app); with no
 * known total it just keeps counting. null = nothing to do (already at the end).
 */
export function plusOneOutcome(
	current: { status: MediaListStatus; progress: number } | null,
	total: number | null
): PlusOne | null {
	const progress = current?.progress ?? 0;
	if (total && progress >= total) return null;
	const next = progress + 1;
	const starts = current?.status === 'PLANNING';
	const completes =
		!!total && next >= total && !!current && (isInProgress(current.status) || starts);
	return { progress: next, completes, starts: starts && !completes };
}

/**
 * Episodes (or chapters) out so far, when that's known: the one before the
 * next to air, or the total once it's finished. Null for manga still
 * running and anything AniList has no schedule for.
 */
export function airedCount(title: Pick<Title, 'next' | 'status' | 'total'>): number | null {
	if (title.next) return title.next.ep - 1;
	if (title.status === 'Finished') return title.total;
	return null;
}

/** New episodes out for `title` at `progress`, when the schedule says. */
export function newEpisodesFor(
	title: Pick<Title, 'next' | 'status' | 'total'>,
	progress: number
): number | null {
	const aired = airedCount(title);
	return aired == null ? null : Math.max(0, aired - progress);
}

/**
 * Where you are, in the words Home, My List and the title page share:
 * "2 new" while it airs, "16 left" once it's finished, "Caught up" when
 * you've seen everything out. Null when the schedule doesn't say.
 */
export function progressWord(
	title: Pick<Title, 'next' | 'status' | 'total'>,
	progress: number
): string | null {
	const fresh = newEpisodesFor(title, progress);
	if (fresh == null) return null;
	if (fresh === 0) return 'Caught up';
	return title.next ? `${fresh} new` : `${fresh} left`;
}
