import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/auth/session.dart';
import '../core/list/list_store.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// The offline banner (1j): AniList couldn't be reached and what's shown is
/// the device's copy, from [savedAt]. Signed in, it adds that changes are
/// kept and how many are waiting to be sent; [onRetry] adds a Retry button.
class OfflineNote extends ConsumerWidget {
  const OfflineNote({super.key, this.savedAt, this.what = 'these', this.onRetry});

  /// When the shown copy was saved; null when there's nothing saved to show.
  final DateTime? savedAt;

  /// "these", "your list".
  final String what;

  final VoidCallback? onRetry;

  static String ago(DateTime savedAt, {DateTime? now}) {
    final ago = (now ?? DateTime.now()).difference(savedAt);
    if (ago.inMinutes < 1) return 'just now';
    if (ago.inMinutes < 60) return '${ago.inMinutes}m ago';
    if (ago.inHours < 48) return '${ago.inHours}h ago';
    return '${ago.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionProvider.select((s) => s.authState == AuthState.signedIn));
    final queued = signedIn ? ref.watch(listStoreProvider.select((s) => s.queued.length)) : 0;
    final shown = savedAt == null ? '' : ' Showing $what from ${ago(savedAt!)}.';
    final kept = signedIn ? " Changes are saved here and sync when you're back." : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, Space.x6),
      padding: const EdgeInsets.fromLTRB(Space.x4, Space.x3, Space.x2, Space.x3),
      decoration: BoxDecoration(
        color: Accent.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Corner.md),
        border: Border.all(color: Accent.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.cloud_off_rounded, size: 22, color: Accent.gold),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Can't reach AniList.",
                        style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: '$shown$kept',
                        style: AppType.body.copyWith(color: const Color(0xFFC4C9D6)),
                      ),
                    ],
                  ),
                ),
                if (queued > 0) ...[
                  const SizedBox(height: Space.x1),
                  Text(
                    queued == 1 ? '1 change queued' : '$queued changes queued',
                    style: AppType.numeric.copyWith(fontSize: 12, color: Accent.gold),
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: Space.x2),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Symbols.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: TextTone.high,
                backgroundColor: Surface.s3,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                side: const BorderSide(color: Color(0x24FFFFFF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corner.sm)),
                textStyle: AppType.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ] else
            const SizedBox(width: Space.x2),
        ],
      ),
    );
  }
}

/// The dashed stand-in for a discovery row while offline (1j): "Trending
/// needs a connection", since only the list is kept on the device.
class NeedsConnection extends StatelessWidget {
  const NeedsConnection({super.key, required this.heading, this.signedIn = true});

  final String heading;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(heading, style: AppType.section),
          const SizedBox(height: 14),
          CustomPaint(
            painter: _DashedBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x6, vertical: Space.x8),
              child: Column(
                children: [
                  const Icon(Symbols.wifi_off_rounded, size: 28, color: TextTone.low),
                  const SizedBox(height: Space.x2),
                  Text(
                    '$heading needs a connection',
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: Space.x1),
                  Text(
                    signedIn
                        ? 'Your list works offline. Discovery rows come back when AniList does.'
                        : 'These rows come back when AniList does.',
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(color: TextTone.mid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final paint = Paint()
      ..color = const Color(0x24FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in (Path()..addRRect(rrect.deflate(0.5))).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
