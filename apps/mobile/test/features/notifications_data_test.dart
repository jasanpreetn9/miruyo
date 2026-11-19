import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/features/notifications/notifications_data.dart';

// Ported from apps/web/src/lib/page-data/notifications.test.ts.

const now = 1800000000;
const rin = {
  'id': 7,
  'name': 'rin',
  'avatar': {'medium': 'rin.png'},
};
const frieren = {
  'id': 154587,
  'type': 'ANIME',
  'title': {'userPreferred': 'Frieren'},
  'coverImage': {'medium': 'frieren.jpg'},
};

void main() {
  test('reads an airing notification as a sentence and links to the title', () {
    final item = adaptNotification(
      {
        '__typename': 'AiringNotification',
        'id': 1,
        'createdAt': now - 2 * 3600,
        'episode': 5,
        'contexts': ['Episode ', ' of ', ' aired.'],
        'media': frieren,
      },
      now: now,
      unread: false,
    )!;
    expect(item.label, 'Episode 5 of Frieren aired.');
    expect(item.parts, [
      (text: 'Episode 5 of ', strong: false),
      (text: 'Frieren', strong: true),
      (text: ' aired.', strong: false),
    ]);
    expect(
      (item.titleId, item.link, item.image, item.imageShape, item.when),
      (154587, null, 'frieren.jpg', ImageShape.cover, '2h ago'),
    );
  });

  test('falls back to its own wording when AniList sends no contexts', () {
    final item = adaptNotification(
      {
        '__typename': 'AiringNotification',
        'id': 1,
        'createdAt': now,
        'episode': 12,
        'contexts': null,
        'media': frieren,
      },
      now: now,
      unread: false,
    );
    expect(item?.label, 'Episode 12 of Frieren aired.');
  });

  test('links people, activity and forum notifications to AniList', () {
    final follow = adaptNotification(
      {
        '__typename': 'FollowingNotification',
        'id': 2,
        'createdAt': now,
        'context': ' started following you.',
        'user': rin,
      },
      now: now,
      unread: false,
    )!;
    expect(follow.label, 'rin started following you.');
    expect(follow.parts.first, (text: 'rin', strong: true));
    expect((follow.link.toString(), follow.image, follow.imageShape), ('/user/rin', 'rin.png', ImageShape.avatar));

    final like = adaptNotification(
      {
        '__typename': 'ActivityLikeNotification',
        'id': 3,
        'createdAt': now,
        'context': ' liked your activity.',
        'activityId': 99,
        'user': rin,
      },
      now: now,
      unread: false,
    );
    expect(like?.link.toString(), 'https://anilist.co/activity/99');

    final reply = adaptNotification(
      {
        '__typename': 'ThreadCommentReplyNotification',
        'id': 4,
        'createdAt': now,
        'context': ' replied to your comment, in the forum thread ',
        'commentId': 55,
        'thread': {'id': 12, 'title': 'Fall 2026'},
        'user': rin,
      },
      now: now,
      unread: false,
    );
    expect(reply?.link.toString(), 'https://anilist.co/forum/thread/12/comment/55');
  });

  test('names both sides of a merge', () {
    final item = adaptNotification(
      {
        '__typename': 'MediaMergeNotification',
        'id': 5,
        'createdAt': now,
        'context': ' were merged into ',
        'deletedMediaTitles': ['Sousou no Frieren (TV)'],
        'media': frieren,
      },
      now: now,
      unread: false,
    );
    expect(item?.label, 'Sousou no Frieren (TV) were merged into Frieren');
  });

  test('skips types it does not show, and marks the first unreadCount as unread', () {
    expect(
      adaptNotification({'__typename': 'MediaSubmissionUpdate', 'id': 9, 'createdAt': now}, now: now, unread: false),
      isNull,
    );
    final items = buildNotifications(
      [
        {'__typename': 'FollowingNotification', 'id': 1, 'createdAt': now, 'context': ' followed you.', 'user': rin},
        {'__typename': 'Unknown', 'id': 2, 'createdAt': now},
        {'__typename': 'FollowingNotification', 'id': 3, 'createdAt': now, 'context': ' followed you.', 'user': rin},
      ],
      now: now,
      unreadCount: 1,
    );
    expect(items.map((i) => (i.id, i.unread)), [(1, true), (3, false)]);
  });

  test('drops a notification AniList sent twice, and groups by day', () {
    Json airing(int id, int at, int ep) => {
      '__typename': 'AiringNotification',
      'id': id,
      'createdAt': at,
      'episode': ep,
      'contexts': ['Episode ', ' of ', ' aired.'],
      'media': frieren,
    };
    final items = buildNotifications(
      [
        airing(1, now - 60, 6),
        airing(2, now - 3 * 86400, 5),
        airing(3, now - 3 * 86400, 5),
        airing(4, now - 30 * 86400, 1),
      ],
      now: now,
      unreadCount: 0,
    );
    expect(items.map((i) => i.id), [1, 2, 4]);
    expect(items.first.episode, 6);
    final groups = groupNotifications(items, now: now);
    expect(groups.map((g) => (g.label, g.items.length)), [('Today', 1), ('This week', 1), ('Earlier', 1)]);
  });
}
