import type { AniListNotification } from '#lib/anilist/types.ts';
import { relativeTime } from './list.ts';

/** A run of the sentence; `strong` for the subject (a user or a title). */
export interface NotificationPart {
	text: string;
	strong?: boolean;
}

export interface NotificationItem {
	id: number;
	/** "rin started following you." in parts, so the name can be bold. */
	parts: NotificationPart[];
	/** The whole sentence, for the link's accessible name. */
	label: string;
	/** A title page in miruyo, or AniList for activity, forum and profiles. */
	href: string | null;
	external: boolean;
	/** The user's avatar or the title's cover. */
	image: string | null;
	/** Round for people, a poster for titles. */
	imageShape: 'avatar' | 'cover';
	when: string;
	unread: boolean;
	/** Unix seconds, for grouping by day. */
	createdAt: number;
	/** The title it's about, if any. */
	titleId: number | null;
}

const ANILIST = 'https://anilist.co';

function sentence(parts: NotificationPart[]): NotificationPart[] {
	return parts.filter((p) => p.text);
}

/** "Episode 5 of Frieren aired.", from AniList's ["Episode ", " of ", " aired."]. */
function airingParts(n: AniListNotification, title: string): NotificationPart[] {
	const [before, middle, after] =
		n.contexts && n.contexts.length >= 3 ? n.contexts : ['Episode ', ' of ', ' aired.'];
	return sentence([
		{ text: `${before ?? ''}${n.episode ?? ''}${middle ?? ''}` },
		{ text: title, strong: true },
		{ text: after ?? '' }
	]);
}

/**
 * One AniList notification as a line in the bell's list, or null for a type
 * miruyo doesn't show (submission updates and anything AniList adds later).
 */
export function adaptNotification(
	n: AniListNotification,
	{ now, unread, timeZone }: { now: number; unread: boolean; timeZone?: string }
): NotificationItem | null {
	if (n.id === undefined || n.createdAt === undefined) return null;
	const base = {
		id: n.id,
		when: relativeTime(n.createdAt, now, timeZone),
		unread,
		createdAt: n.createdAt,
		titleId: n.media?.id ?? null
	};
	const context = n.context ?? '';

	let parts: NotificationPart[];
	let href: string | null = null;
	let external = true;
	let image: string | null = null;
	let imageShape: NotificationItem['imageShape'] = 'avatar';

	if (n.user) {
		parts = sentence([{ text: n.user.name, strong: true }, { text: context }]);
		image = n.user.avatar?.medium ?? null;
		if (n.activityId !== undefined) href = `${ANILIST}/activity/${n.activityId}`;
		else if (n.thread && n.commentId !== undefined)
			href = `${ANILIST}/forum/thread/${n.thread.id}/comment/${n.commentId}`;
		else if (n.thread) href = `${ANILIST}/forum/thread/${n.thread.id}`;
		else {
			// a follow: their page, here
			href = `/user/${encodeURIComponent(n.user.name)}`;
			external = false;
		}
	} else if (n.media) {
		const title = n.media.title.userPreferred ?? 'A title';
		image = n.media.coverImage?.medium ?? null;
		imageShape = 'cover';
		href = `/title/${n.media.id}`;
		external = false;
		if (n.__typename === 'AiringNotification') {
			parts = airingParts(n, title);
		} else if (n.__typename === 'MediaMergeNotification') {
			const merged = (n.deletedMediaTitles ?? []).filter(Boolean).join(', ');
			parts = sentence([
				{ text: merged, strong: true },
				{ text: context },
				{ text: title, strong: true }
			]);
		} else {
			parts = sentence([{ text: title, strong: true }, { text: context }]);
		}
	} else if (n.__typename === 'MediaDeletionNotification' && n.deletedMediaTitle) {
		parts = sentence([{ text: n.deletedMediaTitle, strong: true }, { text: context }]);
		imageShape = 'cover';
	} else {
		return null;
	}

	return {
		...base,
		parts,
		label: parts.map((p) => p.text).join(''),
		href,
		external,
		image,
		imageShape
	};
}

/**
 * The bell's list. AniList returns newest first, so the first `unreadCount`
 * are the ones that were unread when the list was opened. AniList sometimes
 * sends the same title notification twice (the same episode of the same
 * title): only the first is kept.
 */
export function buildNotifications(
	notifications: AniListNotification[],
	{ now, unreadCount, timeZone }: { now: number; unreadCount: number; timeZone?: string }
): NotificationItem[] {
	const seen = new Set<string>();
	return notifications.flatMap((n, i) => {
		const item = adaptNotification(n, { now, unread: i < unreadCount, timeZone });
		if (!item) return [];
		// titles only: people can follow, like and reply more than once
		if (item.titleId !== null) {
			const key = `${item.titleId}:${item.label}`;
			if (seen.has(key)) return [];
			seen.add(key);
		}
		return [item];
	});
}

/** Midnight today in `timeZone`, as unix seconds. */
function startOfToday(now: number, timeZone?: string): number {
	const parts = Object.fromEntries(
		new Intl.DateTimeFormat('en-US', {
			hour: 'numeric',
			minute: 'numeric',
			second: 'numeric',
			hourCycle: 'h23',
			timeZone
		})
			.formatToParts(new Date(now * 1000))
			.map((p) => [p.type, Number(p.value)])
	) as { hour: number; minute: number; second: number };
	return now - (parts.hour * 3600 + parts.minute * 60 + parts.second);
}

/** Today, This week, Earlier: the list in sections. Empty sections are left out. */
export function groupNotifications(
	items: NotificationItem[],
	{ now, timeZone }: { now: number; timeZone?: string }
): { label: string; items: NotificationItem[] }[] {
	const midnight = startOfToday(now, timeZone);
	const weekAgo = midnight - 6 * 86400;
	const groups: { label: string; items: NotificationItem[] }[] = [
		{ label: 'Today', items: [] },
		{ label: 'This week', items: [] },
		{ label: 'Earlier', items: [] }
	];
	for (const item of items) {
		const i = item.createdAt >= midnight ? 0 : item.createdAt >= weekAgo ? 1 : 2;
		groups[i].items.push(item);
	}
	return groups.filter((g) => g.items.length);
}
