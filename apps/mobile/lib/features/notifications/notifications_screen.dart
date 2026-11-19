import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/title.dart';
import '../../core/gestures/row_swipe.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/list/list_store.dart';
import '../../core/notifications/episode_alerts.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import '../list/list_data.dart' show listCollectionProvider;
import 'notifications_data.dart';

/// Notifications (the bell): AniList's latest, newest first, with the ones
/// that were unread marked. Titles open in miruyo; activity, forum threads
/// and profiles open on AniList.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final list = signedIn ? ref.watch(notificationsProvider) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: AppType.title),
        backgroundColor: Surface.base,
        surfaceTintColor: Colors.transparent,
      ),
      body: switch (list) {
        null => _Message(
          icon: Symbols.notifications_rounded,
          text: 'Log in to see your AniList notifications.',
          action: ('Log in', () => context.push('/login')),
        ),
        AsyncData(:final value) when value.isEmpty => const _Message(
          icon: Symbols.notifications_off_rounded,
          text: 'Nothing yet. Airing episodes from your list, follows and replies show up here.',
        ),
        AsyncData(:final value) => RefreshIndicator.adaptive(
          onRefresh: () {
            ref.read(anilistClientProvider).clearViewerCache();
            return ref.refresh(notificationsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.x2, Space.x2, Space.x2, Space.x10),
            children: [
              const _AlertsOffer(),
              for (final group in groupNotifications(value, now: DateTime.now().millisecondsSinceEpoch ~/ 1000)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, Space.x4, 10, Space.x1),
                  child: Text(group.label.toUpperCase(), style: AppType.overline.copyWith(color: TextTone.low)),
                ),
                for (final item in group.items) ...[_Row(item: item), const SizedBox(height: 2)],
              ],
            ],
          ),
        ),
        AsyncError(:final error) => ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            SectionError(
              title: "Couldn't load notifications",
              error: error,
              onRetry: () => ref.invalidate(notificationsProvider),
            ),
          ],
        ),
        _ => ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            for (var i = 0; i < 8; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: Space.x3),
                child: Skeleton(height: 48),
              ),
          ],
        ),
      },
    );
  }
}

/// One notification. An aired episode you're up to swipes right to log it
/// (+1), as rows do everywhere.
class _Row extends ConsumerWidget {
  const _Row({required this.item});

  final NotificationItem item;

  void _open(BuildContext context) {
    if (item.titleId != null) {
      unawaited(context.push('/title/${item.titleId}'));
    } else if (item.link case final link?) {
      unawaited(link.hasScheme ? launchUrl(link, mode: LaunchMode.externalApplication) : context.push(link.toString()));
    }
  }

  /// The title an airing notification is about, when the next thing to log
  /// on your list is exactly that episode.
  Title? _loggable(WidgetRef ref) {
    final episode = item.episode, id = item.titleId;
    if (episode == null || id == null) return null;
    final entry = ref.watch(listStoreProvider)[id];
    if (entry == null || entry.progress != episode - 1) return null;
    final collection = ref.watch(listCollectionProvider(Mode.anime)).value;
    final c = collection?.entries.where((c) => c.media.id == id).firstOrNull;
    return c == null ? null : adaptMedia(c.media, titles: ref.watch(sessionProvider.select((s) => s.titles)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggable = _loggable(ref);
    final row = _row(context);
    if (loggable == null) return row;
    return RowSwipe(
      borderRadius: Corner.sm,
      positiveLabel: '+1 · EP ${item.episode}',
      onPositive: () {
        if (canEditList(context, ref)) unawaited(ref.read(listActionsProvider).plusOne(loggable));
      },
      child: row,
    );
  }

  Widget _row(BuildContext context) {
    final cover = item.imageShape == ImageShape.cover;
    final image = item.image;
    final Widget thumb = SizedBox(
      width: cover ? 34 : 40,
      height: cover ? 48 : 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cover ? 6 : 20),
        child: image != null
            ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
            : ColoredBox(
                color: Surface.s3,
                child: Center(
                  child: cover
                      ? const Icon(Symbols.image_not_supported_rounded, size: 18, color: TextTone.low)
                      : Text(
                          item.parts.firstOrNull?.text.characters.firstOrNull?.toUpperCase() ?? '',
                          style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: TextTone.mid),
                        ),
                ),
              ),
      ),
    );

    return Semantics(
      button: item.titleId != null || item.link != null,
      label: '${item.unread ? 'New: ' : ''}${item.label}, ${item.when}',
      excludeSemantics: true,
      child: Material(
        // unread: a faint wash and the dot, not a block of colour
        color: item.unread ? context.mode.accent.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(Corner.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Corner.sm),
          onTap: item.titleId != null || item.link != null ? () => _open(context) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Space.x2),
            child: Row(
              children: [
                thumb,
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            for (final p in item.parts)
                              TextSpan(
                                text: p.text,
                                style: p.strong ? const TextStyle(fontWeight: FontWeight.w600) : null,
                              ),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(color: _textColor(item)),
                      ),
                      const SizedBox(height: 2),
                      Text(item.when, style: AppType.caption.copyWith(color: TextTone.low)),
                    ],
                  ),
                ),
                if (item.unread) ...[
                  const SizedBox(width: Space.x2),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: context.mode.accent, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Read ones step back a little.
  static Color _textColor(NotificationItem item) => item.unread ? TextTone.high : const Color(0xFFD7DBE6);
}

/// Offers episode alerts on this phone, until they're turned on or declined.
class _AlertsOffer extends ConsumerStatefulWidget {
  const _AlertsOffer();

  @override
  ConsumerState<_AlertsOffer> createState() => _AlertsOfferState();
}

class _AlertsOfferState extends ConsumerState<_AlertsOffer> {
  late bool _show = ref.read(episodeAlertsProvider.notifier).undecided;

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final mode = context.mode;
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.x2, 0, Space.x2, Space.x3),
      padding: const EdgeInsets.fromLTRB(Space.x4, Space.x3, Space.x2, Space.x2),
      decoration: BoxDecoration(
        color: mode.tint,
        borderRadius: BorderRadius.circular(Corner.md),
        border: Border.all(color: mode.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.notifications_active_rounded, size: 20, color: mode.accentText),
              const SizedBox(width: Space.x2),
              Text('Get alerts on this phone', style: AppType.title.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'A notification when a new episode of something you’re watching comes out, even with miruyo closed.',
            style: AppType.body.copyWith(color: TextTone.mid),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  await ref.read(episodeAlertsProvider.notifier).disable();
                  setState(() => _show = false);
                },
                style: TextButton.styleFrom(foregroundColor: TextTone.mid),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(episodeAlertsProvider.notifier).enable();
                  if (mounted) setState(() => _show = false);
                },
                style: TextButton.styleFrom(foregroundColor: mode.accentText),
                child: const Text('Turn on'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: TextTone.low),
            const SizedBox(height: Space.x3),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: TextTone.mid),
            ),
            if (action case (final label, final onTap)) ...[
              const SizedBox(height: Space.x4),
              FilledButton(onPressed: onTap, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
