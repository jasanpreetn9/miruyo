import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' hide Title;
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
import '../editor/list_editor.dart';
import 'home_list.dart';

/// Picked for you (01, Gestures · Home 14): what to watch next, each with
/// its reason ("Because you rated Cowboy Bebop 9.5/10"), as landscape cards
/// with Plan and Not this. It never moves on its own, so a title doesn't
/// slide away while you reach for Plan. Swipe to page, or tap a dot.
/// Tracking is Continue's, above it.
class HeroCarousel extends ConsumerStatefulWidget {
  const HeroCarousel({super.key, required this.slides, required this.onDismiss});

  final List<HeroPick> slides;

  /// Not this, on a For You pick.
  final ValueChanged<HeroPick> onDismiss;

  /// The card's height: the cover, or the text beside it at the reader's
  /// text size, whichever is taller. The lines are measured in the card's own
  /// styles, so the buttons fit to the point.
  static double cardHeight(BuildContext context) {
    final t = MediaQuery.textScalerOf(context);
    double lines(TextStyle style, int count) {
      final painter = TextPainter(
        text: TextSpan(text: List.filled(count, 'Ag').join('\n'), style: style),
        textScaler: t,
        textDirection: TextDirection.ltr,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final text =
        lines(_HeroCard.reasonStyle, 2) +
        6 +
        lines(_HeroCard.titleStyle, 2) +
        4 +
        lines(_HeroCard.metaStyle, 1) +
        Space.x3 +
        44;
    return 2 * Space.x4 + math.max(_HeroCard.cover.h, text).ceilToDouble();
  }

  @override
  ConsumerState<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<HeroCarousel> {
  final _pages = PageController();
  int _index = 0;

  int get _count => widget.slides.length.clamp(0, heroSlides);

  @override
  void didUpdateWidget(HeroCarousel old) {
    super.didUpdateWidget(old);
    // a pick hidden or planned elsewhere leaves; stay in range
    if (_index >= _count && _count > 0) {
      _index = _count - 1;
      if (_pages.hasClients) _pages.jumpToPage(_index);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (!_pages.hasClients) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    unawaited(
      _pages.animateToPage(
        index,
        duration: reduce ? const Duration(milliseconds: 1) : Motion.sheet,
        curve: Motion.enter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final card = HeroCarousel.cardHeight(context);

    return Semantics(
      container: true,
      label: 'Picked for you',
      child: Column(
        children: [
          SizedBox(
            height: card + Space.x3,
            child: PageView.builder(
              controller: _pages,
              // the glow spills past the card and fades out; nothing cuts it off
              clipBehavior: Clip.none,
              itemCount: _count,
              onPageChanged: (i) {
                setState(() => _index = i);
                unawaited(ref.read(hapticsProvider).play(Haptic.selection));
              },
              // the ends rubber-band
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, i) {
                final slide = widget.slides[i];
                return Padding(
                  // 16px in, so a touch in the 20px edge strip still goes to OS back
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
                  child: _HeroCard(
                    key: ValueKey(slide.title.id),
                    slide: slide,
                    onDismiss: slide.pick ? () => widget.onDismiss(slide) : null,
                  ),
                );
              },
            ),
          ),
          if (_count > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _count; i++)
                  Semantics(
                    button: true,
                    label: 'Show ${widget.slides[i].title.title} (${i + 1} of $_count)',
                    selected: i == _index,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _goTo(i),
                      // 4px dots, each in a 44px target
                      child: SizedBox(
                        height: Space.minTarget,
                        width: Space.minTarget * 0.75,
                        child: Center(
                          child: AnimatedContainer(
                            duration: Motion.overlay,
                            width: i == _index ? 28 : 12,
                            height: 4,
                            decoration: BoxDecoration(
                              color: i == _index ? TextTone.high : const Color(0x40FFFFFF),
                              borderRadius: BorderRadius.circular(Corner.full),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          else
            const SizedBox(height: Space.x4),
        ],
      ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({super.key, required this.slide, this.onDismiss});

  final HeroPick slide;

  /// Not this (For You picks only): hides it here and on For You.
  final VoidCallback? onDismiss;

  static const cover = (w: 96.0, h: 144.0);

  /// The reason's coral, as on the web.
  static const _reason = Color(0xFFFFB3A6);

  static final reasonStyle = AppType.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: _reason);
  static final titleStyle = AppType.heading.copyWith(fontSize: 22, height: 1.1);
  static final metaStyle = AppType.body.copyWith(fontSize: 13, color: const Color(0xFFC4C9D6));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = slide.title;
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    final mode = context.mode;
    final isAnime = title.isAnime;
    final count = isAnime
        ? (title.eps != null && title.eps! > 0 ? '${title.eps} episodes' : 'Airing')
        : (title.total != null && title.total! > 0 ? '${title.total} ch' : 'Ongoing');
    final meta = [title.knownFormat, count].whereType<String>().join(' · ');

    // the main action: Plan, or where it is once it's on your list (opens the editor)
    final Widget primary = entry == null
        ? FilledButton.icon(
            onPressed: () {
              if (canEditList(context, ref)) {
                unawaited(ref.read(listActionsProvider).changeStatus(title, MediaListStatus.planning));
              }
            },
            style: _buttonStyle(mode.accent, mode.onAccent),
            icon: const Icon(Symbols.bookmark_add_rounded, size: 20),
            label: Text('Plan to ${isAnime ? 'watch' : 'read'}', maxLines: 1, overflow: TextOverflow.ellipsis),
          )
        : FilledButton.icon(
            onPressed: () => unawaited(showListEditor(context, ref, title)),
            style: _buttonStyle(Quiet.fill, TextTone.high, border: Quiet.border),
            icon: const Icon(Symbols.check_rounded, size: 20),
            label: Text(statusLabel(entry.status, isAnime: isAnime), maxLines: 1, overflow: TextOverflow.ellipsis),
          );

    return GestureDetector(
      onTap: () => context.push('/title/${title.id}'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: title.colors.glow, blurRadius: 40, spreadRadius: -16, offset: const Offset(0, 16)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // the cover, blurred and enlarged, behind everything
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Transform.scale(scale: 1.3, child: CoverImage(title: title, radius: 0, showMissing: false)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xF5090B11), Color(0xB8090B11)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: cover.w,
                    height: cover.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Corner.sm),
                      boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 12))],
                    ),
                    child: CoverImage(title: title),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(slide.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: reasonStyle),
                        const SizedBox(height: 6),
                        Text(title.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              if (title.score > 0) ...[
                                const WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Icon(Symbols.star_rounded, size: 14, fill: 1, color: Accent.gold),
                                ),
                                TextSpan(text: ' ${title.score.toStringAsFixed(1)} · '),
                              ],
                              TextSpan(text: meta),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metaStyle,
                        ),
                        const Spacer(),
                        const SizedBox(height: Space.x3),
                        Row(
                          children: [
                            Expanded(child: SizedBox(height: 44, child: primary)),
                            if (onDismiss != null) ...[
                              const SizedBox(width: Space.x2),
                              SizedBox.square(
                                dimension: 44,
                                child: IconButton(
                                  onPressed: onDismiss,
                                  tooltip: 'Not this: hide ${title.title}',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Quiet.fill,
                                    foregroundColor: TextTone.high,
                                    side: const BorderSide(color: Quiet.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Symbols.block_rounded, size: 20),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color bg, Color fg, {Color? border}) => FilledButton.styleFrom(
    backgroundColor: bg,
    foregroundColor: fg,
    padding: const EdgeInsets.symmetric(horizontal: Space.x3),
    side: border == null ? null : BorderSide(color: border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
  );
}
