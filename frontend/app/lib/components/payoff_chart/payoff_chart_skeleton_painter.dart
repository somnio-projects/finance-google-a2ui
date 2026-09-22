import 'package:flutter/rendering.dart';

/// Paints the payoff page's loading plot: the artboard's SVG, scaled to the
/// box it is given.
///
/// Every coordinate is the design's, in its `0 0 500 280` view box, and
/// nothing here is data — there is no payload yet. The line is a placeholder
/// shape, drawn dashed so it cannot be read as a curve.
class PayoffSkeletonPainter extends CustomPainter {
  /// Paints in [color].
  const PayoffSkeletonPainter({required this.color});

  /// The gridlines, tick stubs and dashed line.
  final Color color;

  /// The four gridlines' `y`, from `<line y1=… y2=…>`.
  static const List<double> gridlines = <double>[60, 115, 170, 225];

  /// The three tick stubs' `y`, from `<rect y=…>`; each is 18 × 10 at `x` 20.
  static const List<double> ticks = <double>[55, 110, 165];

  /// The dashed line's vertices, from `<path d="M44 214 L120 196 …">`.
  static const List<Offset> line = <Offset>[
    Offset(44, 214),
    Offset(120, 196),
    Offset(200, 168),
    Offset(280, 128),
    Offset(360, 96),
    Offset(486, 66),
  ];

  /// `stroke-dasharray="6 6"`, in design units.
  static const double dash = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 500;
    final sy = size.height / 280;
    final hairline = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final y in gridlines) {
      canvas.drawLine(
        Offset(44 * sx, y * sy),
        Offset(486 * sx, y * sy),
        hairline,
      );
    }
    final fill = Paint()..color = color;
    for (final y in ticks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(20 * sx, y * sy, 18 * sx, 10 * sy),
          Radius.circular(3 * sx),
        ),
        fill,
      );
    }
    final path = Path()..moveTo(line.first.dx * sx, line.first.dy * sy);
    for (final point in line.skip(1)) {
      path.lineTo(point.dx * sx, point.dy * sy);
    }
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * sx
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_dashed(path, dash * sx), stroke);
  }

  /// Cuts [source] into `on`/`off` dashes of [length] each.
  Path _dashed(Path source, double length) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashed.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += 2 * length;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(PayoffSkeletonPainter oldDelegate) =>
      oldDelegate.color != color;
}
