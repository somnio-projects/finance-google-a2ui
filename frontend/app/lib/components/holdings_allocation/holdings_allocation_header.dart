import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';

/// The card's header: the caption, the headline total, and the total's label.
///
/// The design's header is three stacked lines — a small uppercase caption, a
/// 30 px figure, then a 13 px line. Its own copy fills them with the state
/// name, the portfolio value and an **all-time gain** (`▲ +$61,204 (+14.5%)`),
/// coloured green or red.
///
/// `holdings.allocation.v1` carries no gain, no percentage and no period, so
/// the third line carries `total.label` in the muted mark instead. Inventing
/// the gain would mean computing a figure (N-1) from fields the payload does
/// not have (N-3); colouring it would mean the client deciding a sign. The
/// slot is the design's, the content is the contract's, and
/// `specs/frontend/0007` OD-1 carries the backend fields that would let the
/// two meet.
class HoldingsAllocationHeader extends StatelessWidget {
  /// Creates the header.
  const HoldingsAllocationHeader({required this.data, super.key});

  /// The gap between the caption and the headline, measured from the design.
  static const double captionGap = 6;

  /// The gap between the headline and the line under it, measured.
  static const double headlineGap = 4;

  /// What to draw.
  final AllocationData data;

  @override
  Widget build(BuildContext context) {
    final chart = ChartPalette.of(context);
    final palette = AllocationPalette.of(context);
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
