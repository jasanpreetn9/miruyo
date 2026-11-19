import 'package:flutter/material.dart' hide Title;
import 'package:go_router/go_router.dart';

import '../core/catalog/title.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'poster_card.dart';
import 'skeleton.dart';

/// A section heading with an optional subtitle and "See all →".
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.heading, this.subtitle, this.seeAll, this.seeAllPushes = false});

  final String heading;
  final String? subtitle;

  /// Where "See all" goes; no link when null.
  final String? seeAll;

  /// "See all" opens a page above the tabs (For You), so Back returns here,
  /// rather than switching tabs.
  final bool seeAllPushes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // the heading takes what it needs; the subtitle gives way first
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // a long heading ("Because you loved …") ellipsizes rather than overflow
                Flexible(
                  flex: 3,
                  child: Text(heading, style: AppType.section, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: Space.x2),
                  Flexible(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(color: TextTone.low),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (seeAll != null)
            Semantics(
              link: true,
              label: 'See all: $heading',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => seeAllPushes ? context.push(seeAll!) : context.go(seeAll!),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Space.minTarget),
                  child: Center(
                    child: Text(
                      'See all →',
                      style: AppType.body.copyWith(color: TextTone.mid, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A heading over a sideways-scrolling row of 108-wide posters, a little
/// over three to a phone screen. The row
/// scrolls natively; holding a poster opens the peek.
class PosterRow extends StatelessWidget {
  const PosterRow({
    super.key,
    required this.heading,
    required this.titles,
    this.subtitle,
    this.seeAll,
    this.countdown = false,
    this.meta = PosterMeta.standard,
    this.reasons,
    this.seeAllPushes = false,
    this.showStatus = true,
  });

  final String heading;
  final String? subtitle;
  final String? seeAll;
  final List<Title> titles;
  final bool countdown;
  final PosterMeta meta;

  /// A reason under each title, in place of its meta line (For You).
  final List<String>? reasons;
  final bool seeAllPushes;

  /// Passed to each PosterCard.
  final bool showStatus;

  static const cardWidth = 108.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(heading: heading, subtitle: subtitle, seeAll: seeAll, seeAllPushes: seeAllPushes),
        const SizedBox(height: 14),
        SizedBox(
          // a reason runs to three lines where the meta line has one
          height: _rowHeight(context, countdown: countdown, reasons: reasons != null),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            itemCount: titles.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.x3),
            itemBuilder: (context, i) => SizedBox(
              width: cardWidth,
              child: PosterCard(
                title: titles[i],
                countdown: countdown,
                meta: meta,
                reason: reasons?[i],
                showStatus: showStatus,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cover (2:3) + the status bar + gap + two title lines + meta, and the
/// chip when shown.
/// The cover, the status bar, then the text under it (two title lines, the
/// meta line, a countdown, a reason) at the reader's text size.
double _rowHeight(BuildContext context, {bool countdown = false, bool reasons = false}) {
  final text = 34 + 16 + (countdown ? 28 : 0) + (reasons ? 32 : 0);
  return PosterRow.cardWidth * 1.5 + 6 + 4 + 8 + 4 + 4 + MediaQuery.textScalerOf(context).scale(text.toDouble());
}

/// A row's skeleton, shaped like the real thing.
class PosterRowSkeleton extends StatelessWidget {
  const PosterRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Skeleton(width: 180, height: 24, radius: Corner.xs),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _rowHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: Space.x3),
            itemBuilder: (_, _) => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: PosterRow.cardWidth, height: PosterRow.cardWidth * 1.5),
                SizedBox(height: 10),
                Skeleton(width: 110, height: 14, radius: 4),
                SizedBox(height: 6),
                Skeleton(width: 80, height: 12, radius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
