import 'package:flutter/material.dart';

/// The type a chart draws its own labels in.
///
/// Size, weight and colour are the design's measured values: value labels and
/// axis labels are both 10 px, the first at weight 500 and the second at 400.
///
/// **Deliberate divergence.** The design sets these in Roboto Mono, and this
/// app bundles no font asset. The reason a designer reaches for a mono face
/// in a chart is column alignment of digits, and `tabularFigures` buys that
/// from the bundled font without a 60 kB download. `specs/frontend/0002`
/// records it as an open decision with design.
abstract final class ChartText {
  /// A figure drawn above a bar.
  static TextStyle value(Color color) => TextStyle(
    color: color,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.3,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// A total's figure, which the UI Kit prints heavier than a contribution's.
  ///
  /// `$479,675` and `$482,915` are the two figures a reader takes away from
  /// the walk, and the design gives them the card's title colour at 700
  /// rather than the gain/loss marks around them (spec frontend/0028 OD-2).
  static TextStyle total(Color color) => TextStyle(
    color: color,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.3,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// A category name drawn under the axis rule.
  static TextStyle axis(Color color) =>
      TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w400);

  /// The category name of the closing total, and of the selected band.
  ///
  /// The design bolds `Now` and whichever name the reader tapped, and leaves
  /// every other name muted — the two places the eye is meant to land.
  static TextStyle axisStrong(Color color) =>
      TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700);

  /// The card's caption above the plot.
  static TextStyle title(Color color) =>
      TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500);

  /// The figure that sits opposite a card's title, at the title's own size.
  ///
  /// The UI Kit's waterfall header is *`+$3,240 · +0.68%`* set level with
  /// `Today's drivers` and one weight heavier, not a chip or a pill (spec
  /// frontend/0028 OD-1).
  static TextStyle headlineFigure(Color color) => TextStyle(
    color: color,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  // `subtag` and `headline` lived here and were the allocation card's title
  // caption and its 30 px total. GGU-145 moved the total into the ring and
  // dropped the caption, which left both with no caller — deleted rather than
  // kept warm for a design that no longer draws them.

  /// A legend row's category name. Measured: 500 weight, 12.5 px.
  static TextStyle legendLabel(Color color) =>
      TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w500);

  /// A figure on a legend row, at the design's [size] for its column.
  ///
  /// The weight column is 11 px and the value column 12 px — two sizes, so
  /// the caller passes one rather than this guessing from the string.
  static TextStyle legendFigure(Color color, {required double size}) =>
      TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w500,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );

  /// A chip beside the title, carrying an annotation.
  static TextStyle chip(Color color) => TextStyle(
    color: color,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}

/// Lays [text] out for measurement and painting.
///
/// Returned rather than painted so the caller can decide, from the measured
/// width, whether the label fits its band — which is how the chart drops
/// value labels as it narrows instead of overlapping them. The design does
/// the same thing: its 245 px artboard shows no value labels at all.
TextPainter measureLabel(
  String text,
  TextStyle style, {
  required TextDirection textDirection,
}) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: textDirection,
  maxLines: 1,
)..layout();
