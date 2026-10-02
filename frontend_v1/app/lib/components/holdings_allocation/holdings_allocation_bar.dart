import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The stacked bar under the legend: one segment per slice, in the ring's
/// colours, 6px tall at radius 4 (spec 0026 §2).
///
/// Segments are painted, not flexed: a painter takes the raw weights as
/// fractions of the width, which is the geometry use ADR-K reserves them for
/// (N-4), and needs no integer flex — so nothing here rounds.
class HoldingsAllocationBar extends StatelessWidget {
  /// Creates the bar.
  const HoldingsAllocationBar({
    required this.weights,
    required this.colors,
    super.key,
  });

  /// The design's height.
  static const double height = 6;

  /// The design's radius.
  static const double radius = 4;

  /// The shares, in row order.
  final List<double> weights;

  /// One colour per share.
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: AllocationBarPainter(weights: weights, colors: colors),
      ),
    ),
  );
}

/// Paints [weights] left to right, each `weight × width` wide.
class AllocationBarPainter extends CustomPainter {
  /// Creates the painter.
  const AllocationBarPainter({required this.weights, required this.colors});

  /// The shares, in row order.
  final List<double> weights;

  /// One colour per share, cycled if shorter.
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    var left = 0.0;
    for (var index = 0; index < weights.length; index++) {
      final width = size.width * weights[index];
      if (width <= 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(left, 0, width, size.height),
        Paint()..color = colors[index % colors.length],
      );
      left += width;
    }
  }

  @override
  bool shouldRepaint(AllocationBarPainter oldDelegate) =>
      !listEquals(oldDelegate.weights, weights) ||
      !listEquals(oldDelegate.colors, colors);
}
