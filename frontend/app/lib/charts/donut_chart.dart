import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/donut_painter.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// A donut chart: a ring of slices, sized to the box it is given.
///
/// Responsive through `LayoutBuilder` and nothing else — the layout is
/// recomputed from the `Size`, so there is no breakpoint to keep in step with
/// a design (ADR-L D-13). The chart draws **no text at all**: every figure the
/// reader needs is in the legend beside it, already formatted by the backend,
/// which is why this file cannot break the numbers rule even by accident.
class DonutChart extends StatelessWidget {
  /// Creates a chart over [weights].
  const DonutChart({
    required this.weights,
    this.onSliceTap,
    this.selectedIndex,
    this.diameter = designDiameter,
    this.center,
    this.swatches,
    super.key,
  });

  /// Identifies the painted ring, so a test can aim a tap at it rather than
  /// at whichever `CustomPaint` a `MaterialApp` happens to build first.
  static const Key plotKey = Key('donut-plot');

  /// The ring's diameter in the design's primary card, in logical pixels.
  ///
  /// Measured: the catalog page's default state renders a 150 px ring. The
  /// hole follows from [DonutLayout.defaultThicknessRatio], which is the same
  /// measurement's other half.
  static const double designDiameter = 150;

  /// One raw `weight.value` per category, in payload order (N-10).
  ///
  /// These are geometry, not figures: they arrive through
  /// `ViewPayload.geometry` (ADR-L D-14) and leave as angles. The matching
  /// `weight.display` strings go to the legend and never come here.
  final List<double> weights;

  /// Called with a slice's index when the reader taps it.
  final void Function(int index)? onSliceTap;

  /// The slice drawn as selected, if any.
  final int? selectedIndex;

  /// The ring's diameter. Shrinks with the card on a narrow screen.
  final double diameter;

  /// What to print in the hole — the design's `Classes / 4`.
  final Widget? center;

  /// The ramp to sweep with; the palette's default when null.
  final List<Color>? swatches;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: diameter,
    height: diameter,
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        LayoutBuilder(builder: _plot),
        if (center != null) IgnorePointer(child: center),
      ],
    ),
  );

  Widget _plot(BuildContext context, BoxConstraints constraints) {
    final layout = DonutLayout.of(
      weights: weights,
      width: constraints.maxWidth,
      height: constraints.maxHeight,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(layout, details.localPosition),
      child: CustomPaint(
        key: plotKey,
        size: constraints.biggest,
        painter: DonutPainter(
          layout: layout,
          palette: AllocationPalette.of(context),
          selectedIndex: selectedIndex,
          swatches: swatches,
        ),
      ),
    );
  }

  /// Resolves a tap to the slice under it.
  ///
  /// The angle arithmetic is `DonutHitTest` in `finance_charts`, not here: it
  /// is geometry, so it belongs in the pure package where it is asserted
  /// arithmetically under `dart test` (ADR-L D-13). Keeping it there is also
  /// what lets it avoid absolute value and trigonometry, both of which
  /// `binding_rules_compute_test.dart` bans from `app/lib` with no carve-out
  /// — including, as this comment found out, in prose, since the rule greps
  /// source text. This widget contributes the gesture and nothing else.
  void _handleTap(DonutLayout layout, Offset position) {
    final callback = onSliceTap;
    if (callback == null) return;
    final index = layout.arcIndexAt(
      position.dx - layout.center.x,
      position.dy - layout.center.y,
    );
    if (index != null) callback(index);
  }
}
