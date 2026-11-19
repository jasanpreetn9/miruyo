// The bell's list, ported from apps/web/src/lib/page-data/notifications.ts
// (adaptNotification, buildNotifications).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/providers.dart';
import '../list/list_data.dart' show relativeTime;

/// A run of the sentence; [strong] for the subject (a user or a title).
typedef NotificationPart = ({String text, bool strong});

enum ImageShape { avatar, cover }

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.parts,
    required this.when,
    required this.unread,
    this.createdAt = 0,
    this.episode,
    this.link,
    this.titleId,
    this.image,
    this.imageShape = ImageShape.avatar,
  });

  final int id;

  /// "rin started following you." in parts, so the name can be bold.
  final List<NotificationPart> parts;
  final String when;
  final bool unread;

  /// Unix seconds, for grouping by day.
  final int createdAt;

  /// The episode an airing notification is about, for its +1 swipe.
  final int? episode;

  /// AniList, for activity and forum threads; a path in miruyo (no scheme)
  /// for someone's profile.
  final Uri? link;

  /// A title page in miruyo.
  final int? titleId;

  /// The user's avatar or the title's cover.
  final String? image;
  final ImageShape imageShape;

  /// The whole sentence, for screen readers.
  String get label => parts.map((p) => p.text).join();
}

const _anilist = 'https://anilist.co';

List<NotificationPart> _sentence(List<NotificationPart> parts) => [
  for (final p in parts)
    if (p.text.isNotEmpty) p,
];

NotificationPart _plain(String? text) => (text: text ?? '', strong: false);

NotificationPart _bold(String? text) => (text: text ?? '', strong: true);

/// One AniList notification as a line in the list, or null for a type
/// miruyo doesn't show (submission updates and anything AniList adds later).
NotificationItem? adaptNotification(Json n, {required int now, required bool unread}) {
  final id = (n['id'] as num?)?.toInt();
  final createdAt = (n['createdAt'] as num?)?.toInt();
  if (id == null || createdAt == null) return null;
  final when = relativeTime(createdAt, now);
  final context = n['context'] as String? ?? '';
  final type = n['__typename'] as String?;
  final user = n['user'] as Json?;
  final media = n['media'] as Json?;

  if (user != null) {
    final name = user['name'] as String? ?? '';
    final activityId = (n['activityId'] as num?)?.toInt();
    final thread = n['thread'] as Json?;
    final commentId = (n['commentId'] as num?)?.toInt();
    final link = activityId != null
        ? '$_anilist/activity/$activityId'
        : thread != null && commentId != null
        ? '$_anilist/forum/thread/${thread['id']}/comment/$commentId'
        : thread != null
        ? '$_anilist/forum/thread/${thread['id']}'
        // a follow: their page, here
        : '/user/${Uri.encodeComponent(name)}';
    return NotificationItem(
      id: id,
      parts: _sentence([_bold(name), _plain(context)]),
      when: when,
      unread: unread,
      createdAt: createdAt,
      link: Uri.parse(link),
      image: (user['avatar'] as Json?)?['medium'] as String?,
    );
  }

  if (media != null) {
    final title = (media['title'] as Json?)?['userPreferred'] as String? ?? 'A title';
    final List<NotificationPart> parts;
    if (type == 'AiringNotification') {
      // "Episode 5 of Frieren aired.", from AniList's ["Episode ", " of ", " aired."]
      final contexts = (n['contexts'] as List?)?.cast<String?>();
      final [before, middle, after] = contexts != null && contexts.length >= 3
          ? contexts.take(3).toList()
          : <String?>['Episode ', ' of ', ' aired.'];
      parts = _sentence([_plain('${before ?? ''}${n['episode'] ?? ''}${middle ?? ''}'), _bold(title), _plain(after)]);
    } else if (type == 'MediaMergeNotification') {
      final merged = ((n['deletedMediaTitles'] as List?) ?? const []).whereType<String>().join(', ');
      parts = _sentence([_bold(merged), _plain(context), _bold(title)]);
    } else {
      parts = _sentence([_bold(title), _plain(context)]);
    }
    return NotificationItem(
      id: id,
      parts: parts,
      when: when,
      unread: unread,
      createdAt: createdAt,
      episode: type == 'AiringNotification' ? (n['episode'] as num?)?.toInt() : null,
      titleId: (media['id'] as num?)?.toInt(),
      image: (media['coverImage'] as Json?)?['medium'] as String?,
      imageShape: ImageShape.cover,
    );
  }

  final deleted = n['deletedMediaTitle'] as String?;
  if (type == 'MediaDeletionNotification' && deleted != null) {
    return NotificationItem(
      id: id,
      parts: _sentence([_bold(deleted), _plain(context)]),
      when: when,
      unread: unread,
      imageShape: ImageShape.cover,
    );
  }
  return null;
}

/// AniList returns newest first, so the first [unreadCount] are the ones
/// that were unread when the list was opened.
/// AniList sometimes sends the same notification twice (the same episode of
/// the same title): only the first is kept.
List<NotificationItem> buildNotifications(List<Json> notifications, {required int now, required int unreadCount}) {
  final seen = <String>{};
  return [
    for (final (i, n) in notifications.indexed)
      if (adaptNotification(n, now: now, unread: i < unreadCount) case final item?)
        // titles only: people can follow, like and reply more than once
        if (item.titleId == null || seen.add('${item.titleId}:${item.label}')) item,
  ];
}

/// Today, This week, Earlier: the list in sections, in the device's time
/// zone. Empty sections are left out.
List<({String label, List<NotificationItem> items})> groupNotifications(
  List<NotificationItem> items, {
  required int now,
}) {
  final today = DateTime.fromMillisecondsSinceEpoch(now * 1000);
  final midnight = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch ~/ 1000;
  final weekAgo = midnight - 6 * 86400;
  final groups = <String, List<NotificationItem>>{'Today': [], 'This week': [], 'Earlier': []};
  for (final item in items) {
    final key = item.createdAt >= midnight
        ? 'Today'
        : item.createdAt >= weekAgo
        ? 'This week'
        : 'Earlier';
    groups[key]!.add(item);
  }
  return [
    for (final MapEntry(:key, :value) in groups.entries)
      if (value.isNotEmpty) (label: key, items: value),
  ];
}

/// The list, fetched when the screen opens. Fetching marks everything read
/// on AniList, so the bell's dot clears once it's in.
final notificationsProvider = FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final unreadCount = ref.read(sessionProvider).user?.unreadNotificationCount ?? 0;
  final list = await ref.read(anilistClientProvider).fetchNotifications();
  ref.read(sessionProvider.notifier).setUnreadCount(0);
  return buildNotifications(list, now: DateTime.now().millisecondsSinceEpoch ~/ 1000, unreadCount: unreadCount);
});
