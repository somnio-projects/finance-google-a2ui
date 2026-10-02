import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/holdings_allocation/allocation_gain.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_center.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:finance_app/components/holdings_allocation/holdings_summary_tokens.dart';
import 'package:flutter/material.dart';

/// The card's title row: the title, and the all-time gain opposite it.
///
/// **The total is not here any more (GGU-145).** The design puts it inside
/// the ring, which is where the eye goes on a donut card, and leaves this row
/// as a caption and a verdict. [HoldingsAllocationTotalCenter] draws it.
class HoldingsAllocationHeader extends StatelessWidget {
  /// Creates the row.
  const HoldingsAllocationHeader({required this.data, super.key});

  /// The gap kept between the title and the gain when both are on one line.
  static const double gap = 12;

  /// The model.
  final AllocationData data;

  @override
  Widget build(BuildContext context) {
    final text = HoldingsSummaryText.of(context);
    final gain = data.totalGain;
    return Semantics(
      container: true,
      header: true,
      // The ring's count is read out here because the catalog card draws the
      // total in its place and `center.*` would otherwise go unspoken — the
      // payload's words still reach a person, which is what N-9 is about.
      label: <String>[
        data.title,
        data.totalLabel,
        data.totalDisplay,
        if (data.centerCount.isNotEmpty)
          '${data.centerCount} ${data.centerUnit}',
      ].join(' '),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Flexible(
              child: Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HoldingsSummaryText.title(text.primary),
              ),
            ),
            if (gain != null) ...<Widget>[
              const SizedBox(width: gap),
              Flexible(
                child: _GainLine(gain: gain, muted: text.secondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GainLine extends StatelessWidget {
  const _GainLine({required this.gain, required this.muted});

  /// The figure's size, `font-size/13` on the `Default, Light, Desktop`
  /// artboard, at `Peso 500`.
  static const double size = 13;

  final AllocationGain gain;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final chart = ChartPalette.of(context);
    final tone = switch (gain.trend) {
      'up' => chart.barGain,
      'down' => chart.barLoss,
      _ => muted,
    };
    // One text, two spans: a narrow card wraps the period onto the next
    // line rather than overflowing a row of two.
    return Text.rich(
      textAlign: TextAlign.end,
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '${gain.amountDisplay} (${gain.percentDisplay})',
            style: TextStyle(
              color: tone,
              fontSize: size,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: ' ${gain.period}',
            style: TextStyle(color: muted, fontSize: size),
          ),
        ],
      ),
    );
  }
}
