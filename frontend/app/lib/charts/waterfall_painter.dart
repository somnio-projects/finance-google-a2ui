import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/dashed_line.dart';
import 'package:finance_app/charts/waterfall_marks.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints a [WaterfallLayout].
///
/// The painter holds no geometry of its own: every rectangle and every point
/// arrives already computed, so what can be wrong here is a colour, a radius
/// or a dash — and the geometry is proved separately, arithmetically, in
/// `finance_charts` (ADR-L D-13).
class WaterfallPainter extends CustomPainter {
  /// Creates a painter for one laid-out chart.
  const WaterfallPainter({
    required this.layout,
    required this.palette,
    required this.valueLabels,
    required this.textDirection,
    this.selectedIndex,
  });

  /// The corner radius of a bar's top edge, measured from the design.
  static const Radius barRadius = Radius.circular(4);

  /// The connector's stroke width, measured from the design.
  static const double connectorWidth = 1.5;

  /// The gap between a bar's top edge and its value label.
  static const double labelGap = 7.5;

  /// The geometry to draw.
  final WaterfallLayout layout;

  /// The colours to draw it in.
  final ChartPalette palette;

  /// One pre-formatted figure per step, in step order.
  ///
  /// These are `*.display` strings the backend produced and this painter
  /// copies to the canvas. Nothing here formats, rounds or signs a number
  /// (N-1); the painter never even sees the raw values, which reached it as
  /// pixel positions.
  final List<String> valueLabels;

  /// The reading direction the labels are laid out in.
  final TextDirection textDirection;

  /// The step the reader has selected, if any.
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    _paintConnectors(canvas);
    for (final bar in layout.bars) {
      _paintBar(canvas, bar);
      _paintValueLabel(canvas, bar);
    }
  }

  @override
  bool shouldRepaint(WaterfallPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.palette != palette ||
      oldDelegate.selectedIndex != selectedIndex ||
      !listEquals(oldDelegate.valueLabels, valueLabels);

  void _paintBar(Canvas canvas, WaterfallBar bar) {
    final rect = Rect.fromLTRB(
      bar.rect.left,
      bar.rect.top,
      bar.rect.right,
      bar.rect.bottom,
    );
    final paint = Paint()..color = palette.barFor(bar.step.kind);
    canvas.drawRRect(
      RRect.fromRectAndCorners(rect, topLeft: barRadius, topRight: barRadius),
      paint,
    );
    if (bar.index != selectedIndex) return;
    // Selection is an outline rather than a colour change: recolouring a bar
    // would collide with the gain/loss meaning the colour already carries.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect.inflate(2),
        topLeft: barRadius,
        topRight: barRadius,
      ),
      Paint()
        ..color = palette.barTotal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintConnectors(Canvas canvas) {
    final paint = Paint()
      ..color = palette.connector
      ..strokeWidth = connectorWidth;
    for (final connector in layout.connectors) {
      drawDashedLine(
        canvas,
        Offset(connector.from.x, connector.from.y),
        Offset(connector.to.x, connector.to.y),
        paint,
      );
    }
  }

  void _paintValueLabel(Canvas canvas, WaterfallBar bar) {
    if (bar.index >= valueLabels.length) return;
    final painter = measureLabel(
      valueLabels[bar.index],
      ChartText.value(palette.labelFor(bar.step.kind)),
      textDirection: textDirection,
    );
    // A label wider than its band would collide with its neighbour, so it is
    // dropped rather than overlapped — the same thing the design's narrow
    // artboard does. No breakpoint: the rule is the measured width.
    if (painter.width > layout.bandScale.bandWidth) return;
    paintCenteredAbove(
      canvas,
      painter,
      Offset(bar.rect.topCenter.x, bar.rect.topCenter.y),
      above: labelGap,
    );
  }
}
