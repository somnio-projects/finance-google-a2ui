import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:flutter/material.dart';

/// A rounded pill carrying one server-written string.
///
/// The kit draws three of them — the legend key, the term marker on a row,
/// and the two split figures in the footer — and they differ only in padding
/// and type. One widget with those as parameters keeps the corner radius and
/// the shape in a single place, which is what stops the third one drifting.
///
/// [label] is always text the backend wrote, and nothing here formats it
/// (N-1). The footer's caller passes **two** server strings joined by a
/// space (`'+$26,679.60 Long-term'`) — a join of two payload values, which
/// is what the kit's `$4,100 LT` costs while `LT` stays uncoined (OD-5).
class TaxLotChip extends StatelessWidget {
  /// Creates a pill.
  const TaxLotChip({
    required this.label,
    required this.background,
    required this.padding,
    required this.style,
    super.key,
  });

  /// The text, verbatim.
  final String label;

  /// The fill.
  final Color background;

  /// The inset, which differs per site — see [TaxLotMetrics].
  final EdgeInsets padding;

  /// The type, already tinted — see `TaxLotType`, whose roles are functions
  /// of their colour.
  final TextStyle style;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: TaxLotMetrics.chipBorderRadius,
    ),
    child: Padding(
      padding: padding,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: style,
      ),
    ),
  );
}
