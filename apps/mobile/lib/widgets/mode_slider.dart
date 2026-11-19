import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/catalog/mode.dart';
import '../core/gestures/haptics.dart';
import '../core/providers.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// A full-width Anime / Manga switch (setup, Profile). Tap either half, or
/// drag the thumb: it follows the finger, the labels swap colour as it passes
/// halfway (with a Selection haptic), and it snaps to the nearer side on
/// release. Landing is silent, as on the top bar's toggle.
class ModeSlider extends ConsumerStatefulWidget {
  const ModeSlider({super.key, required this.value, required this.onChanged, this.height = 48});

  final Mode value;
  final ValueChanged<Mode> onChanged;
  final double height;

  @override
  ConsumerState<ModeSlider> createState() => _ModeSliderState();
}

class _ModeSliderState extends ConsumerState<ModeSlider> {
  /// 0 = Anime, 1 = Manga, while dragging; null at rest.
  double? _drag;

  static const _pad = 4.0;

  void _haptic() => unawaited(ref.read(hapticsProvider).play(Haptic.selection));

  void _tap(Mode m) {
    if (m == widget.value) return;
    _haptic();
    widget.onChanged(m);
  }

  @override
  Widget build(BuildContext context) {
    final rest = widget.value.isAnime ? 0.0 : 1.0;
    final t = _drag ?? rest;
    final showing = t < 0.5 ? Mode.anime : Mode.manga;
    final colors = ModeColors.of(showing);
    final dragging = _drag != null;

    return LayoutBuilder(
      builder: (context, box) {
        final half = (box.maxWidth - _pad * 2) / 2;
        return GestureDetector(
          onHorizontalDragStart: (_) => setState(() => _drag = rest),
          onHorizontalDragUpdate: (d) {
            final was = _drag ?? rest;
            final next = (was + d.delta.dx / half).clamp(0.0, 1.0);
            if ((next < 0.5) != (was < 0.5)) _haptic();
            setState(() => _drag = next);
          },
          onHorizontalDragEnd: (_) {
            final landed = (_drag ?? rest) < 0.5 ? Mode.anime : Mode.manga;
            setState(() => _drag = null);
            if (landed != widget.value) widget.onChanged(landed);
          },
          onHorizontalDragCancel: () => setState(() => _drag = null),
          child: Container(
            padding: const EdgeInsets.all(_pad),
            decoration: BoxDecoration(
              color: Surface.s1,
              borderRadius: BorderRadius.circular(Corner.md),
              border: Border.all(color: Surface.line),
            ),
            child: SizedBox(
              height: widget.height,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: dragging ? Duration.zero : Motion.lift,
                    curve: Motion.enter,
                    left: t * half,
                    width: half,
                    top: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: Motion.overlay,
                      decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  // filling the track, so the labels sit in the middle of the thumb
                  Positioned.fill(
                    child: Row(
                      children: [
                        for (final (m, name, icon) in [
                          (Mode.anime, 'Anime', Symbols.play_circle_rounded),
                          (Mode.manga, 'Manga', Symbols.menu_book_rounded),
                        ])
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: m == widget.value,
                              label: name,
                              excludeSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _tap(m),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 20,
                                      fill: m == showing ? 1 : 0,
                                      color: m == showing ? colors.onAccent : TextTone.mid,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      name,
                                      style: AppType.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: m == showing ? colors.onAccent : TextTone.mid,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
