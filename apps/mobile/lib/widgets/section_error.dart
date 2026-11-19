import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/anilist/client.dart';
import '../core/anilist/errors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../core/ui/clock.dart';

/// A section that couldn't load (Home 1e). It stays in place with a retry
/// while the rest of the page keeps working. AniList's rate limit counts
/// down and retries on its own; other failures retry on a tap.
class SectionError extends StatefulWidget {
  const SectionError({super.key, required this.error, required this.onRetry, this.title = "Couldn't load this"});

  final Object error;
  final VoidCallback onRetry;

  /// Headline when AniList didn't respond (the rate-limit headline is fixed).
  final String title;

  @override
  State<SectionError> createState() => _SectionErrorState();
}

class _SectionErrorState extends State<SectionError> {
  Timer? _tick;
  int _remaining = 0;

  AniListError? get _err => widget.error is AniListError ? widget.error as AniListError : null;
  bool get _rateLimited => _err?.isRateLimit ?? false;

  @override
  void initState() {
    super.initState();
    if (_rateLimited) {
      _remaining = _err!.retryAfter ?? defaultRetryAfter;
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _remaining--);
        if (_remaining <= 0) {
          t.cancel();
          widget.onRetry();
        }
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mono = AppType.numeric.copyWith(fontSize: 14);
    final muted = AppType.body.copyWith(color: TextTone.mid, height: 1.5);
    final offline = _err?.isNetwork ?? false;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.x5),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFFFF8FA8), width: 2),
            top: BorderSide(color: Surface.line),
            bottom: BorderSide(color: Surface.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: const Color(0x24FF6B8B), borderRadius: BorderRadius.circular(2)),
              child: const Icon(Symbols.cloud_off_rounded, size: 22, color: Color(0xFFFF8FA8)),
            ),
            const SizedBox(height: Space.x3),
            if (_rateLimited) ...[
              Text('AniList is busy right now', style: AppType.title.copyWith(fontSize: 16)),
              const SizedBox(height: Space.x1),
              Text.rich(
                TextSpan(
                  style: muted,
                  children: [
                    const TextSpan(text: "We hit their rate limit. We'll try again automatically in "),
                    TextSpan(text: formatCountdown(_remaining), style: mono),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ] else ...[
              Text(offline ? "Can't reach AniList" : widget.title, style: AppType.title.copyWith(fontSize: 16)),
              const SizedBox(height: Space.x1),
              Text(
                offline
                    ? 'Check your connection and try again.'
                    : 'Something went wrong talking to AniList. Try again.',
                style: muted,
              ),
              if (_err != null && !offline) ...[
                const SizedBox(height: Space.x2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x4D000000), borderRadius: BorderRadius.circular(2)),
                  child: Text(_err!.message, style: AppType.numeric.copyWith(fontSize: 12, color: TextTone.low)),
                ),
              ],
            ],
            const SizedBox(height: Space.x3),
            OutlinedButton.icon(
              onPressed: () {
                _tick?.cancel();
                widget.onRetry();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, Space.minTarget),
                backgroundColor: Surface.s3,
                foregroundColor: TextTone.high,
                side: const BorderSide(color: Surface.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                textStyle: AppType.body.copyWith(fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Symbols.refresh_rounded, size: 20),
              label: const Text('Retry now'),
            ),
          ],
        ),
      ),
    );
  }
}
