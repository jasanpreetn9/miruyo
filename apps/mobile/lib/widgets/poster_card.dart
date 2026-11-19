import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/anilist/types.dart';
import '../core/auth/session.dart';
import '../core/catalog/status.dart';
import '../core/catalog/title.dart';
import '../core/gestures/haptics.dart';
import '../core/list/list_store.dart';
import '../core/providers.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'countdown_chip.dart';
import 'cover_image.dart';
import 'motion.dart';
import 'peek.dart';

/// What the line under a card's title shows.
enum PosterMeta {
  standard,
  season,

  /// For a grid where every card shares a format (manga New releases).
  genres,
}

/// The core component (07): a 2:3 cover with the art kept clean (no format
/// or score badges, as on the web) and the metadata below. Titles on your
/// list carry a status pill, +1 and a cover-coloured progress line. Tap opens the title; hold (450ms) dips the poster to 96%
/// and opens the peek.
class PosterCard extends ConsumerStatefulWidget {
  const PosterCard({
    super.key,
    required this.title,
    this.countdown = false,
    this.meta = PosterMeta.standard,
    this.reason,
    this.onHold,
    this.showStatus = true,
  });

  final Title title;

  /// Show the next-episode countdown under the title.
  final bool countdown;
  final PosterMeta meta;

  /// Why it's here ("Because you rated Frieren 9/10"), in place of the meta
  /// line: For You's picks.
  final String? reason;

  /// What a hold opens instead of the peek (For You: Why this pick).
  final VoidCallback? onHold;

  /// Name your status under the title. Off where it goes without saying
  /// (favourites are all finished), so the score and format show instead.
  final bool showStatus;

  @override
  ConsumerState<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends ConsumerState<PosterCard> {
  bool _pressed = false;
  bool _revealed = false;
  Timer? _hold;
  Offset? _downAt;

  Title get title => widget.title;

  void _down(PointerDownEvent e) {
    _hold?.cancel();
    _downAt = e.position;
    setState(() => _pressed = true);
    _hold = Timer(GestureSpec.hold, _peek);
  }

  void _cancel([Object? _]) {
    _hold?.cancel();
    if (_pressed) setState(() => _pressed = false);
  }

  Future<void> _peek() async {
    if (!mounted) return;
    setState(() => _pressed = false);
    unawaited(ref.read(hapticsProvider).play(Haptic.medium));
    if (widget.onHold != null) return widget.onHold!();
    await showPeek(context, title);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  // eases in as it's built: loaded in place of a skeleton, or scrolled to
  @override
  Widget build(BuildContext context) => Appear(child: _build(context));

  Widget _build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    final hidden = title.adult && !session.showAdultContent && !_revealed;
    final inProgress = entry != null && isInProgress(entry.status);
    final total = title.total;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final metaText = hidden
        ? 'Enable 18+ in your AniList settings'
        : widget.meta == PosterMeta.season
        ? [title.knownFormat, title.season].whereType<String>().join(' · ')
        : widget.meta == PosterMeta.genres
        ? title.genres.take(2).join(' · ')
        : [title.knownFormat, title.knownCount].whereType<String>().join(' · ');

    return Semantics(
      button: true,
      label: hidden ? 'Hidden 18+ title' : title.title,
      onLongPressHint: 'Peek',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/title/${title.id}'),
        child: Listener(
          onPointerDown: _down,
          onPointerUp: _cancel,
          onPointerCancel: _cancel,
          // moving more than the slop first (a scroll) cancels the hold
          onPointerMove: (e) {
            if (_downAt != null && (e.position - _downAt!).distance > GestureSpec.holdSlop) _cancel();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                scale: _pressed && !reduceMotion ? GestureSpec.peekScale : 1,
                duration: GestureSpec.hold,
                curve: Curves.easeOut,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverImage(title: title),
                      if (hidden) HiddenCover(onReveal: () => setState(() => _revealed = true)),
                    ],
                  ),
                ),
              ),
              // the status, as a bar in its colour filled to your progress;
              // nothing sits on the cover itself
              const SizedBox(height: 6),
              StatusBar(status: entry?.status, progress: entry?.progress ?? 0, total: total, hidden: hidden),
              const SizedBox(height: 8),
              // up to two lines, with what's under it right below (as on the
              // web): a one-line title leaves no gap; the card's room is kept
              // at the bottom instead
              Text(
                hidden ? 'Hidden title' : title.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
              ),
              if (widget.countdown && title.next != null && !hidden) ...[
                const SizedBox(height: 4),
                CountdownChip(next: title.next!, compact: true),
              ],
              const SizedBox(height: 4),
              // on your list the status is named here too, never by colour alone
              if (widget.reason != null && !hidden)
                Text(
                  widget.reason!,
                  // "Because you rated <title> 9/10" keeps its score on a narrow card
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w400, height: 1.3),
                )
              else if (entry != null && !hidden && widget.showStatus)
                Text(
                  inProgress
                      ? '${statusLabel(entry.status, isAnime: title.isAnime)} · ${entry.progress}/${total ?? '?'}'
                      : statusLabel(entry.status, isAnime: title.isAnime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(color: statusColor[entry.status], fontWeight: FontWeight.w600),
                )
              else
                Text.rich(
                  TextSpan(
                    children: [
                      if (title.score > 0 && !hidden) ...[
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Symbols.star_rounded, size: 12, fill: 1, color: Accent.gold),
                        ),
                        TextSpan(text: ' ${title.score.toStringAsFixed(1)}  '),
                      ],
                      TextSpan(text: metaText),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(color: TextTone.low, fontWeight: FontWeight.w400),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An 18+ cover while the setting is off: blurred, with Reveal.
class HiddenCover extends StatelessWidget {
  const HiddenCover({super.key, required this.onReveal});

  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Corner.sm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: const Color(0x7313110F),
          padding: const EdgeInsets.all(Space.x3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.visibility_off_rounded, size: 28, color: TextTone.high),
              const SizedBox(height: Space.x2),
              Text('18+ · Hidden', style: AppType.caption.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: Space.x2),
              OutlinedButton(
                onPressed: onReveal,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  foregroundColor: TextTone.high,
                  backgroundColor: const Color(0x9913110F),
                  side: const BorderSide(color: Color(0x33FFFFFF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  textStyle: AppType.caption.copyWith(fontWeight: FontWeight.w600),
                ),
                child: const Text('Reveal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status under a poster: a bar in the status colour, filled to your
/// progress while it moves (a finished or planned title fills it). Off the
/// list, or hidden, it keeps its space but stays empty, so cards line up.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.status, required this.progress, required this.total, this.hidden = false});

  /// Null when the title isn't on your list.
  final MediaListStatus? status;
  final int progress;
  final int? total;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null || hidden) return const SizedBox(height: 4);
    final color = statusColor[s]!;
    final t = total;
    // progress fills the bar while it moves; an unknown total, or any other
    // status, is the whole bar
    final share = isInProgress(s) && t != null && t > 0 ? (progress / t).clamp(0.0, 1.0) : 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Corner.full),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color.withValues(alpha: 0.25)),
            EasedFractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: share,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
