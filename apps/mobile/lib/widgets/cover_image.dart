import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:material_symbols_icons/symbols.dart';

import '../core/catalog/cover_color.dart';
import '../core/catalog/title.dart';
import '../core/theme/tokens.dart';

/// A cover over its cover-colour gradient: the gradient shows until the
/// image arrives, then the image fades in, so there's never a white flash.
/// A title without a cover gets the image_not_supported placeholder.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.title,
    this.thumb = false,
    this.radius = Corner.sm,
    this.showMissing = true,
  });

  final Title title;

  /// The smaller image, for list thumbnails.
  final bool thumb;
  final double radius;

  /// Show the title in the placeholder when there's no cover.
  final bool showMissing;

  @override
  Widget build(BuildContext context) {
    final url = thumb ? (title.thumbUrl ?? title.coverUrl) : title.coverUrl;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: url == null ? Surface.s2 : null,
          gradient: url == null ? null : coverGradient(title.colors),
        ),
        child: url == null
            ? (showMissing ? const _Missing() : const SizedBox.expand())
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                fadeInDuration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                fadeOutDuration: Duration.zero,
                placeholder: (_, _) => const SizedBox.expand(),
                errorWidget: (_, _, _) => const SizedBox.expand(),
              ),
      ),
    );
  }
}

/// linear-gradient(160deg, …) from the cover colour.
LinearGradient coverGradient(CoverColors colors) => LinearGradient(
  begin: const Alignment(-0.34, -1),
  end: const Alignment(0.34, 1),
  colors: colors.gradient,
  stops: CoverColors.gradientStops,
);

/// A missing cover: just the icon, scaled to the frame. No title on the
/// poster; it's under it already.
class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => Center(
        child: Icon(
          Symbols.image_not_supported_rounded,
          size: (box.maxWidth * 0.3).clamp(14.0, 32.0),
          color: const Color(0xFF9A9080),
        ),
      ),
    );
  }
}
