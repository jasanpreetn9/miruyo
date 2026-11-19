import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/catalog/airing.dart';
import '../core/catalog/title.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../core/ui/clock.dart';

/// The next episode: blue at rest, the accent with a live dot inside 24h,
/// "Airing now" for 30 minutes after release, then gone.
class CountdownChip extends ConsumerWidget {
  const CountdownChip({super.key, required this.next, this.compact = false});

  final NextAiring next;

  /// For narrow posters: no clock icon, and only the largest unit
  /// ("EP 3 · 5d", not "5d 18h"). Screen readers still get the full time.
  final bool compact;

  static final _secondUnit = RegExp(r'(\d+[dh]) \d+[hm]');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final chip = airingChip(ep: next.ep, airingAt: next.airingAt, nowSeconds: now);
    if (chip == null) return const SizedBox.shrink();
    final hot = chip.phase == AiringPhase.soon || chip.phase == AiringPhase.live;
    final mode = context.mode;
    final fg = hot ? mode.accentText : Accent.soraText;

    return Semantics(
      label: chip.label.replaceAll('EP', 'Episode'),
      excludeSemantics: true,
      child: Container(
        height: 24,
        // no fill: words in mono, vermilion when it's soon
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hot && !compact)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: mode.accent, shape: BoxShape.circle),
              )
            else if (hot)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(left: 2, right: 1),
                decoration: BoxDecoration(color: mode.accent, shape: BoxShape.circle),
              )
            else if (!compact)
              Icon(Symbols.schedule_rounded, size: 14, color: fg),
            SizedBox(width: compact && !hot ? 0 : 4),
            Flexible(
              child: Text(
                compact ? chip.label.replaceAllMapped(_secondUnit, (m) => m[1]!) : chip.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.numeric.copyWith(
                  fontSize: 11,
                  color: fg,
                  fontWeight: hot ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
