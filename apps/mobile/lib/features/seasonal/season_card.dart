import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/catalog/status.dart';
import '../../core/gestures/haptics.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/motion.dart';
import '../../widgets/peek.dart';
import 'seasonal_data.dart';

/// A season chart card (06, after AniChart): the cover fills the card's
/// height; beside it, when it airs, the title and studio, the synopsis, genres in
/// the cover colour, the score's face and this season's popularity rank.
/// Titles on your list get a ring in the cover colour.
class SeasonCardView extends ConsumerWidget {
  const SeasonCardView({super.key, required this.card});

  final SeasonCard card;

  // eases in as it's built: loaded in place of a skeleton, or scrolled to
  @override
  Widget build(BuildContext context, WidgetRef ref) => Appear(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final title = card.title;
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    final accent = title.colors.accent;

    return Material(
      color: Surface.s1,
      borderRadius: BorderRadius.circular(Corner.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corner.md),
        onTap: () => context.push('/title/${title.id}'),
        // Haptic Touch: hold for the peek, as on posters
        onLongPress: () {
          unawaited(ref.read(hapticsProvider).play(Haptic.medium));
          unawaited(showPeek(context, title));
        },
        child: Container(
          height: 148,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Corner.md)),
          // drawn over the cover, so the ring shows all the way round
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corner.md),
            border: Border.all(
              color: entry != null ? accent.withValues(alpha: 0.7) : Surface.line,
              width: entry != null ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 98, child: CoverImage(title: title, radius: 0)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.x3, Space.x3, Space.x3, Space.x2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "Ep 3 of 12 airing in 4 days, 19 hours", on one line
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: '${card.whenLabel} '),
                                  TextSpan(
                                    text: card.when,
                                    style: const TextStyle(color: TextTone.high, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w400),
                            ),
                          ),
                          if (card.score != null) _Score(score: card.score!, face: card.face),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.25),
                      ),
                      if (card.studio.isNotEmpty)
                        Text(
                          card.studio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(color: accent),
                        ),
                      const SizedBox(height: 4),
                      // the synopsis: up to two lines, as many as fit
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final style = AppType.caption.copyWith(
                              color: TextTone.mid,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            );
                            final line = MediaQuery.textScalerOf(context).scale(12) * 1.4;
                            final lines = (box.maxHeight / line).floor().clamp(0, 2);
                            // large text: no room left, so no synopsis
                            if (lines == 0) return const SizedBox.shrink();
                            return Text(
                              title.synopsis ?? '',
                              maxLines: lines,
                              overflow: TextOverflow.ellipsis,
                              style: style,
                            );
                          },
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              card.genres.take(2).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(color: accent, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (entry != null)
                            Text(
                              statusLabel(entry.status, isAnime: title.isAnime),
                              style: AppType.caption.copyWith(
                                color: statusColor[entry.status],
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (card.popularRank != null)
                            Text(
                              '#${card.popularRank}',
                              style: AppType.numeric.copyWith(fontSize: 12, color: TextTone.mid),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.score, required this.face});

  final int score;
  final ScoreFace? face;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (face) {
      ScoreFace.good => (Symbols.sentiment_satisfied_rounded, Accent.green),
      ScoreFace.ok => (Symbols.sentiment_neutral_rounded, Accent.gold),
      _ => (Symbols.sentiment_dissatisfied_rounded, Accent.danger),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 3),
        Text('$score%', style: AppType.numeric.copyWith(fontSize: 12, color: color)),
      ],
    );
  }
}
