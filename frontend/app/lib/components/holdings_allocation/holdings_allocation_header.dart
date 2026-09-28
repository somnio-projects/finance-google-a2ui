import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/holdings_allocation/allocation_gain.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';

/// Title, total, and the all-time gain under it (the catalog page's header).
class HoldingsAllocationHeader extends StatelessWidget {
  /// Creates the header.
  const HoldingsAllocationHeader({required this.data, super.key});

  /// Gap under the caption.
  static const double captionGap = 6;

  /// Gap under the headline.
  static const double headlineGap = 4;

  /// The model.
  final AllocationData data;

  @override
  Widget build(BuildContext context) {
    final chart = ChartPalette.of(context);
    final palette = AllocationPalette.of(context);
    final gain = data.totalGain;
    return Semantics(
      container: true,
      header: true,
      label: '${data.title} ${data.totalLabel} ${data.totalDisplay}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ChartText.subtag(palette.legendWeight),
            ),
            const SizedBox(height: captionGap),
            Text(
              data.totalDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ChartText.headline(chart.title),
            ),
            const SizedBox(height: headlineGap),
            if (gain != null)
              _GainLine(gain: gain, chart: chart, muted: palette.legendWeight)
            else
              Text(
                data.totalLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ChartText.legendFigure(palette.legendWeight, size: 13),
              ),
          ],
        ),
      ),
    );
  }
}

class _GainLine extends StatelessWidget {
  const _GainLine({
    required this.gain,
    required this.chart,
    required this.muted,
  });

  final AllocationGain gain;
  final ChartPalette chart;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final tone = switch (gain.trend) {
      'up' => chart.barGain,
      'down' => chart.barLoss,
      _ => muted,
    };
    final glyph = switch (gain.trend) {
      'up' => '▲',
      'down' => '▼',
      _ => '—',
    };
    // One text, two spans: a narrow card wraps the period onto the next
    // line rather than overflowing a row of two.
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$glyph ${gain.amountDisplay} (${gain.percentDisplay})',
            style: ChartText.legendFigure(tone, size: 12.5),
          ),
          TextSpan(
            text: '  ${gain.period}',
            style: ChartText.legendFigure(muted, size: 12),
          ),
        ],
      ),
    );
  }
}
