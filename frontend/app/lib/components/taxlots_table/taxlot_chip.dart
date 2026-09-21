import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:flutter/material.dart';

/// A rounded pill carrying one server-written string.
///
/// The design draws three of them at three sizes — the legend key, the term
/// marker on a row, and the two split figures in the footer — and they
/// differ only in padding, type and whether they carry a hairline. One
/// widget with those as parameters keeps the corner radius and the shape in
/// a single place, which is what stops the third one drifting.
///
/// [label] is always a string the backend wrote. Nothing is appended to it
/// and nothing is formatted here (N-1).
class TaxLotChip extends StatelessWidget {
  /// Creates a pill.
  const TaxLotChip({
    required this.label,
    required this.background,
    required this.padding,
    required this.style,
    this.border,
    super.key,
  });

  /// The text, verbatim.
  final String label;

  /// The fill.
  final Color background;

  /// The inset, which differs per site — see [TaxLotMetrics].
  final EdgeInsets padding;

  /// The type, already tinted — see `TaxLotType`, whose roles are
  /// functions of their colour.
  final TextStyle style;

  /// The hairline, drawn only by the legend.
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final edge = border;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: TaxLotMetrics.chipBorderRadius,
        border: edge == null ? null : Border.all(color: edge),
      ),
      child: Padding(
        padding: padding,
        child: Text(label, style: style),
      ),
    );
  }
}
