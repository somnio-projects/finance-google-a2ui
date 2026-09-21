import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// The clearance kept between two tick labels before one is dropped.
const double tickPadding = 8;

/// Draws as many of [labels] under the plot as fit without touching.
///
/// Its own file because it is the axis furniture rather than the plot, and
/// because the rule it implements is the whole of this chart's
/// responsiveness: the design shows seven labels for twenty-five points, and
/// rather than thin by a ratio each label is measured and drawn only when it
/// clears the last one. A narrow card therefore keeps fewer labels and a wide
/// one more, with no breakpoint anywhere (spec `frontend/0005` AC-6) — the
/// same rule the waterfall uses for its figures.
///
/// Every label is a backend `*Display` price copied to the canvas. This
/// chooses **which** of them fit and never what any of them says (N-1).
void paintTickRow(
  Canvas canvas, {
  required PayoffLayout layout,
  required List<String> labels,
  required Color color,
  required TextDirection textDirection,
  required double width,
  required double top,
}) {
  var freeFrom = 0.0;
  for (final (index, label) in labels.indexed) {
    final x = layout.tickX(index);
    if (x == null) continue;
    final painter = measureLabel(
      label,
      ChartText.axis(color),
      textDirection: textDirection,
    );
    final left = x - painter.width / 2;
    if (left < freeFrom || left + painter.width > width) continue;
    painter.paint(canvas, Offset(left, top));
    freeFrom = left + painter.width + tickPadding;
  }
}
