import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/gestures/haptics.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// The Anime/Manga toggle (Gestures · Navigation, 13). Mode changes only
/// here: tap either side, or drag the thumb. The thumb follows the finger,
/// takes the accent of the nearer side as it passes halfway (with a
/// Selection haptic), and snaps on release. Landing is silent. On phones
/// only the active side shows its label.
class ModeToggle extends ConsumerStatefulWidget {
  const ModeToggle({super.key, this.showInactiveLabel = false});

  /// Tablets and the onboarding step show both labels.
  final bool showInactiveLabel;

  @override
  ConsumerState<ModeToggle> createState() => _ModeToggleState();
}

class _ModeToggleState extends ConsumerState<ModeToggle> {
  /// 0 = Anime, 1 = Manga, while dragging; null at rest.
  double? _drag;

  /// The thumb's height, as designed; each side's tap target is 44pt tall
  /// (Apple's minimum), reaching past the 40pt track.
  static const _height = 32.0;
  static const _pad = 3.0;
  static const _target = 44.0;
  static const _iconOnly = 44.0;

  TextStyle get _label => AppType.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600);

  double _labelled(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _label),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    // +1 so a font that loads after this measure can't nudge it over
    return 10 + 16 + 4 + painter.width.ceilToDouble() + 10 + 1;
  }

  void _select(Mode mode) {
    final current = ref.read(modeProvider);
    if (mode != current) unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    ref.read(modeProvider.notifier).set(mode);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(modeProvider);
    final rest = mode.isAnime ? 0.0 : 1.0;
    final t = _drag ?? rest;
    // which side the thumb is on right now, so colours swap at halfway
    final showing = t < 0.5 ? Mode.anime : Mode.manga;
    final colors = ModeColors.of(showing);

    final animeW = showing.isAnime || widget.showInactiveLabel ? _labelled('Anime') : _iconOnly;
    final mangaW = !showing.isAnime || widget.showInactiveLabel ? _labelled('Manga') : _iconOnly;
    final thumbLeft = t * (animeW + 2);
    final thumbW = animeW + (mangaW - animeW) * t;
    final dragging = _drag != null;

    Widget segment(Mode m, IconData icon, String label, double width) {
      final active = m == showing;
      final fg = active ? colors.onAccent : TextTone.mid;
      return Semantics(
        button: true,
        selected: m == mode,
        label: '$label mode',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _select(m),
          child: AnimatedContainer(
            duration: dragging ? Duration.zero : Motion.lift,
            curve: Motion.enter,
            width: width,
            height: _target,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: fg, fill: active ? 1 : 0),
                if (active || widget.showInactiveLabel) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: _label.copyWith(color: fg),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final trackW = animeW + mangaW + 2;
    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _drag = rest),
      onHorizontalDragUpdate: (d) {
        final travel = trackW - thumbW;
        if (travel <= 0) return;
        final next = ((_drag ?? rest) + d.delta.dx / travel).clamp(0.0, 1.0);
        final crossed = (next < 0.5) != ((_drag ?? rest) < 0.5);
        if (crossed) unawaited(ref.read(hapticsProvider).play(Haptic.selection));
        setState(() => _drag = next);
      },
      onHorizontalDragEnd: (_) {
        final landed = (_drag ?? rest) < 0.5 ? Mode.anime : Mode.manga;
        setState(() => _drag = null);
        // the halfway haptic already played; landing is silent
        ref.read(modeProvider.notifier).set(landed);
      },
      onHorizontalDragCancel: () => setState(() => _drag = null),
      child: SizedBox(
        height: _target,
        child: Stack(
          children: [
            // the track: the thumb plus its padding and border, 40pt tall
            Positioned.fill(
              top: (_target - _height) / 2 - _pad - 1,
              bottom: (_target - _height) / 2 - _pad - 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Surface.s1,
                  borderRadius: BorderRadius.circular(Corner.full),
                  border: Border.all(color: Surface.line),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pad + 1),
              // animates with the segments, so their sum always fits the track
              child: AnimatedContainer(
                duration: dragging ? Duration.zero : Motion.lift,
                curve: Motion.enter,
                width: trackW,
                height: _target,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: dragging ? Duration.zero : Motion.lift,
                      curve: Motion.enter,
                      left: thumbLeft,
                      width: thumbW,
                      top: (_target - _height) / 2,
                      bottom: (_target - _height) / 2,
                      child: AnimatedContainer(
                        duration: Motion.overlay,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(Corner.full),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        segment(Mode.anime, Symbols.play_circle_rounded, 'Anime', animeW),
                        const SizedBox(width: 2),
                        segment(Mode.manga, Symbols.menu_book_rounded, 'Manga', mangaW),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
