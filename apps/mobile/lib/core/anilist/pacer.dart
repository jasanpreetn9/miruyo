// Keeps the app under AniList's rate limit instead of running into it,
// ported from apps/web/src/lib/anilist/pacer.ts.
//
// AniList allows a set number of requests a minute (90, or 30 when it's
// busy) and every response says how many are left (X-RateLimit-Limit /
// X-RateLimit-Remaining). While plenty are left, requests go straight out.
// When few are, they go out one at a time at the limit's own pace (one
// every two seconds at 30 a minute), so a busy screen loads a little slower
// instead of hitting a 429. And when a 429 does say how long to wait
// (Retry-After), every request waits that out rather than each failing on
// its own.
//
// Unlike the browser, the app can read a 429, so a request with no response
// is a network failure, not a hidden rate limit; and one client lives for
// the whole process, so the count isn't saved between launches.

import 'dart:math' as math;

/// At or below this many left, requests are spaced out.
const lowWater = 5;

/// What AniList reports is only trusted this long: its window is a minute.
const _staleAfter = Duration(minutes: 1);

class Pacer {
  Pacer({DateTime Function()? now, Future<void> Function(Duration)? sleep})
    : _now = now ?? DateTime.now,
      _sleep = sleep ?? Future<void>.delayed;

  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;

  int _limit = 90;

  /// What the last response said was left, or null when unknown.
  int? _remaining;
  DateTime? _seenAt;

  /// Sent since the last response, so not counted in [_remaining] yet.
  int _inFlight = 0;

  /// When the next spaced-out request may go.
  DateTime? _next;
  DateTime? _pausedUntil;

  /// How many are likely left right now; null when unknown (or stale).
  int? get left {
    final seenAt = _seenAt;
    final remaining = _remaining;
    if (seenAt == null || remaining == null || _now().difference(seenAt) > _staleAfter) return null;
    return remaining - _inFlight;
  }

  bool get _low => (left ?? lowWater + 1) <= lowWater;

  /// The gap between requests at the limit's pace.
  Duration get spacing => Duration(milliseconds: (60000 / _limit).ceil());

  /// Completes when a request may go out; call it right before sending.
  Future<void> slot() async {
    for (;;) {
      final now = _now();
      final until = [
        ?_pausedUntil,
        if (_low) ?_next,
      ].fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      if (until == null || !until.isAfter(now)) break;
      await _sleep(until.difference(now));
    }
    // no await between the check and these: the next caller sees them
    if (_low) {
      final now = _now();
      final from = _next == null || now.isAfter(_next!) ? now : _next!;
      _next = from.add(spacing);
    }
    _inFlight++;
  }

  /// Reads AniList's headers off a response (any status); null when the
  /// request got no response.
  void settle(Map<String, String>? headers) {
    _inFlight = math.max(0, _inFlight - 1);
    final limit = int.tryParse(headers?['x-ratelimit-limit'] ?? '');
    final remaining = int.tryParse(headers?['x-ratelimit-remaining'] ?? '');
    if (limit != null && limit > 0) _limit = limit;
    if (remaining != null) {
      _remaining = remaining;
      _seenAt = _now();
    }
  }

  /// A 429 said to wait this many seconds: everything waits.
  void pause(int seconds) {
    final until = _now().add(Duration(seconds: seconds));
    if (_pausedUntil == null || until.isAfter(_pausedUntil!)) _pausedUntil = until;
  }
}
