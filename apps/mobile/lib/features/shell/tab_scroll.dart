import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';

/// Taps on the tab that's already showing: (tab index, a count so the same
/// tab can be tapped again).
class TabReselect extends Notifier<(int, int)?> {
  @override
  (int, int)? build() => null;

  void reselect(int index) => state = (index, (state?.$2 ?? 0) + 1);
}

final tabReselectProvider = NotifierProvider<TabReselect, (int, int)?>(TabReselect.new);

/// Gives a tab its own primary scroll controller, so its main scroll view
/// picks it up without wiring, and scrolls it back to the top when the tab
/// is tapped again (the iOS convention).
class TabScrollScope extends ConsumerStatefulWidget {
  const TabScrollScope({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  ConsumerState<TabScrollScope> createState() => _TabScrollScopeState();
}

class _TabScrollScopeState extends ConsumerState<TabScrollScope> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tabReselectProvider, (_, tap) {
      if (tap == null || tap.$1 != widget.index || !_controller.hasClients) return;
      // a tab can have more than one view on the primary controller (Seasonal's two)
      for (final position in _controller.positions) {
        if (position.pixels > 0) {
          position.animateTo(0, duration: Motion.sheet, curve: Motion.enter);
        }
      }
    });
    return PrimaryScrollController(controller: _controller, child: widget.child);
  }
}
