import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/waterfall_marks.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// The gap between a bar's top edge and the figure above it, measured.
const double waterfallLabelGap = 7.5;

/// Paints one step's pre-formatted figure above its bar.
///
/// [text] is a `*.display` string the backend produced and this copies to the
/// canvas. Nothing here formats, rounds or signs a number (N-1); the painter
/// never sees the raw value, which reached it as a pixel position.
///
/// Two placement rules, both the design's and both measured rather than
/// chosen:
///
/// * **A label wider than its band is dropped.** It would collide with its
///   neighbour, and the design's narrow artboard shows no value labels at all
///   for exactly that reason. No breakpoint — the rule is the measured width.
/// * **A label that fits is clamped into the plot.** The two totals' figures
///   are the widest in the walk and sit over the outermost bars, so centring
///   them alone would push `$479,675` off the left edge. The design pins them
///   to the edge instead, which is [clampedLabelLeft].
void paintWaterfallValueLabel(
  Canvas canvas, {
  required WaterfallBar bar,
  required String text,
  required ChartPalette palette,
  required TextDirection textDirection,
  required BandScale bandScale,
}) {
  final painter = measureLabel(
    text,
    _styleFor(bar.step.kind, palette),
    textDirection: textDirection,
  );
  if (painter.width > bandScale.bandWidth) return;
  painter.paint(
    canvas,
    Offset(
      clampedLabelLeft(
        center: bar.rect.topCenter.x,
        width: painter.width,
        plotWidth: bandScale.width,
      ),
      bar.rect.top - waterfallLabelGap - painter.height,
    ),
  );
}

/// The type a step's figure is drawn in.
///
/// The UI Kit prints the two totals in the card's own title colour at the
/// heavier weight — they are the figures a reader takes away — while a
/// contribution keeps its gain or loss mark. Deriving one from the other got
/// this wrong before (spec frontend/0028 OD-2).
TextStyle _styleFor(WaterfallStepKind kind, ChartPalette palette) =>
    switch (kind) {
      WaterfallStepKind.start ||
      WaterfallStepKind.total => ChartText.total(palette.title),
      WaterfallStepKind.gain ||
      WaterfallStepKind.loss => ChartText.value(palette.labelFor(kind)),
    };
