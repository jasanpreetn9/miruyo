import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/catalog/status.dart';
import '../../core/gestures/haptics.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/motion.dart';
import '../../widgets/peek.dart';
import '../../widgets/poster_row.dart';
import 'home_data.dart';

/// Upcoming (Newly serialized in manga) on a phone: compact rows with the
/// countdown once AniList schedules a premiere, and a Plan button.
class UpcomingList extends ConsumerWidget {
  const UpcomingList({super.key, required this.heading, required this.items, this.seeAll});

  final String heading;
  final List<UpcomingItem> items;
  final String? seeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(heading: heading, seeAll: seeAll),
        const SizedBox(height: Space.x2),
        for (final item in items) _UpcomingRow(item: item),
      ],
    );
  }
}

class _UpcomingRow extends ConsumerWidget {
  const _UpcomingRow({required this.item});

  final UpcomingItem item;

  // eases in as it's built: loaded in place of a skeleton, or scrolled to
  @override
  Widget build(BuildContext context, WidgetRef ref) => Appear(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final title = item.title;
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    return InkWell(
      onTap: () => context.push('/title/${title.id}'),
      // Haptic Touch: hold for the peek, as on posters
      onLongPress: () {
        unawaited(ref.read(hapticsProvider).play(Haptic.medium));
        unawaited(showPeek(context, title));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
        padding: const EdgeInsets.symmetric(vertical: Space.x2),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Surface.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 96,
              child: CoverImage(title: title, thumb: true, radius: 8, showMissing: false),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // every row the same: the season, the title, the studio, then the countdown
                children: [
                  Text(item.when, style: AppType.caption.copyWith(color: TextTone.low)),
                  const SizedBox(height: 2),
                  Semantics(
                    label: title.title,
                    excludeSemantics: true,
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (item.by.isNotEmpty)
                    Text(
                      item.by,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w400),
                    ),
                  if (item.countdown case final countdown?) ...[
                    const SizedBox(height: 4),
                    Text(
                      countdown,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: AppType.numeric.copyWith(fontSize: 11, color: Accent.sora),
                    ),
                  ],
                ],
              ),
            ),
            if (entry != null)
              SizedBox(
                height: Space.minTarget,
                child: Row(
                  children: [
                    Icon(Symbols.check_rounded, size: 16, color: statusColor[entry.status]),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel(entry.status, isAnime: title.isAnime),
                      style: AppType.caption.copyWith(color: statusColor[entry.status], fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else
              Semantics(
                button: true,
                label: 'Plan to ${title.isAnime ? 'watch' : 'read'} ${title.title}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(2),
                  onTap: () {
                    if (canEditList(context, ref)) {
                      unawaited(ref.read(listActionsProvider).changeStatus(title, MediaListStatus.planning));
                    }
                  },
                  child: Ink(
                    width: Space.minTarget,
                    height: Space.minTarget,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Surface.line),
                    ),
                    child: const Icon(Symbols.bookmark_add_rounded, size: 20, color: TextTone.high),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
