import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/donut_chart.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_bar.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_center.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_empty.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_header.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';

/// The `HoldingsSummary` card: header (unless a shell draws it), the ring
/// with its centre count, the legend, and the stacked bar (spec 0026 §2).
class HoldingsAllocationCard extends StatefulWidget {
  /// Creates the card.
  const HoldingsAllocationCard({
    required this.data,
    this.initialSelectedIndex,
    super.key,
  });

  /// Corner radius.
  static const double radius = 16;

  /// Inner padding.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 16, 18, 16);

  /// Gap between ring and legend.
  static const double chartGap = 22;

  /// Below this width the ring stacks above the legend.
  static const double stackBelowWidth = 340;

  /// Ring size when stacked.
  static const double stackedDiameter = 112;

  /// Ring size beside a legend when a shell draws the header — the Home
  /// card's 104. The catalog card keeps [DonutChart.designDiameter].
  static const double compactDiameter = 104;

  /// The model.
  final AllocationData data;

  /// A slice to start selected, for goldens.
  final int? initialSelectedIndex;

  @override
  State<HoldingsAllocationCard> createState() => _HoldingsAllocationCardState();
}

class _HoldingsAllocationCardState extends State<HoldingsAllocationCard> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final data = widget.data;
    final body = data.isEmpty
        ? const HoldingsAllocationEmpty()
        : LayoutBuilder(builder: _body);
    if (!data.headline) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(HoldingsAllocationCard.radius),
      ),
      child: Padding(
        padding: HoldingsAllocationCard.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            HoldingsAllocationHeader(data: data),
            const SizedBox(height: 14),
            body,
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, BoxConstraints constraints) {
    final data = widget.data;
    final ramp = AllocationPalette.of(context).rampFor(data.groupBy);
    final stacked =
        constraints.maxWidth < HoldingsAllocationCard.stackBelowWidth;
    final chart = DonutChart(
      weights: data.weights,
      selectedIndex: _selectedIndex,
      onSliceTap: _select,
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
      selectedIndex: _selectedIndex,
      onCategoryTap: _select,
      swatches: ramp,
    );
    final bar = Padding(
      padding: const EdgeInsets.only(top: 16),
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

  void _select(int index) =>
      setState(() => _selectedIndex = _selectedIndex == index ? null : index);
}
