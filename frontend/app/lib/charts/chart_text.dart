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
