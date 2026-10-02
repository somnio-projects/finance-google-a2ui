import 'package:flutter/material.dart';

/// Draws the tick inside a filled box.
///
/// The kit exports it as a three-point polyline — `M1978 665 L1981.3 668.3
/// L1988 660.7` inside a 16 px box — so it is painted rather than borrowed
/// from `Icons.check`, whose glyph is a different shape at a different
/// optical weight and would be the one mark on this card that is not the
/// design's.
class TaxLotCheckGlyphPainter extends CustomPainter {
  /// Creates the painter.
  const TaxLotCheckGlyphPainter({required this.color});

  /// The stroke, which is `checkGlyph` in both themes.
  final Color color;

  /// The polyline's three points as fractions of the box, from the export.
  static const List<Offset> points = <Offset>[
    Offset(0.1875, 0.5625),
    Offset(0.395, 0.769),
    Offset(0.8125, 0.294),
  ];

  /// The stroke width the export draws at 16 px.
  static const double strokeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final (index, point) in points.indexed) {
      final at = Offset(point.dx * size.width, point.dy * size.height);
      index == 0 ? path.moveTo(at.dx, at.dy) : path.lineTo(at.dx, at.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(TaxLotCheckGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
