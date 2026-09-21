import 'package:finance_app/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// One allocation row, already formatted by the backend.
///
/// Every field is a `String` on purpose. There is no `double` here to be
/// tempted into arithmetic with, which is prohibition N-2 made structural
/// rather than remembered.
@immutable
class HoldingsAllocationRow {
  /// Creates a row.
  const HoldingsAllocationRow({
    required this.categoryKey,
    required this.label,
    required this.valueDisplay,
    required this.weightDisplay,
  });

  /// The payload's `key`, e.g. `BTC` — or `other` for the residual bucket the
  /// backend adds and the client never computes.
  final String categoryKey;

  /// The payload's `label`, e.g. `Bitcoin`.
  final String label;

  /// The payload's `value.display`, e.g. `$38,550.00`.
  final String valueDisplay;

  /// The payload's `weight.display`, e.g. `59.27%`.
  final String weightDisplay;
}

/// Renders `holdings.allocation.v1` as a total plus a legend of rows.
///
/// The catalog names this view's A2UI component `AllocationSummary`. The arc
/// itself needs the raw `weight.value` for geometry — a legitimate use of
/// the raw member under N-4 — and lands with the charting ticket; a legend
/// that shows every figure correctly is the honest skeleton until then.
class HoldingsAllocationCard extends StatelessWidget {
  /// Creates the card.
  const HoldingsAllocationCard({
    required this.title,
    required this.totalLabel,
    required this.totalDisplay,
    required this.categories,
    super.key,
  });

  /// The payload's `title`.
  final String title;

  /// The payload's `total.label`.
  final String totalLabel;

  /// The payload's `total.amount.display`.
  final String totalDisplay;

  /// The payload's `categories`, in the order the backend sent them.
  final List<HoldingsAllocationRow> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppSpacing.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleLarge),
            SizedBox(height: spacing.sm),
            Semantics(
              container: true,
              label: '$totalLabel $totalDisplay',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(totalLabel, style: theme.textTheme.bodyMedium),
                    Text(totalDisplay, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ),
            Divider(height: spacing.lg),
            for (final row in categories)
              _AllocationRowTile(row: row, spacing: spacing),
          ],
        ),
      ),
    );
  }
}

class _AllocationRowTile extends StatelessWidget {
  const _AllocationRowTile({required this.row, required this.spacing});

  final HoldingsAllocationRow row;
  final AppSpacing spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '${row.label} ${row.valueDisplay} ${row.weightDisplay}',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xs),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(row.label, style: theme.textTheme.bodyLarge),
              ),
              Text(row.valueDisplay, style: theme.textTheme.bodyLarge),
              SizedBox(width: spacing.md),
              SizedBox(
                width: 64,
                child: Text(
                  row.weightDisplay,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
