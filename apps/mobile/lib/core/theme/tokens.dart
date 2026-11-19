// Design tokens, matching the web app's layout.css: the editorial redesign
// (design/mockups) on top of the design system's structure (screen 00).
// Change a value there and here together.

import 'package:flutter/animation.dart';

/// Surfaces: a warm paper-black, not blue-black. Elevation is shown by
/// lightness; in-flow content is ruled off rather than boxed.
abstract final class Surface {
  static const base = Color(0xFF13110F);
  static const s1 = Color(0xFF171512);
  static const s2 = Color(0xFF1D1A16);
  static const s3 = Color(0xFF25211C);
  static const s4 = Color(0xFF2D2822);

  /// Hairlines and rules: cream ink at 12%.
  static const line = Color(0x1FEFE7DA);

  /// The heavier rule over a table or a block of facts: ink itself.
  static const rule = TextTone.high;
}

/// The +1 and other repeated row actions: an outline, no fill, so a column
/// of them doesn't outshine the titles (the web's btn-quiet). The screen's
/// one main action is filled in ink (the web's btn-ink).
abstract final class Quiet {
  static const fill = Color(0x00000000);
  static const border = Surface.line;
}

/// Text tokens: cream ink; all pass AA on every surface up to S3.
abstract final class TextTone {
  static const high = Color(0xFFEFE7DA);
  static const mid = Color(0xFFB3A996);
  static const low = Color(0xFF9A9080);
}

/// The two mode accents and the secondary blue. Text on an accent is dark
/// ink: white on coral fails AA.
abstract final class Accent {
  /// Shu (vermilion): anime mode, the active rule under nav and tabs.
  static const beni = Color(0xFFE8452C);
  static const beniInk = Color(0xFF13110F);

  /// Shu lifted for text and icons on dark surfaces.
  static const beniText = Color(0xFFF07A63);

  /// Fuji: replaces Beni in manga mode.
  static const fuji = Color(0xFFA08CFF);
  static const fujiInk = Color(0xFF140E2B);
  static const fujiText = Color(0xFFB9A9FF);

  /// Sora: info, countdowns, links in data, the Watching status.
  static const sora = Color(0xFF5AB0FF);
  static const soraInk = Color(0xFF04182B);

  /// The light focus ring.
  static const focus = TextTone.high;

  /// Errors and destructive actions.
  static const danger = Color(0xFFFF6B8B);

  /// Score stars, the Paused status.
  static const gold = Color(0xFFF5B83D);

  /// Completed, "N new", a finished +1.
  static const green = Color(0xFF4ED98A);
  static const greenInk = Color(0xFF06210F);

  /// Countdowns at rest: quiet text, not blue (the editorial look keeps one accent).
  static const soraText = TextTone.mid;
}

/// The 4px spacing scale.
abstract final class Space {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x14 = 56.0;
  static const x20 = 80.0;

  /// Content starts at least this far in, clear of the OS back-gesture strip.
  static const gutter = x4;

  /// The smallest touch target, even when the visual is smaller.
  static const minTarget = 44.0;
}

/// Corners: nearly square everywhere (print, not app chrome); sheets keep a
/// small lip so they read as lifted.
abstract final class Corner {
  /// Tags, kbd.
  static const xs = 2.0;

  /// Buttons, covers.
  static const sm = 2.0;

  /// Panels and floating layers.
  static const md = 3.0;

  /// Modals, sheets.
  static const lg = 6.0;

  /// Pills, the mode toggle.
  static const full = 999.0;
}

/// Motion: quick and quiet, it confirms rather than performs.
abstract final class Motion {
  static const press = Duration(milliseconds: 90);
  static const overlay = Duration(milliseconds: 160);
  static const lift = Duration(milliseconds: 180);
  static const panel = Duration(milliseconds: 240);
  static const sheet = Duration(milliseconds: 320);
  static const shimmer = Duration(milliseconds: 1400);

  /// Skeletons give up and show an error after this long.
  static const shimmerTimeout = Duration(seconds: 8);

  /// Press feedback scales to this.
  static const pressScale = 0.97;

  /// cubic-bezier(.2,.8,.2,1)
  static const enter = Cubic(0.2, 0.8, 0.2, 1);

  /// cubic-bezier(.4,0,1,1)
  static const exit = Cubic(0.4, 0, 1, 1);
}

/// Gesture thresholds shared by every screen (Gestures · Overview, 22a).
abstract final class GestureSpec {
  /// The first this-many px of movement decide between scroll and swipe.
  static const axisLock = 8.0;

  /// Scrubbable strips (charts, the day strip) decide sooner.
  static const scrubAxisLock = 6.0;

  /// Swipes starting this close to the left edge belong to the OS back gesture.
  static const edgeStrip = 20.0;

  /// Row grammar: a swipe arms here…
  static const rowArm = 72.0;

  /// …and a left swipe this long opens quick actions instead of −1.
  static const rowMore = 160.0;

  /// A flick commits a row swipe once it's moved this far…
  static const rowFlickMin = 32.0;

  /// …this fast, in px/ms.
  static const rowFlickVelocity = 0.6;

  static const hold = Duration(milliseconds: 450);
  static const holdSlop = 8.0;
  static const peekScale = 0.96;

  /// Pagers commit at this share of their width, or a flick this fast (px/ms).
  static const pagerShare = 0.3;
  static const pagerFlickVelocity = 0.5;

  /// Movement past an end continues at this rate.
  static const rubberBand = 0.3;
  static const sheetRubberBand = 0.2;

  /// Sheets close past this drag, or a flick this fast (px/ms).
  static const sheetClose = 120.0;
  static const sheetFlickVelocity = 0.5;

  static const holdToDestroy = Duration(milliseconds: 800);

  /// Undo for removals and bulk moves…
  static const undoLong = Duration(seconds: 5);

  /// …and for everything else.
  static const undoShort = Duration(seconds: 4);
}
