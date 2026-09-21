import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/waterfall_painter.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// A waterfall chart: a plot, a rule, and a row of category labels.
///
/// Responsive through `LayoutBuilder` and nothing else — the layout is
/// recomputed from the `Size` it is given, so there is no breakpoint to keep
/// in step with a design (ADR-L D-13). Every string it shows was formatted by
/// the backend and is drawn verbatim.
class WaterfallChart extends StatelessWidget {
  /// Creates a chart over [steps].
  const WaterfallChart({
    required this.steps,
    required this.valueLabels,
    required this.axisLabels,
    this.onSegmentTap,
    this.selectedIndex,
    super.key,
  });

  /// Identifies the painted plot, so a test can aim a tap at it rather
  /// than at whichever `CustomPaint` a `MaterialApp` happens to build first.
  static const Key plotKey = Key('waterfall-plot');

  /// The plot's height, measured from the design's 200 px artboard.
  static const double plotHeight = 200;

  /// The space between the plot and the rule, and between the rule and the
  /// axis labels. Both are 8 px in the design.
  static const double axisGap = 8;

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

  /// The step drawn as selected, if any.
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: plotHeight,
          child: LayoutBuilder(builder: _plot),
        ),
        const SizedBox(height: axisGap),
        Divider(height: 1, thickness: 1, color: palette.rule),
        const SizedBox(height: axisGap),
        Row(
          children: <Widget>[
            for (var index = 0; index < axisLabels.length; index++)
              Expanded(
                child: Text(
                  axisLabels[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ChartText.axis(
                    index == selectedIndex
                        ? palette.barTotal
                        : palette.mutedLabel,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _plot(BuildContext context, BoxConstraints constraints) {
    final layout = WaterfallLayout.of(
      steps: steps,
      width: constraints.maxWidth,
      height: constraints.maxHeight,
    );
    final painter = WaterfallPainter(
      layout: layout,
      palette: ChartPalette.of(context),
      valueLabels: valueLabels,
      textDirection: Directionality.of(context),
      selectedIndex: selectedIndex,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(layout, details.localPosition.dx),
      child: CustomPaint(
        key: plotKey,
        size: constraints.biggest,
        painter: painter,
      ),
    );
  }

  void _handleTap(WaterfallLayout layout, double dx) {
    final callback = onSegmentTap;
    if (callback == null) return;
    final band = layout.bandScale.bandAt(dx);
    if (band == null || band >= steps.length) return;
    callback(steps[band].key);
  }
}
