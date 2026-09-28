import 'package:finance_app/components/holdings_allocation/holdings_allocation_header.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_header_row.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'holdings_allocation_toggle_harness.dart';

/// Where the toggle sits relative to the header, at two widths (GGU-145).
///
/// Its own file rather than a third group in the toggle's suite: this is
/// about the **arrangement**, and it is the half that GGU-144 would have
/// caught earlier — the first version shared one row at every width and
/// ellipsised the total in the Assistant, whose column is nowhere near the
/// artboard's.
void main() {
  group(HoldingsAllocationHeaderRow, () {
    testWidgets('puts the toggle beside the header when there is room', (
      tester,
    ) async {
      // The design's own arrangement, at the artboard's width.
      await tester.pumpApp(
        editableAllocation(<SentOption>[]),
        surfaceSize: desktopSurface,
      );
      final header = tester.getTopLeft(find.byType(HoldingsAllocationHeader));
      final toggle = tester.getTopLeft(find.byType(HoldingsAllocationToggle));

      expect(toggle.dx, greaterThan(header.dx));
    });

    testWidgets('drops the toggle below the header when the column is narrow', (
      tester,
    ) async {
      // GGU-144's lesson one component later: the first version of this row
      // shared it at every width and ellipsised the total in the Assistant,
      // whose column is nowhere near the artboard's.
      await tester.pumpApp(
        editableAllocation(<SentOption>[]),
        surfaceSize: const Size(420, 900),
      );
      final header = tester.getTopLeft(find.byType(HoldingsAllocationHeader));
      final toggle = tester.getTopLeft(find.byType(HoldingsAllocationToggle));

      expect(toggle.dy, greaterThan(header.dy));
      expect(toggle.dx, header.dx);
    });
  });
}
