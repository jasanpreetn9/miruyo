import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';

/// A grid of covers with text under them (poster cards): each row is as tall
/// as a 2:3 cover at the column's width, plus [below] for the text under it
/// at the reader's text size, so large text never runs out of the cell.
class CoverGridDelegate extends SliverGridDelegate {
  const CoverGridDelegate({
    required this.below,
    this.textScale = 1,
    this.columns = 3,
    this.crossAxisSpacing = Space.x2,
    this.mainAxisSpacing = Space.x5,
  });

  /// From [context]'s text size.
  CoverGridDelegate.of(BuildContext context, {required double below, int columns = 3})
    : this(below: below, columns: columns, textScale: MediaQuery.textScalerOf(context).scale(1));

  /// The height under the cover at 1× text: bars, gaps and text lines.
  final double below;
  final double textScale;
  final int columns;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = (constraints.crossAxisExtent - crossAxisSpacing * (columns - 1)) / columns;
    final height = width * 1.5 + below * textScale;
    return SliverGridRegularTileLayout(
      crossAxisCount: columns,
      mainAxisStride: height + mainAxisSpacing,
      crossAxisStride: width + crossAxisSpacing,
      childMainAxisExtent: height,
      childCrossAxisExtent: width,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(CoverGridDelegate oldDelegate) =>
      oldDelegate.below != below ||
      oldDelegate.textScale != textScale ||
      oldDelegate.columns != columns ||
      oldDelegate.crossAxisSpacing != crossAxisSpacing ||
      oldDelegate.mainAxisSpacing != mainAxisSpacing;
}

/// Under a PosterCard's cover at 1× text: the status bar, two title lines
/// and the meta line.
const posterCardBelow = 80.0;
