import 'package:finance_app/components/holdings_allocation/holdings_allocation_header.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_header_row.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'holdings_allocation_toggle_harness.dart';

/// Where the toggle sits relative to the header (GGU-145).
///
/// Its own file rather than a third group in the toggle's suite, because it
/// is the half that kept being answered by guesswork. The first version put
/// the two side by side and ellipsised the total in the Assistant; the second
/// added a 480 px breakpoint to fix that, which was a number nobody had
/// measured. Figma's `Header` frame is `Flujo Vertical` on **both** the 360
/// and the 640 artboard, so there is no arrangement to switch between — which
/// is what these two assert, at those two widths.
void main() {
  group(HoldingsAllocationHeaderRow, () {
    for (final (name, size) in const <(String, Size)>[
      ("the artboard's width", desktopSurface),
      ("the Assistant's column", Size(420, 900)),
    ]) {
      testWidgets('keeps the toggle on its own line at $name', (tester) async {
        await tester.pumpApp(
          editableAllocation(<SentOption>[]),
          surfaceSize: size,
        );
        final header = tester.getTopLeft(find.byType(HoldingsAllocationHeader));
        final toggle = tester.getTopLeft(find.byType(HoldingsAllocationToggle));

        expect(toggle.dy, greaterThan(header.dy));
        expect(toggle.dx, header.dx);
      });
    }

    testWidgets('leaves the title room to breathe beside the gain', (
      tester,
    ) async {
      // The one thing the title row can still get wrong: the gain is on the
      // same line, and a title that took the whole width would push it off.
      // Both are on screen, and neither overlaps the other.
      await tester.pumpApp(
        editableAllocation(<SentOption>[]),
        surfaceSize: const Size(420, 900),
      );
      final title = tester.getRect(find.text(allocationData().title));
      final gain = tester.getRect(
        find.textContaining('all-time', findRichText: true),
      );

      expect(title.right, lessThanOrEqualTo(gain.left));
    });
  });
}
