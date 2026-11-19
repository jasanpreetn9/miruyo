// Carrying a selection to a status (Gestures · My List, 21): the selection
// lifts into a stack under the finger and the status panel rises from the
// bottom, in thumb reach. Dropping on a status moves everything there;
// dropping anywhere else changes nothing and keeps the selection.

import 'package:flutter/material.dart' hide Title;

import '../../core/anilist/types.dart';
import '../../core/catalog/status.dart';
import '../../core/catalog/title.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/cover_image.dart';
import 'list_edit.dart';

class CarryController {
  CarryController({
    required this.context,
    required this.titles,
    required this.here,
    required this.isAnime,
    required this.onEnter,
  });

  final BuildContext context;
  final List<Title> titles;

  /// The current tab: shown, but not a target.
  final MediaListStatus here;
  final bool isAnime;

  /// A target lit up under the finger.
  final VoidCallback onEnter;

  final _position = ValueNotifier<Offset>(Offset.zero);
  final _hot = ValueNotifier<MediaListStatus?>(null);
  final _keys = {for (final s in listStatuses) s: GlobalKey()};
  OverlayEntry? _entry;

  MediaListStatus? get hot => _hot.value;

  void show(Offset position) {
    _position.value = position;
    _entry = OverlayEntry(
      builder: (_) =>
          _CarryLayer(titles: titles, here: here, isAnime: isAnime, position: _position, hot: _hot, keys: _keys),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void move(Offset position) {
    _position.value = position;
    MediaListStatus? over;
    for (final MapEntry(key: status, value: key) in _keys.entries) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if ((box.localToGlobal(Offset.zero) & box.size).contains(position)) over = status;
    }
    if (over == here) over = null;
    if (over != _hot.value) {
      _hot.value = over;
      if (over != null) onEnter();
    }
  }

  void dismiss() {
    // the notifiers aren't disposed: the layer may still be listening until
    // the next frame unmounts it
    _entry?.remove();
    _entry = null;
  }
}

class _CarryLayer extends StatefulWidget {
  const _CarryLayer({
    required this.titles,
    required this.here,
    required this.isAnime,
    required this.position,
    required this.hot,
    required this.keys,
  });

  final List<Title> titles;
  final MediaListStatus here;
  final bool isAnime;
  final ValueNotifier<Offset> position;
  final ValueNotifier<MediaListStatus?> hot;
  final Map<MediaListStatus, GlobalKey> keys;

  @override
  State<_CarryLayer> createState() => _CarryLayerState();
}

class _CarryLayerState extends State<_CarryLayer> with SingleTickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: Motion.panel)..forward();

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final n = widget.titles.length;
    return Stack(
      children: [
        // a light scrim: the list stays readable behind
        IgnorePointer(
          child: FadeTransition(
            opacity: _rise,
            child: const ColoredBox(color: Color(0x80050609), child: SizedBox.expand()),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _rise, curve: Motion.enter)),
            child: Container(
              padding: EdgeInsets.fromLTRB(Space.gutter, 10, Space.gutter, bottom + Space.x4),
              decoration: const BoxDecoration(
                color: Surface.s2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Corner.lg)),
              ),
              child: ValueListenableBuilder(
                valueListenable: widget.hot,
                builder: (context, hot, _) => StatusPanel(
                  title: 'Drop on a status',
                  here: widget.here,
                  isAnime: widget.isAnime,
                  hot: hot,
                  targetKeys: widget.keys,
                ),
              ),
            ),
          ),
        ),
        // the stack under the finger: up to three covers and a count
        ValueListenableBuilder(
          valueListenable: widget.position,
          builder: (context, at, _) => Positioned(
            left: at.dx - 30,
            top: at.dy - 64,
            child: IgnorePointer(
              child: SizedBox(
                width: 84,
                height: 96,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final (i, t) in widget.titles.take(3).toList().reversed.indexed)
                      Positioned(
                        left: (2 - i) * 6.0,
                        top: (2 - i) * 4.0,
                        child: Transform.rotate(
                          angle: (i - 1) * 0.06,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(color: Color(0x99000000), blurRadius: 22, offset: Offset(0, 10)),
                              ],
                            ),
                            child: SizedBox(
                              width: 56,
                              height: 84,
                              child: CoverImage(title: t, thumb: true, radius: 6, showMissing: false),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 24),
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.mode.accent,
                          borderRadius: BorderRadius.circular(Corner.full),
                        ),
                        child: Text(
                          '$n',
                          style: AppType.numeric.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.mode.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
