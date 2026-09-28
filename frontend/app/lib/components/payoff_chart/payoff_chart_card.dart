import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/payoff_chart.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_detail.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_model.dart';
import 'package:flutter/material.dart';

/// Renders `payoff.curve.v1` as the design's card.
///
/// The chrome is the design's, read from its own stylesheet rather than
/// sampled: `background:#fdfbff; border:1px solid #eae7f0; border-radius:16px;
/// padding:16px 18px 14px`. It is the same chrome the attribution waterfall
/// uses, which is the catalog being one system rather than six.
class PayoffChartCard extends StatelessWidget {
  /// Creates the card.
  const PayoffChartCard({required this.data, super.key});

  /// The card's corner radius, measured from the design.
  static const double radius = 16;

  /// The card's padding, measured from the design.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 16, 18, 14);

  /// What to draw.
  final PayoffChartData data;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // The design puts the legend opposite the title rather than
            // under the plot: with two series the reader needs the key
            // *before* looking, not after (GGU-146).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ChartText.title(palette.title),
                  ),
                ),
                const SizedBox(width: 12),
                PayoffLegend(lines: data.lines),
              ],
            ),
            const SizedBox(height: 14),
            PayoffChart(
              series: data.series,
              tickLabels: data.tickLabels,
              valueLabels: <String>[
                for (final rung in data.rungs) rung.display,
              ],
              valueTicks: <double>[for (final rung in data.rungs) rung.at],
              breakEvenAt: data.breakEven?.at,
              currentAt: data.current?.at,
              breakEvenLabel: data.breakEven?.caption ?? '',
              lossWord: data.lossWord,
              gainWord: data.gainWord,
            ),
            if (data.totals.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              PayoffFactRow(facts: data.totals),
            ],
            if (data.annotations.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              PayoffFactRow(facts: data.annotations),
            ],
            const SizedBox(height: 12),
            PayoffDisclosure(text: data.disclosure),
          ],
        ),
      ),
    );
  }
}
