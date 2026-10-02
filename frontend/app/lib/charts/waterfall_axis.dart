import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// The rule under the plot and the row of category names beneath it.
///
/// Two names are emphasised and the rest are muted, which is the UI Kit's own
/// hierarchy rather than a styling preference: the **closing total** (`Now`)
/// is where the walk arrives, and the **selected** band is where the reader
/// is looking. Both are decided from the step's `kind` and from the selected
/// index — never from the spelling of a label (N-5).
class WaterfallAxis extends StatelessWidget {
  /// Creates the axis under a plot of [steps].
  const WaterfallAxis({
    required this.steps,
    required this.labels,
    this.selectedIndex,
    super.key,
  });

  /// The space between the plot and the rule, and between the rule and the
  /// labels. Both are 8 px in the design.
  static const double gap = 8;

  /// The walk, in the order the backend sent it (N-10).
  final List<WaterfallStep> steps;

  /// One category name per step, drawn verbatim.
  final List<String> labels;

  /// The band drawn as selected, if any.
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: gap),
        Divider(height: 1, thickness: 1, color: palette.rule),
        const SizedBox(height: gap),
        Row(
          children: <Widget>[
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _styleFor(index, palette),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Whether the label at [index] is one of the two the design emphasises.
  ///
  /// A step past the end of [steps] is never emphasised rather than throwing:
  /// the labels and the walk are two lists and a caller may legitimately pass
  /// a shorter one (the chart's own empty state does).
  bool _isEmphasised(int index) =>
      index == selectedIndex ||
      (index < steps.length && steps[index].kind == WaterfallStepKind.total);

  TextStyle _styleFor(int index, ChartPalette palette) => _isEmphasised(index)
      ? ChartText.axisStrong(palette.title)
      : ChartText.axis(palette.mutedLabel);
}
