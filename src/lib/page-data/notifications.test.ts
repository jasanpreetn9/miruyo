import { describe, expect, it } from 'vitest';
import type { AniListNotification } from '#lib/anilist/types.ts';
import { adaptNotification, buildNotifications, groupNotifications } from './notifications.ts';

const NOW = 1_800_000_000;
const opts = { now: NOW, unread: false };

const rin = { id: 7, name: 'rin', avatar: { medium: 'rin.png' } };
const frieren = {
	id: 154587,
	type: 'ANIME' as const,
	title: { userPreferred: 'Frieren' },
	coverImage: { medium: 'frieren.jpg' }
};

describe('adaptNotification', () => {
	it('reads an airing notification as a sentence and links to the title', () => {
		const item = adaptNotification(
			{
				__typename: 'AiringNotification',
				id: 1,
				createdAt: NOW - 2 * 3600,
				episode: 5,
				contexts: ['Episode ', ' of ', ' aired.'],
				media: frieren
			},
			opts
		);
		expect(item).toMatchObject({
			label: 'Episode 5 of Frieren aired.',
			parts: [{ text: 'Episode 5 of ' }, { text: 'Frieren', strong: true }, { text: ' aired.' }],
			href: '/title/154587',
			external: false,
			image: 'frieren.jpg',
			imageShape: 'cover',
			when: '2h ago'
		});
	});

	it('falls back to its own wording when AniList sends no contexts', () => {
		const n: AniListNotification = {
			__typename: 'AiringNotification',
			id: 1,
			createdAt: NOW,
			episode: 12,
			contexts: null,
			media: frieren
		};
		expect(adaptNotification(n, opts)?.label).toBe('Episode 12 of Frieren aired.');
	});

	it('links people, activity and forum notifications to AniList', () => {
		const follow = adaptNotification(
			{
				__typename: 'FollowingNotification',
				id: 2,
				createdAt: NOW,
				context: ' started following you.',
				user: rin
			},
			opts
		);
		expect(follow).toMatchObject({
			label: 'rin started following you.',
			parts: [{ text: 'rin', strong: true }, { text: ' started following you.' }],
			href: '/user/rin',
			external: false,
			image: 'rin.png',
			imageShape: 'avatar'
		});

		const like = adaptNotification(
			{
				__typename: 'ActivityLikeNotification',
				id: 3,
				createdAt: NOW,
				context: ' liked your activity.',
				activityId: 99,
				user: rin
			},
			opts
		);
		expect(like?.href).toBe('https://anilist.co/activity/99');

		const reply = adaptNotification(
			{
				__typename: 'ThreadCommentReplyNotification',
				id: 4,
				createdAt: NOW,
				context: ' replied to your comment, in the forum thread ',
				commentId: 55,
				thread: { id: 12, title: 'Fall 2026' },
				user: rin
			},
			opts
		);
		expect(reply?.href).toBe('https://anilist.co/forum/thread/12/comment/55');
	});

	it('names both sides of a merge', () => {
		const item = adaptNotification(
			{
				__typename: 'MediaMergeNotification',
				id: 5,
				createdAt: NOW,
				context: ' were merged into ',
				deletedMediaTitles: ['Sousou no Frieren (TV)'],
				media: frieren
			},
			opts
		);
		expect(item?.label).toBe('Sousou no Frieren (TV) were merged into Frieren');
	});

	it('shows a deletion without a link', () => {
		const item = adaptNotification(
			{
				__typename: 'MediaDeletionNotification',
				id: 6,
				createdAt: NOW,
				context: ' was deleted from the site.',
				deletedMediaTitle: 'Old Title'
			},
			opts
		);
		expect(item).toMatchObject({ label: 'Old Title was deleted from the site.', href: null });
	});

	it('skips types it has no fields for', () => {
		expect(adaptNotification({ __typename: 'MediaSubmissionUpdateNotification' }, opts)).toBeNull();
	});
});

describe('buildNotifications', () => {
	it('marks the newest `unreadCount` as unread and drops unknown types', () => {
		const list: AniListNotification[] = [
			{
				__typename: 'FollowingNotification',
				id: 1,
				createdAt: NOW,
				context: ' started following you.',
				user: rin
			},
			{ __typename: 'MediaSubmissionUpdateNotification' },
			{
				__typename: 'FollowingNotification',
				id: 2,
				createdAt: NOW,
				context: ' started following you.',
				user: rin
			}
		];
		const items = buildNotifications(list, { now: NOW, unreadCount: 2 });
		expect(items.map((i) => [i.id, i.unread])).toEqual([
			[1, true],
			[2, false]
		]);
	});
});

describe('the same title notification twice', () => {
	it('keeps only the first', () => {
		const aired = (id: number): AniListNotification => ({
			__typename: 'AiringNotification',
			id,
			createdAt: NOW - id,
			episode: 5,
			contexts: ['Episode ', ' of ', ' aired.'],
			media: frieren
		});
		const items = buildNotifications([aired(1), aired(2)], { now: NOW, unreadCount: 0 });
		expect(items.map((i) => i.id)).toEqual([1]);
	});

	it('keeps repeats from people', () => {
		const follow = (id: number): AniListNotification => ({
			__typename: 'FollowingNotification',
			id,
			createdAt: NOW - id,
			context: ' started following you.',
			user: rin
		});
		const items = buildNotifications([follow(1), follow(2)], { now: NOW, unreadCount: 0 });
		expect(items).toHaveLength(2);
	});
});

describe('groupNotifications', () => {
	it('sorts into Today, This week and Earlier, leaving out empty ones', () => {
		// noon UTC
		const noon = Date.UTC(2026, 9, 14, 12) / 1000;
		const at = (id: number, createdAt: number) => ({
			id,
			createdAt,
			parts: [],
			label: '',
			href: null,
			external: false,
			image: null,
			imageShape: 'avatar' as const,
			when: '',
			unread: false,
			titleId: null
		});
		const groups = groupNotifications(
			[at(1, noon - 3600), at(2, noon - 2 * 86400), at(3, noon - 30 * 86400)],
			{ now: noon, timeZone: 'UTC' }
		);
		expect(groups.map((g) => [g.label, g.items.map((i) => i.id)])).toEqual([
			['Today', [1]],
			['This week', [2]],
			['Earlier', [3]]
		]);
		expect(
			groupNotifications([at(1, noon - 30 * 86400)], { now: noon, timeZone: 'UTC' }).map(
				(g) => g.label
			)
		).toEqual(['Earlier']);
	});
});
