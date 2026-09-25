import 'package:flutter/material.dart';

/// The little triangle under the desktop callout, aimed at the selected bar.
///
/// Its own widget because it is the one piece of the callout that is painted
/// rather than laid out, and because [dx] — the bar's centre inside the
/// callout — is what makes the callout an annotation of a bar rather than a
/// box that happens to be nearby.
class AttributionWaterfallPointer extends StatelessWidget {
  /// Creates the pointer.
  const AttributionWaterfallPointer({
    required this.dx,
    required this.fill,
    required this.border,
    super.key,
  });

  /// The triangle's height, measured from the desktop artboard.
  static const double height = 7;

  /// Its half-width at the base.
  static const double halfWidth = 7;

  /// Where the tip falls, from the callout's left edge.
  final double dx;

  /// The callout's own fill, so the two read as one shape.
  final Color fill;

  /// The callout's hairline, drawn down the triangle's two slopes.
  final Color border;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(
      painter: _PointerPainter(dx: dx, fill: fill, border: border),
    ),
  );
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter({
    required this.dx,
    required this.fill,
    required this.border,
  });

  final double dx;
  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    const half = AttributionWaterfallPointer.halfWidth;
    final path = Path()
      ..moveTo(dx - half, 0)
      ..lineTo(dx, size.height)
      ..lineTo(dx + half, 0);
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) =>
      oldDelegate.dx != dx ||
      oldDelegate.fill != fill ||
      oldDelegate.border != border;
}
