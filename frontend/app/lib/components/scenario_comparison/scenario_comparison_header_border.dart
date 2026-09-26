import 'package:flutter/material.dart';

/// Strokes a column header's hairline: top and both sides, rounded at the
/// top, **open at the bottom** so the header runs into the table.
///
/// A `BoxDecoration` cannot draw this. Flutter asserts that a `borderRadius`
/// is only given for a *uniform* `Border`, so `Border(top:, left:, right:)`
/// plus rounded corners throws — and the obvious way round it, a uniform
/// `Border.all`, adds a bottom hairline the design does not have, in a
/// different colour from the row rule immediately beneath it.
///
/// Twenty lines of `Path` is the honest answer, and it is the same trade
/// ADR-L D-13 makes for charts: when the framework's convenience shape is
/// not the design's shape, paint the design's shape.
class ScenarioHeaderBorderPainter extends CustomPainter {
  /// Creates a painter stroking [color] with a [radius] top.
  const ScenarioHeaderBorderPainter({
    required this.color,
    required this.radius,
    this.fill,
  });

  /// The hairline colour.
  final Color color;

  /// The radius of the two top corners.
  final double radius;

  /// The cell's fill, or null for a column that carries none.
  ///
  /// The recommended column is filled **and** outlined; every other header
  /// is outlined only, which is why this is nullable rather than
  /// transparent-by-default.
  final Color? fill;

  /// The hairline's width. CSS draws a 1 px border *inside* the box, so the
  /// path is inset by half of this and the stroke lands on the same pixels.
  static const double strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = strokeWidth / 2;
    final right = size.width - inset;
    final path = Path()
      ..moveTo(inset, size.height)
      ..lineTo(inset, inset + radius)
      ..arcToPoint(
        Offset(inset + radius, inset),
        radius: Radius.circular(radius),
      )
      ..lineTo(right - radius, inset)
      ..arcToPoint(
        Offset(right, inset + radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(right, size.height);
    // The fill goes down first, inside the same path: a recommended header
    // is filled **and** outlined, and painting the fill separately would
    // leave it square under the rounded top corners.
    if (fill case final colour?) {
      canvas.drawPath(path, Paint()..color = colour);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(ScenarioHeaderBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.fill != fill;
}
