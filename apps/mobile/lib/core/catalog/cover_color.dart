// The cover-colour rules from apps/web/src/lib/catalog/dress.ts.
//
// AniList's coverImage.color is normalised before use: very dark colours are
// mixed toward white, very light ones toward black, so glows and progress
// bars stay visible on #090B11. It's only ever used for glow, progress fill
// and a 16% tint — never for text.
//
// The web does this with CSS `color-mix(in oklch, …)`; this is the same
// mix, computed here.

import 'dart:math' as math;
import 'dart:ui';

const fallbackCoverColor = Color(0xFF30363D);

Color? parseHex(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

double _channel(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// WCAG relative luminance, as the web's hexLum().
double relativeLuminance(Color c) => 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _toLinear(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _fromLinear(double c) => c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

double _cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

typedef _Oklch = ({double l, double c, double? h});

_Oklch _toOklch(Color color) {
  final r = _toLinear(color.r), g = _toLinear(color.g), b = _toLinear(color.b);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  final okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  final okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  final c = math.sqrt(okA * okA + okB * okB);
  // near-neutral colours (white, black, #05060a) have no hue: CSS treats it
  // as "missing" and takes the other colour's hue when mixing. 0.02 is
  // Chrome's cutoff for hex colours, measured; below it a mix toward the
  // page's deep navy keeps the cover's hue instead of swinging toward blue.
  final h = c < 0.02 ? null : (math.atan2(okB, okA) * 180 / math.pi) % 360;
  return (l: okL, c: c, h: h);
}

Color _fromOklch(_Oklch v, double alpha) {
  final hr = (v.h ?? 0) * math.pi / 180;
  final a = v.c * math.cos(hr), b = v.c * math.sin(hr);
  final l = math.pow(v.l + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
  final m = math.pow(v.l - 0.1055613458 * a - 0.0638541728 * b, 3).toDouble();
  final s = math.pow(v.l - 0.0894841775 * a - 1.2914855480 * b, 3).toDouble();
  double ch(double x) => _fromLinear(x).clamp(0.0, 1.0);
  return Color.from(
    alpha: alpha,
    red: ch(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    green: ch(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    blue: ch(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
  );
}

/// CSS `color-mix(in oklch, a p, b)`: [p] (0–1) of [a], the rest [b]. Hue
/// takes the shorter arc.
Color mixOklch(Color a, double p, Color b) {
  final x = _toOklch(a), y = _toOklch(b);
  double? hue;
  if (x.h == null) {
    hue = y.h;
  } else if (y.h == null) {
    hue = x.h;
  } else {
    var d = y.h! - x.h!;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    hue = (x.h! + d * (1 - p)) % 360;
  }
  final q = 1 - p;
  return _fromOklch((l: x.l * p + y.l * q, c: x.c * p + y.c * q, h: hue), 1);
}

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);
const _deep = Color(0xFF05060A);

/// Everything a title's cover colour drives.
class CoverColors {
  const CoverColors._({
    required this.base,
    required this.accent,
    required this.gradient,
    required this.glow,
    required this.tint,
  });

  factory CoverColors.from(Color base) {
    final lum = relativeLuminance(base);
    final accent = lum < 0.12
        ? mixOklch(base, 0.45, _white)
        : lum > 0.6
        ? mixOklch(base, 0.8, _black)
        : base;
    return CoverColors._(
      base: base,
      accent: accent,
      // linear-gradient(160deg, mix 72% white 0%, colour 42%, mix 45% deep 100%)
      gradient: [mixOklch(base, 0.72, _white), base, mixOklch(base, 0.45, _deep)],
      glow: accent.withValues(alpha: 0.7),
      tint: accent.withValues(alpha: 0.16),
    );
  }

  factory CoverColors.fromHex(String? hex) => CoverColors.from(parseHex(hex) ?? fallbackCoverColor);

  /// AniList's colour as given.
  final Color base;

  /// Normalised so it always reads on the base surface: glow, progress fill.
  final Color accent;

  /// The placeholder a cover shows until its image loads (stops 0, .42, 1 at 160°).
  final List<Color> gradient;

  /// The card glow (shadow 0 18 40 −14).
  final Color glow;

  /// 16% wash for chips and selected rows.
  final Color tint;

  static const gradientStops = [0.0, 0.42, 1.0];
}
