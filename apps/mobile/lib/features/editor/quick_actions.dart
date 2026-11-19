import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/catalog/status.dart';
import '../../core/catalog/title.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/list/list_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/cover_image.dart';
import 'list_editor.dart';

/// Quick actions for one title (Gestures · Rows 11): −1, +1 and Edit, then
/// the statuses, Open details and Remove. Opened by a long swipe left or a
/// hold on any row.
Future<void> showQuickActions(BuildContext context, WidgetRef ref, Title title) async {
  if (!canEditList(context, ref)) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Surface.s2,
    barrierColor: const Color(0x99090B11),
    builder: (_) => _QuickActions(title: title, host: context),
  );
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.title, required this.host});

  final Title title;

  /// The page that opened the sheet, for what opens after it closes.
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    final actions = ref.read(listActionsProvider);
    final total = title.total;
    final progress = entry?.progress ?? 0;

    void close() => Navigator.of(context).pop();

    Widget square(IconData icon, String label, VoidCallback? onTap, {bool primary = false}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: primary ? TextTone.high : Surface.s3,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Opacity(
              opacity: onTap == null ? 0.35 : 1,
              child: SizedBox(
                height: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 22, color: primary ? Surface.s1 : TextTone.high),
                    const SizedBox(height: 4),
                    Text(label, style: AppType.caption.copyWith(color: primary ? Surface.s1 : TextTone.high)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(width: 40, height: 60, child: CoverImage(title: title, thumb: true, radius: 6)),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.title.copyWith(fontSize: 16),
                      ),
                      Text(
                        entry == null
                            ? 'Not on your list'
                            : '${statusLabel(entry.status, isAnime: title.isAnime)} · ${title.unit} $progress / ${total ?? '?'}',
                        style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Row(
              children: [
                square(
                  Symbols.remove_rounded,
                  '−1',
                  entry != null && progress > 0
                      ? () {
                          close();
                          unawaited(actions.minusOne(title));
                        }
                      : null,
                ),
                square(
                  Symbols.add_rounded,
                  '+1',
                  total == null || progress < total
                      ? () {
                          close();
                          unawaited(actions.plusOne(title));
                        }
                      : null,
                  primary: true,
                ),
                square(Symbols.edit_rounded, 'Edit', () {
                  close();
                  unawaited(showListEditor(host, ref, title));
                }),
              ],
            ),
            const SizedBox(height: Space.x4),
            Text('STATUS', style: AppType.overline.copyWith(color: TextTone.mid)),
            const SizedBox(height: Space.x2),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final s in listStatuses)
                  ChoiceChip(
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor[s], shape: BoxShape.circle),
                    ),
                    label: Text(statusLabel(s, isAnime: title.isAnime)),
                    selected: entry?.status == s,
                    showCheckmark: false,
                    selectedColor: statusColor[s]!.withValues(alpha: 0.18),
                    backgroundColor: Surface.s1,
                    side: BorderSide(color: entry?.status == s ? statusColor[s]! : Surface.line),
                    labelStyle: AppType.body.copyWith(fontSize: 13),
                    shape: const StadiumBorder(),
                    onSelected: (_) {
                      close();
                      unawaited(actions.changeStatus(title, s));
                    },
                  ),
              ],
            ),
            const SizedBox(height: Space.x3),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Symbols.info_rounded, color: TextTone.high),
              title: Text('Open details', style: AppType.body),
              trailing: const Icon(Symbols.chevron_right_rounded, color: TextTone.low),
              onTap: () {
                close();
                unawaited(host.push('/title/${title.id}'));
              },
            ),
            if (entry?.status == MediaListStatus.planning)
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: actions.topPriorityFor(title) != null,
                leading: const Icon(Symbols.vertical_align_top_rounded, color: TextTone.high),
                title: Text('Move to top of Up next', style: AppType.body),
                onTap: () {
                  close();
                  unawaited(actions.moveToTop(title));
                },
              ),
            if (entry != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Symbols.delete_rounded, color: Accent.danger),
                title: Text('Remove from list', style: AppType.body.copyWith(color: Accent.danger)),
                onTap: () {
                  close();
                  // Undo stays up for 5s in the toast
                  unawaited(actions.removeFromList(title));
                },
              ),
          ],
        ),
      ),
    );
  }
}
