import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/donut_chart.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_bar.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_center.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';

/// The donut, the legend and the stacked bar, side by side or stacked.
///
/// Split out of the card when GGU-145 added the grouping toggle and the card
/// passed the 150-line budget. The seam is the card's own: the card owns the
/// chrome, the header and the selection; this owns where the three pieces sit
/// at a given width.
class HoldingsAllocationLayout extends StatelessWidget {
  /// Creates the layout.
  const HoldingsAllocationLayout({
    required this.data,
    required this.constraints,
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  /// Gap above the stacked bar.
  static const double barGap = 16;

  /// The model.
  final AllocationData data;

  /// The width the card was given, which decides whether it stacks.
  final BoxConstraints constraints;

  /// The slice a tap selected, or null.
  final int? selectedIndex;

  /// Called with the index a slice or a legend row was tapped at.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ramp = AllocationPalette.of(context).rampFor(data.groupBy);
    final stacked =
        constraints.maxWidth < HoldingsAllocationCard.stackBelowWidth;
    final chart = DonutChart(
      weights: data.weights,
      selectedIndex: selectedIndex,
      onSliceTap: onSelect,
      swatches: ramp,
      center: HoldingsAllocationCenter(
        count: data.centerCount,
        unit: data.centerUnit,
      ),
      diameter: stacked
          ? HoldingsAllocationCard.stackedDiameter
          : data.headline
          ? DonutChart.designDiameter
          : HoldingsAllocationCard.compactDiameter,
    );
    final legend = HoldingsAllocationLegend(
      categories: data.categories,
      selectedIndex: selectedIndex,
      onCategoryTap: onSelect,
      swatches: ramp,
    );
    final bar = Padding(
      padding: const EdgeInsets.only(top: barGap),
      child: HoldingsAllocationBar(weights: data.weights, colors: ramp),
    );
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(child: chart),
          const SizedBox(height: HoldingsAllocationCard.chartGap),
          legend,
          bar,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            chart,
            const SizedBox(width: HoldingsAllocationCard.chartGap),
            Expanded(child: legend),
          ],
        ),
        bar,
      ],
    );
  }
}
