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
/// tint (`#EBF1FF` → `#EBF1FE`) moves 32.5 % of this frame and 32.5 % of the
/// phone one; the same error on a whole-card golden moves well under 1 %,
/// which is under the tolerance and therefore invisible.
void main() {
  group('TaxLotTable row-chrome goldens', () {
    /// The widest a row can be before its first text cell begins: the rail,
    /// the tick box and the two gaps around them.
    const tableChrome = TaxLotColumns.leadingWidth + TaxLotMetrics.railGap;

    /// The same for the phone block — and it stops **before** the tick box,
    /// which is the narrower frame on purpose.
    ///
    /// A horizontal crop applies to the whole height, and a block is two
    /// lines: the box sits on the first, but under it the four-cell grid
    /// starts at the rail's own gap, because `tilePadding` insets vertically
    /// only. Framing to the box therefore put 16 px of the *Shares* caption
    /// and its figure in shot, and that is what failed on the Linux runner
    /// at 4.54 % after the whole-card frames were already cropped away
    /// (spec `frontend/0027` OD-10). The rail and its band are the full
    /// height of the claim; the box and its tick are asserted on the canvas
    /// in `taxlot_sold_mark_test.dart`, where emptying `paint` turns them
    /// red.
    const phoneChrome = TaxLotMetrics.railWidth + TaxLotMobileMetrics.railGap;

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
          unitsLabel: 'Quantity',
          costBasisLabel: 'Cost basis',
          proceedsLabel: 'Proceeds',
        ),
        const SizedBox(height: TaxLotMobileMetrics.tileGap),
        TaxLotMobileTile(
          lot: lot(term: TaxLotTerm.short, termLabel: 'Short-term'),
          unitsLabel: 'Quantity',
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

    testWidgets('the phone block rail and its band', (tester) async {
      // The phone form's rail is 80 px on a 4 px gap — a different rhythm
      // from the table's, and the one thing about it a picture can hold.
      // Beside it, the 8 px band carries the consumed lot's tint for the
      // block's whole height, which is the other half of this frame.
      await shootGolden(
        tester,
        croppedFrame(width: 328, crop: phoneChrome, child: blocks()),
        'taxlot_rails_phone',
      );
    });
  });
}
