import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// A season chart entry (06, after AniChart), editorial: the cover, then when
/// it airs, the title and studio (in the cover's colour), the synopsis, genres
/// as words, the score and this season's popularity rank, ruled off from the
/// next. Titles on your list get an offset shadow behind their cover.
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
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/title/${title.id}'),
        // Haptic Touch: hold for the peek, as on posters
        onLongPress: () {
          unawaited(ref.read(hapticsProvider).play(Haptic.medium));
          unawaited(showPeek(context, title));
        },
        child: Container(
          height: 160,
          padding: const EdgeInsets.symmetric(vertical: Space.x3 + 2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Surface.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 88,
                margin: const EdgeInsets.only(right: 6, bottom: 6),
                decoration: BoxDecoration(boxShadow: entry != null ? offsetShadow(accent) : null),
                child: CoverImage(title: title, radius: Corner.sm),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: Space.x3),
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
                              style: AppType.mono(11, color: TextTone.mid),
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
                        style: AppType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25),
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
                              card.genres.take(3).join(' / '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(color: TextTone.low, fontWeight: FontWeight.w400),
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
    // a plain percentage in ink, as the web's season chart has it
    return Semantics(
      label: 'Average score $score%',
      excludeSemantics: true,
      child: Text('$score%', style: AppType.mono(12)),
    );
  }
}
