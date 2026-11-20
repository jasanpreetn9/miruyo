import 'package:flutter/material.dart' hide Title;
import 'package:go_router/go_router.dart';

import '../core/catalog/title.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'poster_card.dart';
import 'skeleton.dart';

/// A section heading, editorial: a serif title (with an
/// optional italic part, "Because you loved *Frieren*"), a Japanese gloss and
/// a note, then a hairline out to "See all →" or a [trailing] control.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.heading,
    this.em,
    this.jp,
    this.subtitle,
    this.subtitleColor = TextTone.low,
    this.seeAll,
    this.seeAllPushes = false,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: Space.gutter),
    this.background = Surface.base,
  });

  final String heading;

  /// Set in italics after [heading].
  final String? em;

  /// A small Japanese gloss beside the title (視聴中).
  final String? jp;
  final String? subtitle;
  final Color subtitleColor;

  /// Where "See all" goes; no link when null.
  final String? seeAll;

  /// "See all" opens a page above the tabs (For You), so Back returns here,
  /// rather than switching tabs.
  final bool seeAllPushes;

  /// Replaces "See all" (a sort control, "My List →").
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// What the heading sits on, so its words mask the hairline behind them.
  final Color background;

  @override
  Widget build(BuildContext context) {
    final full = em == null ? heading : '$heading $em';
    final link =
        trailing ??
        (seeAll == null
            ? null
            : Semantics(
                link: true,
                label: 'See all: $full',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => seeAllPushes ? context.push(seeAll!) : context.go(seeAll!),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Space.minTarget),
                    child: Center(
                      child: Text(
                        'See all →',
                        style: AppType.body.copyWith(color: TextTone.mid, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ));
    // the hairline runs the full width behind; the words and the link sit on
    // the page's colour over it, so it shows only between them. The words
    // give way (ellipsize) before the link does.
    return Padding(
      padding: padding,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          const Positioned.fill(child: Hairline()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: ColoredBox(
                  color: background,
                  child: Padding(
                    padding: const EdgeInsets.only(right: Space.x3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          flex: 3,
                          child: Text.rich(
                            TextSpan(
                              text: heading,
                              children: [
                                if (em != null)
                                  TextSpan(
                                    text: ' $em',
                                    style: AppType.section.copyWith(fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                            semanticsLabel: full,
                            style: AppType.section,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (jp != null) ...[const SizedBox(width: Space.x2), Text(jp!, style: AppType.jp, maxLines: 1)],
                        if (subtitle != null) ...[
                          const SizedBox(width: Space.x2),
                          Flexible(
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(color: subtitleColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (link != null)
                ColoredBox(
                  color: background,
                  child: Padding(
                    padding: const EdgeInsets.only(left: Space.x3),
                    child: link,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A section's hairline. It draws out from the left the first time it's
/// built (Motion.panel), and is simply there under reduced motion.
class Hairline extends StatefulWidget {
  const Hairline({super.key, this.color = Surface.line, this.thickness = 1});

  final Color color;
  final double thickness;

  @override
  State<Hairline> createState() => _HairlineState();
}

class _HairlineState extends State<Hairline> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(widthFactor: Motion.enter.transform(_c.value), heightFactor: null, child: child),
      ),
      child: Container(height: widget.thickness, color: widget.color),
    ),
  );
}

/// A heading over a sideways-scrolling row of 108-wide posters, a little
/// over three to a phone screen. The row
/// scrolls natively; holding a poster opens the peek.
class PosterRow extends StatelessWidget {
  const PosterRow({
    super.key,
    required this.heading,
    this.em,
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

  /// Set in italics after [heading] (the title it's because of).
  final String? em;
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
        SectionHeading(heading: heading, em: em, subtitle: subtitle, seeAll: seeAll, seeAllPushes: seeAllPushes),
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
