import 'package:finance_app/components/holdings_allocation/holdings_allocation_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'holdings_allocation_toggle_harness.dart';

/// How the toggle *looks*, as opposed to what it does — the seam is asserted
/// in `holdings_allocation_toggle_test.dart`. Split when the two together
/// passed the 150-line budget, by subject rather than into a part two.
void main() {
  group(HoldingsAllocationToggle, () {
    for (final (brightness, hasBorder) in <(Brightness, bool)>[
      (Brightness.light, false),
      (Brightness.dark, true),
    ]) {
      testWidgets('outlines the lit segment only on $brightness', (
        tester,
      ) async {
        // On the dark artboard the selected segment is *darker* than the
        // track, so the design adds `border/primary` to keep its edge
        // readable. The light one has no border at all, and drawing one there
        // would be an invention — which is why both halves are asserted: a
        // widget that always drew a border would pass a dark-only check.
        await tester.pumpApp(
          editableAllocation(<SentOption>[]),
          surfaceSize: desktopSurface,
          brightness: brightness,
        );
        final lit = allocationData().groups.firstWhere((g) => g.selected);
        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text(lit.label),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );

        expect(
          (box.decoration as BoxDecoration).border,
          hasBorder ? isNotNull : isNull,
        );
      });
    }
  });
}
