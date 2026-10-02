import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/waterfall_axis.dart';
import 'package:finance_app/charts/waterfall_overlay.dart';
import 'package:finance_app/charts/waterfall_painter.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// A waterfall chart: a plot, a rule, and a row of category labels.
///
/// Responsive through `LayoutBuilder` and nothing else — the layout is
/// recomputed from the width it is given, so there is no breakpoint to keep
/// in step with a design (ADR-L D-13). Every string it shows was formatted by
/// the backend and is drawn verbatim.
class WaterfallChart extends StatelessWidget {
  /// Creates a chart over [steps].
  const WaterfallChart({
    required this.steps,
    required this.valueLabels,
    required this.axisLabels,
    this.onSegmentTap,
    this.selection,
    this.overlay,
    super.key,
  });

  /// Identifies the painted plot, so a test can aim a tap at it rather
  /// than at whichever `CustomPaint` a `MaterialApp` happens to build first.
  static const Key plotKey = Key('waterfall-plot');

  /// The plot's height, measured from the design's 200 px artboard.
  static const double plotHeight = 200;

  /// The selected column's corner radius, measured from the UI Kit.
  static const double columnRadius = 6;

  /// The walk, in the order the backend sent it (N-10).
  final List<WaterfallStep> steps;

  /// One `*.display` string per step, drawn above its bar.
  final List<String> valueLabels;

  /// One category name per step, drawn under the rule.
  final List<String> axisLabels;

  /// Called with a step's `key` when the reader taps its band.
  ///
  /// The key is the backend's raw symbol, which is the argument
  /// `drill.attribution.v1` takes.
  final void Function(String key)? onSegmentTap;

  /// The step drawn as selected, and the colours the design gives it.
  final WaterfallSelection? selection;

  /// What to float above the selected bar, on a card wide enough for it.
  final WaterfallOverlay? overlay;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _chart(context, constraints.maxWidth),
  );

  Widget _chart(BuildContext context, double width) {
    final layout = WaterfallLayout.of(
      steps: steps,
      width: width,
      height: plotHeight,
    );
    return Stack(
      children: <Widget>[
        ...waterfallColumnChildren(
          bandScale: layout.bandScale,
          selection: selection,
          radius: columnRadius,
        ),
        Column(
          // Shrink-wrapped: a chart is as tall as its plot, its rule and its
          // labels, and nothing more.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: plotHeight, child: _plot(context, layout)),
            WaterfallAxis(
              steps: steps,
              labels: axisLabels,
              selectedIndex: selection?.index,
            ),
          ],
        ),
      ],
    );
  }

  Widget _plot(BuildContext context, WaterfallLayout layout) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: (details) => _handleTap(layout, details.localPosition.dx),
    child: Stack(
      // The callout floats above the bar and out of the plot, exactly as the
      // desktop artboard draws it over the header.
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            key: plotKey,
            painter: WaterfallPainter(
              layout: layout,
              palette: ChartPalette.of(context),
              valueLabels: valueLabels,
              textDirection: Directionality.of(context),
              selection: selection,
            ),
          ),
        ),
        ...waterfallOverlayChildren(
          context,
          layout: layout,
          selection: selection,
          overlay: overlay,
          plotHeight: plotHeight,
        ),
      ],
    ),
  );

  void _handleTap(WaterfallLayout layout, double dx) {
    final callback = onSegmentTap;
    if (callback == null) return;
    final band = layout.bandScale.bandAt(dx);
    if (band == null || band >= steps.length) return;
    callback(steps[band].key);
  }
}
