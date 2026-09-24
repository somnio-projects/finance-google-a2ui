import 'package:finance_app/features/catalog/view/catalog_card.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The card grid: three columns at the design's width, two on a tablet, one
/// on a phone, 16 apart. Each row's cards stretch to the tallest, which is
/// what the design's CSS grid does and what a `Wrap` would not.
class CatalogGrid extends StatelessWidget {
  /// Creates the grid over [entries], in the order the backend listed them.
  const CatalogGrid({required this.entries, super.key});

  /// The gap between cards, both ways.
  static const double gap = 16;

  /// Below this width the grid drops to two columns.
  static const double threeColumnsFrom = 900;

  /// Below this width the grid drops to one column.
  static const double twoColumnsFrom = 600;

  /// The entries with a registered component, in arrival order (N-10).
  final List<CatalogEntry> entries;

  /// How many columns fit in [width].
  static int columnsFor(double width) => width >= threeColumnsFrom
      ? 3
      : width >= twoColumnsFrom
      ? 2
      : 1;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = columnsFor(constraints.maxWidth);
      final rows = <List<CatalogEntry>>[];
      for (var start = 0; start < entries.length; start += columns) {
        rows.add(
          entries.sublist(
            start,
            start + columns > entries.length ? entries.length : start + columns,
          ),
        );
      }
      return Column(
        children: <Widget>[
          for (final (index, row) in rows.indexed)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (var slot = 0; slot < columns; slot++) ...<Widget>[
                      if (slot > 0) const SizedBox(width: gap),
                      Expanded(
                        child: slot < row.length
                            ? CatalogCard(entry: row[slot])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
