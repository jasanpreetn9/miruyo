import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/anilist/types.dart';
import '../core/catalog/status.dart';
import '../core/catalog/title.dart';
import '../core/list/guard.dart';
import '../core/list/list_actions.dart';
import '../core/list/list_store.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../features/editor/list_editor.dart';
import 'cover_image.dart';

/// The peek a held poster opens (Gestures · Navigation, 13): the cover, the
/// facts and quick actions over a blurred page. Tap outside to close.
Future<void> showPeek(BuildContext context, Title title) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x9913110F),
    transitionDuration: reduceMotion ? Motion.overlay : Motion.panel,
    pageBuilder: (context, _, _) => _Peek(title: title),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.enter, reverseCurve: Motion.exit);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12 * animation.value, sigmaY: 12 * animation.value),
        child: FadeTransition(
          opacity: curved,
          child: reduceMotion
              ? child
              : ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child),
        ),
      );
    },
  );
}

class _Peek extends ConsumerWidget {
  const _Peek({required this.title});

  final Title title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    final mode = context.mode;
    final verb = title.isAnime ? 'watch' : 'read';

    void setStatus(MediaListStatus status) {
      Navigator.of(context).pop();
      if (canEditList(context, ref)) unawaited(ref.read(listActionsProvider).changeStatus(title, status));
    }

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x6),
          child: Material(
            color: Surface.s3,
            borderRadius: BorderRadius.circular(Corner.lg),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Space.x4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 104,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Corner.sm),
                            boxShadow: [
                              BoxShadow(
                                color: title.colors.glow,
                                blurRadius: 40,
                                spreadRadius: -14,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: CoverImage(title: title),
                          ),
                        ),
                        const SizedBox(width: Space.x4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppType.title),
                              const SizedBox(height: Space.x1),
                              Text(title.meta, style: AppType.caption.copyWith(color: TextTone.mid)),
                              if (title.score > 0) ...[
                                const SizedBox(height: Space.x2),
                                Row(
                                  children: [
                                    const Icon(Symbols.star_rounded, size: 16, fill: 1, color: Accent.gold),
                                    const SizedBox(width: 4),
                                    Text(title.score.toStringAsFixed(1), style: AppType.numeric),
                                  ],
                                ),
                              ],
                              const SizedBox(height: Space.x2),
                              Text(
                                title.genres.join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.caption.copyWith(color: title.colors.accent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (title.synopsis != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x3),
                      child: Text(
                        title.synopsis!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(color: TextTone.mid),
                      ),
                    ),
                  const Divider(),
                  if (entry == null)
                    _Action(
                      icon: Symbols.bookmark_add_rounded,
                      label: 'Plan to $verb',
                      color: mode.accentText,
                      onTap: () => setStatus(MediaListStatus.planning),
                    )
                  else
                    for (final s in listStatuses)
                      _Action(
                        icon: s == entry.status ? Symbols.check_rounded : Symbols.circle_rounded,
                        iconFill: s == entry.status ? 0 : 1,
                        iconSize: s == entry.status ? 20 : 10,
                        label: statusLabel(s, isAnime: title.isAnime),
                        color: statusColor[s]!,
                        selected: s == entry.status,
                        onTap: () => setStatus(s),
                      ),
                  if (entry != null)
                    _Action(
                      icon: Symbols.edit_rounded,
                      label: 'Edit entry',
                      color: TextTone.high,
                      onTap: () {
                        // the peek's context goes with it; open from the navigator's
                        final host = Navigator.of(context, rootNavigator: true).context;
                        Navigator.of(context).pop();
                        unawaited(showListEditor(host, ref, title));
                      },
                    ),
                  _Action(
                    icon: Symbols.info_rounded,
                    label: 'Open details',
                    color: TextTone.high,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/title/${title.id}');
                    },
                  ),
                  const SizedBox(height: Space.x2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.iconFill = 0,
    this.iconSize = 20,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool selected;
  final double iconFill;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: Space.minTarget + 4,
        padding: const EdgeInsets.symmetric(horizontal: Space.x4),
        color: selected ? const Color(0x0FFFFFFF) : null,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(icon, size: iconSize, fill: iconFill, color: color),
            ),
            const SizedBox(width: Space.x3),
            Text(
              label,
              style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: selected ? color : TextTone.high),
            ),
          ],
        ),
      ),
    );
  }
}
