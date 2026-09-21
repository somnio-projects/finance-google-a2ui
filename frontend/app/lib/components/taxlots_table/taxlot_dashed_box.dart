import 'package:flutter/material.dart';

/// Draws the dashed rounded square the empty state shows.
///
/// `app/lib/charts/dashed_line.dart` dashes a straight horizontal run and
/// cannot follow a corner, and widening it to take a `Path` would be
/// editing a file the charts own to add a component (ADR-L D-3). This
/// painter walks the rounded rect's own `PathMetric`, which is the shape a
/// border needs and the chart helper never will.
///
/// **The pattern is approximate, and knowingly so** — the same limitation
/// `specs/frontend/0002` records for the connector. CSS leaves a `dashed`
/// border's pattern to the user agent, so the design carries no measurable
/// one; 4 on, 3 off is what Chrome renders at 1.5 px on the reference page,
/// and this reuses that number rather than inventing a second.
class TaxLotDashedBoxPainter extends CustomPainter {
  /// Creates the painter.
  const TaxLotDashedBoxPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  /// The dash colour.
  final Color color;

  /// The square's corner radius.
  final double radius;

  /// The dash thickness.
  final double strokeWidth;

  /// Pixels drawn per dash.
  static const double dash = 4;

  /// Pixels skipped between two dashes.
  static const double gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in outline.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += dash + gap) {
        final end = start + dash;
        canvas.drawPath(
          metric.extractPath(start, end < metric.length ? end : metric.length),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(TaxLotDashedBoxPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}
