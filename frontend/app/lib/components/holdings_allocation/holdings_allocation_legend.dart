import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend_row.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';

/// The legend beside the donut: one row per category, in payload order.
///
/// Column order and metrics are the design's, measured from the rendered
/// page: a 10 px swatch at a 3 px radius, a 10 px gap, the label, the weight,
/// a flexible spacer, then the value — so the names read left-aligned and the
/// money right-aligned down the card.
class HoldingsAllocationLegend extends StatelessWidget {
  /// Creates the legend.
  const HoldingsAllocationLegend({
    required this.categories,
    this.onCategoryTap,
    this.selectedIndex,
    super.key,
  });

  /// The swatch's side, in logical pixels, as the design draws it.
  static const double swatchSize = 10;

  /// The swatch's corner radius, as the design draws it.
  static const double swatchRadius = 3;

  /// The vertical padding on each row, as the design draws it.
  static const double rowPadding = 6;

  /// The gap between a row's columns, as the design draws it.
  static const double columnGap = 10;

  /// The rows to draw, in the order the backend sent them (N-10).
  final List<AllocationCategory> categories;

  /// Called with a category's index when the reader taps its row.
  final void Function(int index)? onCategoryTap;

  /// The row drawn as selected, if any.
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (var index = 0; index < categories.length; index++)
        AllocationLegendRow(
          category: categories[index],
          index: index,
          selected: index == selectedIndex,
          onTap: onCategoryTap,
        ),
    ],
  );
}
