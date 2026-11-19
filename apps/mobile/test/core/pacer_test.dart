// Ported from apps/web/src/lib/anilist/pacer.test.ts. The web's "no
// response" (a browser 429) and "across page loads" cases don't apply.

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/pacer.dart';

/// A pacer on a fake clock: sleeping moves the clock, and records how long.
({Pacer pacer, List<int> slept, void Function(int ms) advance}) fakePacer() {
  var t = DateTime(2026, 11, 3, 12);
  final slept = <int>[];
  final pacer = Pacer(
    now: () => t,
    sleep: (d) async {
      slept.add(d.inMilliseconds);
      t = t.add(d);
    },
  );
  return (pacer: pacer, slept: slept, advance: (ms) => t = t.add(Duration(milliseconds: ms)));
}

Map<String, String> headers(int limit, int remaining) => {
  'x-ratelimit-limit': '$limit',
  'x-ratelimit-remaining': '$remaining',
};

void main() {
  test('sends at once while plenty are left, or before AniList has said', () async {
    final (:pacer, :slept, advance: _) = fakePacer();
    for (var i = 0; i < 20; i++) {
      await pacer.slot();
    }
    pacer.settle(headers(30, 25));
    await pacer.slot();
    expect(slept, isEmpty);
  });

  test('spaces requests at the limit’s pace once few are left', () async {
    final (:pacer, :slept, advance: _) = fakePacer();
    await pacer.slot();
    pacer.settle(headers(30, lowWater));
    await pacer.slot();
    await pacer.slot();
    await pacer.slot();
    // 30 a minute: one every two seconds
    expect(slept, [2000, 2000]);
  });

  test('counts what is in flight against what is left', () async {
    final (:pacer, :slept, advance: _) = fakePacer();
    await pacer.slot();
    pacer.settle(headers(90, lowWater + 2));
    await pacer.slot(); // 7 left: goes
    await pacer.slot(); // 6 left: goes
    await pacer.slot(); // 5 left: goes, and spacing starts
    expect(slept, isEmpty);
    await pacer.slot();
    expect(slept, [pacer.spacing.inMilliseconds]);
  });

  test('forgets a low count after a minute', () async {
    final (:pacer, :slept, :advance) = fakePacer();
    await pacer.slot();
    pacer.settle(headers(30, 1));
    advance(61000);
    await pacer.slot();
    await pacer.slot();
    expect(slept, isEmpty);
  });

  test('after a 429 with Retry-After, everything waits it out', () async {
    final (:pacer, :slept, advance: _) = fakePacer();
    pacer.pause(10);
    await pacer.slot();
    await pacer.slot();
    expect(slept, [10000]);
  });

  test('callers waiting together go out one spacing apart', () async {
    final (:pacer, :slept, advance: _) = fakePacer();
    await pacer.slot();
    pacer.settle(headers(60, 0));
    await Future.wait([pacer.slot(), pacer.slot(), pacer.slot()]);
    // the first goes now; the others wait one and two seconds
    expect(slept, isNotEmpty);
    expect(slept.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(2000));
  });

  test('a request with no response still leaves the flight count', () async {
    final (:pacer, slept: _, advance: _) = fakePacer();
    await pacer.slot();
    pacer.settle(headers(90, 10));
    await pacer.slot();
    expect(pacer.left, 9);
    pacer.settle(null);
    expect(pacer.left, 10);
  });
}
