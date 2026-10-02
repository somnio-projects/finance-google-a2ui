import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// Paints a [DonutLayout].
///
/// The painter holds no geometry of its own: every angle and every radius
/// arrives already computed, so what can be wrong here is a colour or a
/// stroke — and the geometry is proved separately, arithmetically, against
/// the design's own rendered gradient stops (ADR-L D-13).
///
/// The ring is drawn as a **stroked arc** rather than as filled wedges with a
/// hole punched out of them. One `Paint` with `strokeWidth` equal to the
/// ring's thickness gives the same pixels as the design's `conic-gradient`
/// with its `donut-hole` overlay, and it does not depend on the hole being
/// filled with the card's own background — which is what the design's CSS
/// does, and which breaks the moment the card sits on anything else.
class DonutPainter extends CustomPainter {
  /// Creates a painter for one laid-out donut.
  const DonutPainter({
    required this.layout,
    required this.palette,
    this.selectedIndex,
    this.swatches,
  });

  /// How much wider the selected slice's stroke is drawn, in logical pixels.
  ///
  /// Selection is a thicker ring rather than a different colour, for the same
  /// reason the waterfall outlines a bar instead of recolouring it: the colour
  /// already carries the category's identity.
  static const double selectedGrowth = 6;

  /// The geometry to draw.
  final DonutLayout layout;

  /// The colours to draw it in.
  final AllocationPalette palette;

  /// The slice the reader has selected, if any.
  final int? selectedIndex;

  /// A ramp overriding the palette's default, for the class grouping.
  final List<Color>? swatches;

  @override
  void paint(Canvas canvas, Size size) {
    final ramp = swatches ?? palette.swatches;
    if (layout.isEmpty || layout.thickness <= 0) return;
    final center = Offset(layout.center.x, layout.center.y);
    final rect = Rect.fromCircle(center: center, radius: layout.strokeRadius);
    for (final arc in layout.arcs) {
      if (arc.sweepAngle <= 0) continue;
      final selected = arc.index == selectedIndex;
      canvas.drawArc(
        rect,
        arc.startAngle,
        arc.sweepAngle,
        false,
        Paint()
          ..color = ramp[arc.index % ramp.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = layout.thickness + (selected ? selectedGrowth : 0.0),
      );
    }
  }

  @override
  bool shouldRepaint(DonutPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.palette != palette ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.swatches != swatches;
}
