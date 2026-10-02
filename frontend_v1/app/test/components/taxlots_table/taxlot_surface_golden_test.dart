import 'package:finance_app/components/taxlots_table/taxlots_table_skeleton.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taxlot_golden_frame.dart';

/// Goldens for the two surfaces that carry no text of their own (AC-8).
///
/// Both are shot whole rather than cropped, for the same reason: there is
/// nothing in either frame for a platform to lay out differently. The card
/// plane is empty by construction, and the kit draws the loading state with
/// no text at all — which is also why the waterfall's loading goldens are
/// portable (spec `frontend/0027` OD-10).
void main() {
  group('TaxLotTable surface goldens', () {
    /// The empty plane, with room around it for the shadow to fall into.
    Widget plane() => const RepaintBoundary(
      key: goldenSubject,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: SizedBox(
          width: 240,
          child: TaxLotsTableSurface(child: SizedBox(height: 80)),
        ),
      ),
    );

    Widget skeleton() => const RepaintBoundary(
      key: goldenSubject,
      child: SizedBox(width: 600, child: TaxLotsTableSkeleton()),
    );

    testWidgets('the card plane, light', (tester) async {
      // The kit's card carries no hairline: what separates it from the page
      // is the surface and a soft shadow, and an empty plane is the only
      // frame of it with no text in the way.
      await shootGolden(tester, plane(), 'taxlot_surface');
    });

    testWidgets('the card plane, dark', (tester) async {
      await shootGolden(
        tester,
        plane(),
        'taxlot_surface_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('the loading state, light', (tester) async {
      await shootGolden(tester, skeleton(), 'taxlot_skeleton');
    });

    testWidgets('the loading state, dark', (tester) async {
      await shootGolden(
        tester,
        skeleton(),
        'taxlot_skeleton_dark',
        brightness: Brightness.dark,
      );
    });
  });
}
