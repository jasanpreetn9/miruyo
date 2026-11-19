import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/gestures/haptics.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// The Anime/Manga toggle (Gestures · Navigation, 13), editorial: two words
/// with a slash, the current one in ink over a rule in its accent. Mode
/// changes only here: tap either word, or drag the rule. It follows the
/// finger, takes the accent of the nearer side as it passes halfway (with a
/// Selection haptic), and snaps on release. Landing is silent.
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
  static const _slash = 14.0;

  TextStyle get _label => AppType.sans(13, 1.2, FontWeight.w600);

  double _labelled(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _label),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    // +1 so a font that loads after this measure can't nudge it over
    return 4 + painter.width.ceilToDouble() + 4 + 1;
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

    final animeW = _labelled('Anime');
    final mangaW = _labelled('Manga');
    final thumbLeft = t * (animeW + _slash);
    final thumbW = animeW + (mangaW - animeW) * t;
    final dragging = _drag != null;

    Widget segment(Mode m, String label, double width) {
      final active = m == showing;
      final fg = active ? TextTone.high : TextTone.low;
      return Semantics(
        button: true,
        selected: m == mode,
        label: '$label mode',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _select(m),
          child: AnimatedContainer(
            duration: dragging ? Duration.zero : Motion.lift,
            curve: Motion.enter,
            width: width,
            height: _target,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: _label.copyWith(color: fg, fontWeight: active ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
          ),
        ),
      );
    }

    final trackW = animeW + mangaW + _slash;
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
                      // the rule under the current word
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(duration: Motion.overlay, height: 1.5, color: colors.accent),
                      ),
                    ),
                    Row(
                      children: [
                        segment(Mode.anime, 'Anime', animeW),
                        SizedBox(
                          width: _slash,
                          child: Center(
                            child: Text(
                              '/',
                              style: _label.copyWith(color: TextTone.low, fontWeight: FontWeight.w400),
                            ),
                          ),
                        ),
                        segment(Mode.manga, 'Manga', mangaW),
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
