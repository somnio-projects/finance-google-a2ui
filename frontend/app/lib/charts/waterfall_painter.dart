import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/waterfall_marks.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:finance_app/charts/waterfall_value_label.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints a [WaterfallLayout].
///
/// The painter holds no geometry of its own: every rectangle and every point
/// arrives already computed, so what can be wrong here is a colour, a radius
/// or a stroke — and the geometry is proved separately, arithmetically, in
/// `finance_charts` (ADR-L D-13).
class WaterfallPainter extends CustomPainter {
  /// Creates a painter for one laid-out chart.
  const WaterfallPainter({
    required this.layout,
    required this.palette,
    required this.valueLabels,
    required this.textDirection,
    this.selection,
  });

  /// The corner radius of a bar, measured from the UI Kit.
  ///
  /// **All four corners**, not the two at the top: a contribution floats
  /// between two running totals and is a capsule in the design, and squaring
  /// its lower edge made it read as standing on something (spec
  /// frontend/0028 OD-2).
  static const Radius barRadius = Radius.circular(4);

  /// The connector's stroke width, measured from the design.
  static const double connectorWidth = 1;

  /// The geometry to draw.
  final WaterfallLayout layout;

  /// The colours to draw it in.
  final ChartPalette palette;

  /// One pre-formatted figure per step, in step order.
  ///
  /// These are `*.display` strings the backend produced and this painter
  /// copies to the canvas (N-1).
  final List<String> valueLabels;

  /// The reading direction the labels are laid out in.
  final TextDirection textDirection;

  /// The step the reader has selected, and the colours it takes.
  final WaterfallSelection? selection;

  @override
  void paint(Canvas canvas, Size size) {
    _paintConnectors(canvas);
    for (final bar in layout.bars) {
      _paintBar(canvas, bar);
      if (bar.index < valueLabels.length) {
        paintWaterfallValueLabel(
          canvas,
          bar: bar,
          text: valueLabels[bar.index],
          palette: palette,
          textDirection: textDirection,
          bandScale: layout.bandScale,
        );
      }
    }
  }

  @override
  bool shouldRepaint(WaterfallPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.palette != palette ||
      oldDelegate.selection != selection ||
      !listEquals(oldDelegate.valueLabels, valueLabels);

  /// The fill of [bar], which is its own mark unless it is the selected one.
  ///
  /// Exposed so a test can assert the substitution without reading pixels:
  /// selecting a bar deepens its fill and never changes which *family* the
  /// fill belongs to, so a gain stays green and a loss stays red.
  Color fillFor(WaterfallBar bar) => bar.index == selection?.index
      ? selection!.barFill
      : palette.barFor(bar.step.kind);

  void _paintBar(Canvas canvas, WaterfallBar bar) {
    final rect = Rect.fromLTRB(
      bar.rect.left,
      bar.rect.top,
      bar.rect.right,
      bar.rect.bottom,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, barRadius),
      Paint()..color = fillFor(bar),
    );
  }

  /// The runs between neighbouring bars.
  ///
  /// **Solid**, at one pixel: the UI Kit draws an unbroken hairline from each
  /// bar's exit level to the next band. The first build dashed them, which is
  /// what a reference line looks like — a different statement (0028 OD-2).
  void _paintConnectors(Canvas canvas) {
    final paint = Paint()
      ..color = palette.connector
      ..strokeWidth = connectorWidth;
    for (final connector in layout.connectors) {
      canvas.drawLine(
        Offset(connector.from.x, connector.from.y),
        Offset(connector.to.x, connector.to.y),
        paint,
      );
    }
  }
}
