import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// Paints a [SparklineLayout]: a 2px line and a fade beneath it.
///
/// The design's sparkline is an SVG path stroked `#12805C` at 2px over a
/// vertical gradient of the same hue from 22 % opacity to none. The painter
/// holds no geometry of its own — every point comes from the layout, which
/// is what lets the geometry be tested without a canvas (ADR-L D-13).
class SparklinePainter extends CustomPainter {
  /// Creates the painter.
  const SparklinePainter({required this.layout, required this.color});

  /// The design's stroke width.
  static const double strokeWidth = 2;

  /// The design's top-of-fill opacity.
  static const double fillAlpha = 0.22;

  /// Where the points are.
  final SparklineLayout layout;

  /// The line's colour; the fill is the same hue faded.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.isEmpty) return;
    final line = Path()..moveTo(layout.points.first.x, layout.points.first.y);
    for (final point in layout.points.skip(1)) {
      line.lineTo(point.x, point.y);
    }
    final fill = Path.from(line)
      ..lineTo(layout.points.last.x, layout.baseline)
      ..lineTo(layout.points.first.x, layout.baseline)
      ..close();
    _paintFill(canvas, size, fill);
    _paintLine(canvas, line);
  }

  void _paintFill(Canvas canvas, Size size, Path fill) {
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: fillAlpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  void _paintLine(Canvas canvas, Path line) {
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.color != color;
}
