import 'package:finance_app/components/taxlots_table/taxlot_dashed_box.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:flutter/material.dart';

/// What the card shows when the sale consumes no lots.
///
/// A dashed square and one sentence. The sentence is **chrome, not data** —
/// the payload has no field for it, and a view with an empty `lots` array is
/// a valid answer rather than a contract violation, so nothing is raised
/// here.
///
/// The UI Kit's tax-lot frame draws no empty state, so this keeps the shape
/// the earlier artboard gave it (spec `frontend/0003`) in the new palette.
/// Inventing one from the kit's other pages would be a design decision made
/// in Dart.
class TaxLotsTableEmpty extends StatelessWidget {
  /// Creates the empty state.
  const TaxLotsTableEmpty({super.key});

  /// The sentence the design writes.
  static const String message = 'No lots for this position.';

  @override
  Widget build(BuildContext context) {
    final palette = TaxLotPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: TaxLotMetrics.placeholderPadding,
      ),
      child: Column(
        children: <Widget>[
          CustomPaint(
            size: const Size.square(TaxLotMetrics.placeholderSize),
            painter: TaxLotDashedBoxPainter(
              color: palette.placeholderBorder,
              radius: TaxLotMetrics.placeholderRadius,
              strokeWidth: TaxLotMetrics.checkBoxBorderWidth,
            ),
          ),
          const SizedBox(height: TaxLotMetrics.placeholderGap),
          Text(message, style: TaxLotType.placeholder(palette.mutedText)),
        ],
      ),
    );
  }
}
