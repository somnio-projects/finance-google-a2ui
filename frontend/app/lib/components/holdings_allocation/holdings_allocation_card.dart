import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/donut_chart.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_empty.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_header.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';

/// Renders `holdings.allocation.v1` as the design's card.
///
/// The chrome is the design's, measured from the rendered catalog page: a
/// 16 px radius, a 1 px hairline, and 16/18 padding. Selection is **local
/// state** — tapping an arc or a legend row marks it and nothing leaves the
/// widget, because the frozen catalog gives this view `"actions": []` and
/// there is nothing to dispatch.
class HoldingsAllocationCard extends StatefulWidget {
  /// Creates the card.
  const HoldingsAllocationCard({
    required this.data,
    this.initialSelectedIndex,
    super.key,
  });

  /// The card's corner radius, measured from the design.
  static const double radius = 16;

  /// The card's padding, measured from the design (`padding:16px 18px`).
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 16, 18, 16);

  /// The gap between the ring and its legend, measured from the design.
  static const double chartGap = 22;

  /// Below this content width the card stacks the ring above the legend.
  ///
  /// Interpolated, not measured directly: the design lays the ring **beside**
  /// the legend in its primary card (~400 px of content) and **above** it in
  /// both secondary cards (~300 px), so the switch is somewhere between. 340
  /// is the midpoint, and it is the one number on this card the design does
  /// not pin — `specs/frontend/0007` OD-3 carries it.
  static const double stackBelowWidth = 340;

  /// The ring's diameter when the card stacks, as the design's secondary
  /// cards draw it.
  static const double stackedDiameter = 112;

  /// What to draw.
  final AllocationData data;

  /// The category selected before any tap, which is how a test and a golden
  /// reach the selected state without driving a gesture.
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
            HoldingsAllocationHeader(data: widget.data),
            const SizedBox(height: 14),
            if (widget.data.isEmpty)
              const HoldingsAllocationEmpty()
            else
              LayoutBuilder(builder: _body),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, BoxConstraints constraints) {
    final stacked =
        constraints.maxWidth < HoldingsAllocationCard.stackBelowWidth;
    final chart = DonutChart(
      weights: widget.data.weights,
      selectedIndex: _selectedIndex,
      onSliceTap: _select,
      diameter: stacked
          ? HoldingsAllocationCard.stackedDiameter
          : DonutChart.designDiameter,
    );
    final legend = HoldingsAllocationLegend(
      categories: widget.data.categories,
      selectedIndex: _selectedIndex,
      onCategoryTap: _select,
    );
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(child: chart),
          const SizedBox(height: HoldingsAllocationCard.chartGap),
          legend,
        ],
      );
    }
    return Row(
      children: <Widget>[
        chart,
        const SizedBox(width: HoldingsAllocationCard.chartGap),
        Expanded(child: legend),
      ],
    );
  }

  /// Toggles the selection, so tapping the selected slice clears it.
  void _select(int index) =>
      setState(() => _selectedIndex = _selectedIndex == index ? null : index);
}
