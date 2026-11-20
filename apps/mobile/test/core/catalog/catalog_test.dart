// Ported from the web's humanize, score, progress, airing, status and dress
// tests, so both apps answer the same way.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/airing.dart';
import 'package:miruyo/core/catalog/cover_color.dart';
import 'package:miruyo/core/catalog/humanize.dart';
import 'package:miruyo/core/catalog/progress.dart';
import 'package:miruyo/core/catalog/score.dart';
import 'package:miruyo/core/catalog/season.dart';
import 'package:miruyo/core/catalog/status.dart';

void main() {
  group('humanizeFormat', () {
    test('maps known AniList formats', () {
      expect(humanizeFormat('TV_SHORT'), 'TV Short');
      expect(humanizeFormat('ONE_SHOT'), 'One-shot');
    });
    test('passes unknown formats through and handles null', () {
      expect(humanizeFormat('SOMETHING_NEW'), 'SOMETHING_NEW');
      expect(humanizeFormat(null), 'Unknown');
    });
  });

  test('humanizeStatus maps known statuses', () {
    expect(humanizeStatus('NOT_YET_RELEASED'), 'Not yet released');
    expect(humanizeStatus(null), 'Unknown');
  });

  test('humanizeSeason title-cases the season', () {
    expect(humanizeSeason(MediaSeason.winter), 'Winter');
  });

  test('MediaListStatus.parse keeps known statuses, defaulting to CURRENT', () {
    expect(MediaListStatus.parse('PLANNING'), MediaListStatus.planning);
    expect(MediaListStatus.parse('REPEATING'), MediaListStatus.repeating);
    expect(MediaListStatus.parse('???'), MediaListStatus.current);
  });

  group('formatTimeUntil', () {
    const cases = {
      0: 'now',
      -5: 'now',
      59: '0m',
      12 * 60: '12m',
      5 * 3600 + 5 * 60: '5h 05m',
      19 * 3600 + 12 * 60: '19h 12m',
      86400: '1d',
      2 * 86400 + 4 * 3600: '2d 4h',
    };
    cases.forEach((seconds, expected) {
      test('$seconds seconds → $expected', () => expect(formatTimeUntil(seconds), expected));
    });
  });

  group('stripHtml', () {
    test('removes tags and keeps line breaks as whitespace', () {
      expect(stripHtml('One<br>Two <i>three</i>'), 'One\nTwo three');
      expect(stripHtml('A<br />B'), 'A\nB');
    });
    test('decodes named and numeric entities', () {
      expect(stripHtml('Tom &amp; Jerry &#039;s &#x2014; &hellip;'), "Tom & Jerry 's — …");
    });
    test('leaves unknown entities alone', () => expect(stripHtml('&bogus;'), '&bogus;'));
    test('leaves out-of-range numeric entities alone instead of throwing', () {
      expect(stripHtml('a &#99999999; b &#x110000;'), 'a &#99999999; b &#x110000;');
    });
    test('trims surrounding whitespace', () => expect(stripHtml('  <p>x</p>  '), 'x'));
  });

  group('score', () {
    test('defaults to 10-point with half-point steps', () {
      final s = scoreScale();
      expect((s.max, s.step, s.precision), (10, 0.5, 0.1));
      expect(scoreScale(ScoreFormat.point100).max, 100);
    });

    test('clampScore clamps to the format range and its precision', () {
      expect(clampScore(11), 10);
      expect(clampScore(-2), 0);
      expect(clampScore(7.34), 7.3);
      expect(clampScore(7.6, ScoreFormat.point10), 8);
      expect(clampScore(double.nan), 0);
    });

    test('nudgeScore steps by half points on the decimal scale', () {
      expect(nudgeScore(7, 1), 7.5);
      expect(nudgeScore(7.5, -1), 7);
    });

    test('nudgeScore snaps off-grid scores onto the step grid', () {
      expect(nudgeScore(7.3, 1), 7.5);
      expect(nudgeScore(7.3, -1), 7);
    });

    test('nudgeScore stays within range', () {
      expect(nudgeScore(10, 1), 10);
      expect(nudgeScore(0, -1), 0);
      expect(nudgeScore(100, 1, ScoreFormat.point100), 100);
    });

    test('formatScore formats per scale and shows a dash when unscored', () {
      expect(formatScore(0), '—');
      expect(formatScore(8), '8.0');
      expect(formatScore(85, ScoreFormat.point100), '85');
      expect(formatScore(3, ScoreFormat.point3), '☺');
    });
  });

  group('plusOneOutcome', () {
    test('counts up', () {
      final o = plusOneOutcome((status: MediaListStatus.current, progress: 5), 24)!;
      expect((o.progress, o.completes, o.starts), (6, false, false));
    });

    test('completes on reaching the total while in progress', () {
      for (final status in [MediaListStatus.current, MediaListStatus.repeating, MediaListStatus.paused]) {
        final o = plusOneOutcome((status: status, progress: 23), 24)!;
        expect((o.progress, o.completes, o.starts), (24, true, false));
      }
    });

    test('keeps counting without a known total', () {
      final o = plusOneOutcome((status: MediaListStatus.current, progress: 1120), null)!;
      expect((o.progress, o.completes, o.starts), (1121, false, false));
    });

    test('starts a Planning entry (or completes a one-episode one)', () {
      final a = plusOneOutcome((status: MediaListStatus.planning, progress: 0), 24)!;
      expect((a.progress, a.completes, a.starts), (1, false, true));
      final b = plusOneOutcome((status: MediaListStatus.planning, progress: 0), 1)!;
      expect((b.completes, b.starts), (true, false));
    });

    test("doesn't complete what's dropped, or go past the total", () {
      expect(plusOneOutcome((status: MediaListStatus.dropped, progress: 23), 24)!.completes, false);
      expect(plusOneOutcome((status: MediaListStatus.current, progress: 24), 24), isNull);
      final o = plusOneOutcome(null, 1)!;
      expect((o.progress, o.completes, o.starts), (1, false, false));
    });
  });

  group('airing', () {
    const now = 1800000000;
    const hour = 3600;

    test('is blue at rest, accent within 24h, live for 30 min after release', () {
      expect(airingPhase(now + 25 * hour, now), AiringPhase.later);
      expect(airingPhase(now + 24 * hour, now), AiringPhase.soon);
      expect(airingPhase(now + 60, now), AiringPhase.soon);
      expect(airingPhase(now, now), AiringPhase.live);
      expect(airingPhase(now - 29 * 60, now), AiringPhase.live);
      expect(airingPhase(now - 30 * 60, now), AiringPhase.aired);
    });

    test('counts down live from the airing timestamp', () {
      final a = airingChip(ep: 9, airingAt: now + 2 * 86400 + 4 * hour, nowSeconds: now)!;
      expect((a.phase, a.label), (AiringPhase.later, 'EP 9 · 2d 4h'));
      final b = airingChip(ep: 17, airingAt: now + 4 * hour + 5 * 60, nowSeconds: now)!;
      expect((b.phase, b.label), (AiringPhase.soon, 'EP 17 · 4h 05m'));
    });

    test('reads "Airing now" just after release, then hides', () {
      expect(airingChip(ep: 3, airingAt: now - 60, nowSeconds: now)!.label, 'EP 3 · Airing now');
      expect(airingChip(ep: 3, airingAt: now - hour, nowSeconds: now), isNull);
    });
  });

  group('status', () {
    test('uses watch verbs for anime', () {
      expect(statusLabel(MediaListStatus.current, isAnime: true), 'Watching');
      expect(statusLabel(MediaListStatus.repeating, isAnime: true), 'Rewatching');
    });

    test('swaps to read verbs for manga', () {
      expect(statusLabel(MediaListStatus.current, isAnime: false), 'Reading');
      expect(statusLabel(MediaListStatus.repeating, isAnime: false), 'Rereading');
      expect(statusLabel(MediaListStatus.paused, isAnime: false), 'Paused');
    });

    test('has a label and colour for every status', () {
      for (final s in listStatuses) {
        expect(statusLabel(s, isAnime: true), isNotEmpty);
        expect(statusColor[s], isNotNull);
      }
    });

    test('isInProgress is true only while progress can still move', () {
      expect(listStatuses.where(isInProgress), [
        MediaListStatus.current,
        MediaListStatus.paused,
        MediaListStatus.repeating,
      ]);
    });
  });

  group('cover colour', () {
    test('uses a mid-luminance cover colour as the accent unchanged', () {
      expect(CoverColors.fromHex('#d9a75e').accent, const Color(0xFFD9A75E));
    });

    test('lifts very dark colours toward white and darkens very light ones', () {
      final dark = CoverColors.fromHex('#000000').accent;
      final light = CoverColors.fromHex('#ffffff').accent;
      expect(relativeLuminance(dark), greaterThan(0.1));
      expect(relativeLuminance(light), lessThan(0.7));
    });

    // Reference values: what Chrome renders for the same CSS color-mix()
    final browser = {
      ('#000000', 0.45, '#ffffff'): (113, 113, 113),
      ('#cc2222', 0.72, '#ffffff'): (226, 110, 99),
      ('#d9a75e', 0.72, '#ffffff'): (228, 192, 141),
      ('#d9a75e', 0.45, '#05060a'): (92, 70, 39),
      ('#22232c', 0.45, '#ffffff'): (152, 146, 148),
      ('#f0f0f0', 0.80, '#000000'): (178, 178, 178),
    };
    browser.forEach((mix, rgb) {
      final (a, p, b) = mix;
      test('matches CSS color-mix(in oklch, $a ${(p * 100).round()}%, $b)', () {
        final c = mixOklch(parseHex(a)!, p, parseHex(b)!);
        expect((c.r * 255).round(), closeTo(rgb.$1, 2));
        expect((c.g * 255).round(), closeTo(rgb.$2, 2));
        expect((c.b * 255).round(), closeTo(rgb.$3, 2));
      });
    });

    test('falls back for a missing or malformed colour', () {
      expect(CoverColors.fromHex(null).base, fallbackCoverColor);
      expect(CoverColors.fromHex('#abc').base, fallbackCoverColor);
    });
  });

  group('seasons', () {
    test('December counts as next year\'s winter', () {
      final s = currentSeason(DateTime(2026, 12, 5));
      expect((s.season, s.year), (MediaSeason.winter, 2027));
    });

    test('maps months to seasons', () {
      expect(currentSeason(DateTime(2026, 2)).season, MediaSeason.winter);
      expect(currentSeason(DateTime(2026, 3)).season, MediaSeason.spring);
      expect(currentSeason(DateTime(2026, 8)).season, MediaSeason.summer);
      expect(currentSeason(DateTime(2026, 10)).season, MediaSeason.fall);
    });

    test('next season wraps the year', () {
      final n = nextSeason((season: MediaSeason.fall, year: 2026));
      expect((n.season, n.year), (MediaSeason.winter, 2027));
    });
  });
}
