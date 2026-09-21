import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_model.dart';
import 'package:flutter/material.dart';

/// The legend: one swatch and name per series, plus the gain/loss key.
///
/// The design's legend also carries a "Current +$5,880 at 0%" entry and a
/// break-even swatch. Neither is drawn: the payload has no `current` marker
/// and no machine-readable break-even (spec `frontend/0005` OD-1, OD-7), and
/// a legend entry for something the chart does not draw would be a label for
/// a line that is not there.
class PayoffLegend extends StatelessWidget {
  /// Creates the legend.
  const PayoffLegend({required this.lines, super.key});

  /// The diameter of a series swatch, measured from the design.
  static const double swatch = 9;

  /// The series to name, in arrival order (N-10).
  final List<PayoffLine> lines;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        for (final (index, line) in lines.indexed)
          _Entry(
            color: index == 0 ? palette.barTotal : palette.barNeutral,
            label: line.name,
            rounded: true,
          ),
        _Entry(color: palette.barLoss, label: 'Loss', rounded: false),
        _Entry(color: palette.barGain, label: 'Gain', rounded: false),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.color,
    required this.label,
    required this.rounded,
  });

  final Color color;
  final String label;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: PayoffLegend.swatch,
          height: PayoffLegend.swatch,
          decoration: BoxDecoration(
            color: color,
            // The design draws a series as a dot and a region as a rounded
            // square, which is how a reader tells a line from a wash.
            borderRadius: BorderRadius.circular(rounded ? 4.5 : 3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: ChartText.axis(palette.mutedLabel)),
      ],
    );
  }
}

/// A row of label/figure pairs — the payload's `totals` or `annotations`.
///
/// Every pair is rendered, in arrival order, and none is matched on. The
/// design highlights the break-even among them; picking it out here would
/// mean comparing `label` against `'Break-even price'`, which is the client
/// interpreting a server-supplied string (N-5) and wrong in the two other
/// locales the view offers.
class PayoffFactRow extends StatelessWidget {
  /// Creates the row.
  const PayoffFactRow({required this.facts, super.key});

  /// The pairs to draw, in arrival order (N-10).
  final List<PayoffFact> facts;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: <Widget>[
        for (final fact in facts)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(fact.label, style: ChartText.axis(palette.mutedLabel)),
              const SizedBox(height: 2),
              Text(fact.text, style: ChartText.chip(palette.title)),
            ],
          ),
      ],
    );
  }
}

/// The payload's `disclosure`, drawn verbatim.
///
/// Never dropped and never truncated (N-9). This is the sentence that keeps a
/// straight line from reading as an options payoff, so it is a compliance
/// statement rather than a caption.
class PayoffDisclosure extends StatelessWidget {
  /// Creates the disclosure block.
  const PayoffDisclosure({required this.text, super.key});

  /// The payload's `disclosure`.
  final String text;

  @override
  Widget build(BuildContext context) {
    final payoff = PayoffPalette.of(context);
    return Text(text, style: ChartText.axis(payoff.axisLabel));
  }
}
