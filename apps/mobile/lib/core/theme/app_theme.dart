import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../catalog/mode.dart';
import 'tokens.dart';

/// The type scale from the design system. Bricolage Grotesque for display,
/// Geist for the UI, Geist Mono wherever digits change (countdowns, progress)
/// so they don't jitter.
abstract final class AppType {
  static TextStyle _bricolage(double size, double height, FontWeight weight, double tracking) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: size * tracking,
        color: TextTone.high,
      );

  static TextStyle _geist(double size, double height, FontWeight weight, [double tracking = 0]) => GoogleFonts.geist(
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: size * tracking,
    color: TextTone.high,
  );

  /// Bricolage 700 · 64/64 · −3.5%
  static final displayXL = _bricolage(64, 1, FontWeight.w700, -0.035);

  /// Bricolage 700 · 44/48 · −3%
  static final displayL = _bricolage(44, 1.1, FontWeight.w700, -0.03);

  /// Bricolage 650 · 28/34 · −2% (650 rounds to the nearest static weight)
  static final heading = _bricolage(28, 1.2, FontWeight.w600, -0.02);

  /// Smaller section headings on phones ("Continue watching").
  static final section = _bricolage(20, 1.2, FontWeight.w600, -0.02);

  /// Geist 600 · 18/24
  static final title = _geist(18, 1.33, FontWeight.w600, -0.01);

  /// Geist 400 · 16/26
  static final bodyL = _geist(16, 1.6, FontWeight.w400);

  /// Geist 400 · 14/20
  static final body = _geist(14, 1.45, FontWeight.w400);

  /// Geist 500 · 12/16
  static final caption = _geist(12, 1.33, FontWeight.w500);

  /// Geist 600 · 11/14 · +8% · caps (uppercase the string itself)
  static final overline = _geist(11, 1.3, FontWeight.w600, 0.08);

  /// Geist Mono 500 · 13/16
  static final numeric = GoogleFonts.geistMono(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
    color: TextTone.high,
  );

  /// The logo wordmark.
  static final wordmark = _bricolage(20, 1, FontWeight.w700, -0.02);
}

/// The colours that follow the Anime/Manga mode. Only the accent changes
/// between modes; structure doesn't.
@immutable
class ModeColors extends ThemeExtension<ModeColors> {
  const ModeColors({required this.accent, required this.onAccent, required this.accentText, required this.tint});

  factory ModeColors.of(Mode mode) => switch (mode) {
    Mode.anime => const ModeColors(
      accent: Accent.beni,
      onAccent: Accent.beniInk,
      accentText: Accent.beniText,
      tint: Color(0x29FF6A55), // 16%
    ),
    Mode.manga => const ModeColors(
      accent: Accent.fuji,
      onAccent: Accent.fujiInk,
      accentText: Accent.fujiText,
      tint: Color(0x2EA08CFF), // 18%
    ),
  };

  /// Fills: the primary button, the active toggle segment.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// The accent lifted for text and icons on dark surfaces.
  final Color accentText;

  /// Active tab and badge backgrounds.
  final Color tint;

  @override
  ModeColors copyWith({Color? accent, Color? onAccent, Color? accentText, Color? tint}) => ModeColors(
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentText: accentText ?? this.accentText,
    tint: tint ?? this.tint,
  );

  /// Lerped, so switching mode cross-fades the accent (Motion.overlay).
  @override
  ModeColors lerp(ModeColors? other, double t) {
    if (other == null) return this;
    return ModeColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
    );
  }
}

extension ModeColorsContext on BuildContext {
  ModeColors get mode => Theme.of(this).extension<ModeColors>()!;
}

/// The app is dark only: the design has no light theme.
ThemeData buildTheme(Mode mode) {
  final colors = ModeColors.of(mode);
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Surface.base,
    canvasColor: Surface.base,
    splashFactory: NoSplash.splashFactory,
    // a faint wash while pressed, so every tap answers
    highlightColor: const Color(0x0FFFFFFF),
    colorScheme: ColorScheme.dark(
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: Accent.sora,
      onSecondary: Accent.soraInk,
      surface: Surface.s1,
      onSurface: TextTone.high,
      onSurfaceVariant: TextTone.mid,
      surfaceContainerLowest: Surface.base,
      surfaceContainerLow: Surface.s1,
      surfaceContainer: Surface.s2,
      surfaceContainerHigh: Surface.s3,
      surfaceContainerHighest: Surface.s4,
      outline: Surface.line,
      outlineVariant: Surface.line,
      error: Accent.danger,
    ),
    extensions: [colors],
  );

  return base.copyWith(
    textTheme: TextTheme(
      displayLarge: AppType.displayXL,
      displayMedium: AppType.displayL,
      headlineMedium: AppType.heading,
      titleLarge: AppType.section,
      titleMedium: AppType.title,
      bodyLarge: AppType.bodyL,
      bodyMedium: AppType.body,
      labelMedium: AppType.caption,
      labelSmall: AppType.overline,
    ).apply(bodyColor: TextTone.high, displayColor: TextTone.high),
    iconTheme: const IconThemeData(color: TextTone.mid, size: 20),
    dividerTheme: const DividerThemeData(color: Surface.line, thickness: 1, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Surface.s2,
      modalBackgroundColor: Surface.s2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Corner.lg))),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
