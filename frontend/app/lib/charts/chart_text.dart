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

  /// A category name drawn under the axis rule.
  static TextStyle axis(Color color) =>
      TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w400);

  /// The card's caption above the plot.
  static TextStyle title(Color color) =>
      TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500);

  /// A small uppercase caption above a figure.
  ///
  /// The allocation card's `subtag`, measured: 600 weight, 10 px, uppercase
  /// with `letter-spacing:.08em`. The design sets it in Roboto Mono for the
  /// same digit-alignment reason recorded above, and this app bundles no mono
  /// face — `tabularFigures` buys the alignment without the download.
  static TextStyle subtag(Color color) => TextStyle(
    color: color,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The headline figure on a summary card.
  ///
  /// Measured from the allocation card: 400 weight, 30 px, `line-height:1.05`,
  /// `letter-spacing:-.5px`.
  static TextStyle headline(Color color) => TextStyle(
    color: color,
    fontSize: 30,
    fontWeight: FontWeight.w400,
    height: 1.05,
    letterSpacing: -0.5,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

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

/// Paints [painter] centred on [center] horizontally, with its baseline block
/// ending [above] pixels above that point.
void paintCenteredAbove(
  Canvas canvas,
  TextPainter painter,
  Offset center, {
  required double above,
}) => painter.paint(
  canvas,
  Offset(center.dx - painter.width / 2, center.dy - above - painter.height),
);
