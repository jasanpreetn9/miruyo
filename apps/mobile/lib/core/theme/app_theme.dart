import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../catalog/mode.dart';
import 'tokens.dart';

/// The editorial type scale (design/mockups): Fraunces, a serif, for display
/// and headings; Schibsted Grotesk for the UI; JetBrains Mono wherever digits
/// change (countdowns, progress) so they don't jitter.
abstract final class AppType {
  /// The bundled families (pubspec `fonts:`), variable fonts all three.
  static const serifFamily = 'Fraunces';
  static const sansFamily = 'Schibsted Grotesk';
  static const monoFamily = 'JetBrains Mono';

  /// Japanese glosses (視聴中, 秋): the phone's own Japanese font.
  static const jpFallback = ['Hiragino Sans', 'Noto Sans CJK JP', 'Noto Sans JP'];

  static List<FontVariation> _axes(FontWeight weight, [double? opsz]) => [
    FontVariation('wght', weight.value.toDouble()),
    if (opsz != null) FontVariation('opsz', opsz),
  ];

  /// Fraunces at [size]: the optical size follows the point size (capped at
  /// the font's 144), so display lines get the thin, high-contrast cut.
  static TextStyle serif(
    double size, {
    double height = 1.1,
    FontWeight weight = FontWeight.w500,
    double tracking = -0.02,
    bool italic = false,
    Color color = TextTone.high,
  }) => TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: jpFallback,
    fontSize: size,
    height: height,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    fontVariations: _axes(weight, size.clamp(9, 144).toDouble()),
    letterSpacing: size * tracking,
    color: color,
  );

  static TextStyle sans(double size, double height, FontWeight weight, [double tracking = 0]) => TextStyle(
    fontFamily: sansFamily,
    fontFamilyFallback: jpFallback,
    fontSize: size,
    height: height,
    fontWeight: weight,
    fontVariations: _axes(weight),
    letterSpacing: size * tracking,
    color: TextTone.high,
  );

  static TextStyle mono(double size, {FontWeight weight = FontWeight.w400, Color color = TextTone.high}) => TextStyle(
    fontFamily: monoFamily,
    fontSize: size,
    height: 1.2,
    fontWeight: weight,
    fontVariations: _axes(weight),
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color,
  );

  /// A Japanese gloss beside a heading (視聴中).
  static const jp = TextStyle(fontFamilyFallback: jpFallback, fontSize: 12, color: TextTone.low);

  /// Fraunces 300 · 64/60 · −4.5%: a masthead ("Good evening.").
  static final displayXL = serif(64, height: 0.94, weight: FontWeight.w300, tracking: -0.045);

  /// Fraunces 300 · 44/42 · −4%: page titles.
  static final displayL = serif(44, height: 0.95, weight: FontWeight.w300, tracking: -0.04);

  /// Fraunces 600 · 30/32 · −3%: a feature's title (the pick, the lead).
  static final heading = serif(30, height: 1.02, weight: FontWeight.w600, tracking: -0.03);

  /// Fraunces 500 · 22/26 · −2%: section headings on phones ("Continue watching").
  static final section = serif(22, height: 1.15, weight: FontWeight.w500, tracking: -0.02);

  /// Schibsted 700 · 17/22
  static final title = sans(17, 1.3, FontWeight.w700, -0.01);

  /// Schibsted 400 · 16/26
  static final bodyL = sans(16, 1.6, FontWeight.w400);

  /// Schibsted 400 · 14/20
  static final body = sans(14, 1.45, FontWeight.w400);

  /// Schibsted 500 · 12/16
  static final caption = sans(12, 1.33, FontWeight.w500);

  /// Schibsted 600 · 11/14 · +12% · caps (uppercase the string itself): kickers, labels.
  static final overline = sans(11, 1.3, FontWeight.w600, 0.12);

  /// JetBrains Mono 500 · 13/16: wherever digits change (countdowns, progress).
  static final numeric = mono(13, weight: FontWeight.w500);

  /// The logo wordmark.
  static final wordmark = serif(21, height: 1, weight: FontWeight.w700, tracking: -0.02);
}

/// The editorial offset shadow behind a cover: its colour half-mixed into
/// the page, set [d] down and right, with no blur.
List<BoxShadow> offsetShadow(Color accent, [double d = 6]) => [
  BoxShadow(color: Color.lerp(accent, Surface.base, 0.5)!, offset: Offset(d, d)),
];

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
      tint: Color(0x29E8452C), // 16%
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
    highlightColor: const Color(0x0FEFE7DA),
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
