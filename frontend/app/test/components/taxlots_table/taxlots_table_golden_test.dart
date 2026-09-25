import 'package:finance_app/components/taxlots_table/taxlot_columns.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taxlot_golden_frame.dart';
import 'taxlots_table_harness.dart';

/// Goldens for a row's chrome: the rail, the tick box and the tint (AC-8).
///
/// Each frame is the left edge of a row, cut at the point its first **text**
/// cell begins — computed from the layout's own constants, so a grid change
/// moves the frame rather than letting a caption drift into shot. What these
/// no longer prove (the captions, the column order, the figures) is asserted
/// on the widget tree in `taxlots_table_card_test.dart`, where a failure
/// names the defect instead of saying only that something moved.
///
/// **Cropping made them stronger.** A one-step error on the selected-row
/// tint (`#EBF1FF` → `#EBF1FE`) moves 32.5 % of this frame and 26.9 % of the
/// phone one; the same error on a whole-card golden moves well under 1 %,
/// which is under the tolerance and therefore invisible.
void main() {
  group('TaxLotTable row-chrome goldens', () {
    /// The widest a row can be before its first text cell begins: the rail,
    /// the tick box and the two gaps around them.
    const tableChrome = TaxLotColumns.leadingWidth + TaxLotMetrics.railGap;

    /// The same for the phone block, whose date begins after the box.
    const phoneChrome =
        TaxLotMetrics.railWidth +
        TaxLotMobileMetrics.railGap +
        TaxLotMetrics.checkBoxSize;

    /// Four rows: a consumed long-term lot, an untouched one, and the same
    /// pair short-term — every combination the rail and the box can be in.
    Widget rows() => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final (index, lot) in <TaxLot>[
          lot(fullySold: true),
          lot(),
          lot(term: TaxLotTerm.short, termLabel: 'Short-term', fullySold: true),
          lot(term: TaxLotTerm.short, termLabel: 'Short-term'),
        ].indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: TaxLotMetrics.rowGap),
          TaxLotRowTile(lot: lot),
        ],
      ],
    );

    /// Two phone blocks, one consumed and one not.
    Widget blocks() => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TaxLotMobileTile(
          lot: lot(fullySold: true),
          costBasisLabel: 'Cost basis',
          proceedsLabel: 'Proceeds',
        ),
        const SizedBox(height: TaxLotMobileMetrics.tileGap),
        TaxLotMobileTile(
          lot: lot(term: TaxLotTerm.short, termLabel: 'Short-term'),
          costBasisLabel: 'Cost basis',
          proceedsLabel: 'Proceeds',
        ),
      ],
    );

    testWidgets('the rails, the boxes and the tint, light', (tester) async {
      // Proves: both rail colours and the 4 px width, the 41/8 row rhythm,
      // the tinted band of a consumed lot, the filled box with its painted
      // tick, and the hairline box of an untouched one.
      await shootGolden(
        tester,
        croppedFrame(width: 600, crop: tableChrome, child: rows()),
        'taxlot_rails',
      );
    });

    testWidgets('the rails, the boxes and the tint, dark', (tester) async {
      await shootGolden(
        tester,
        croppedFrame(width: 600, crop: tableChrome, child: rows()),
        'taxlot_rails_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('the phone block rail and tick', (tester) async {
      // The phone form's rail is 80 px on a 4 px gap — a different rhythm
      // from the table's, and the one thing about it a picture can hold.
      await shootGolden(
        tester,
        croppedFrame(width: 328, crop: phoneChrome, child: blocks()),
        'taxlot_rails_phone',
      );
    });
  });
}
