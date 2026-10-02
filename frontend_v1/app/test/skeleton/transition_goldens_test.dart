// The page-shaped skeletons, as rasters.
//
// Spec frontend/0020 OD-8: unlike the six component skeletons, these four are
// composed from the page's own layout rather than measured off an artboard —
// there is no stylesheet to check them against. Counting blocks proves how
// many there are and proves nothing about where they sit, and "the skeleton
// occupies the layout the content will occupy" is the whole point of drawing
// one. That is exactly the claim `.claude/rules/frontend/testing.md` §6 keeps
// goldens for: a layout that reflowed.
//
// Deterministic because every one is pumped with reduced motion, which rests
// the shimmer band at mid-sweep (0015 OD-5) — an animating golden would be a
// different raster every run. They compare through the tolerant comparator in
// `flutter_test_config.dart`.
import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/activity/view/activity_first_run.dart';
import 'package:finance_app/features/catalog/view/catalog_loading.dart';
import 'package:finance_app/features/holdings/view/holdings_first_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Without a boundary `matchesGoldenFile` walks up to the whole surface.
const Key boundary = Key('golden-subject');

Widget _framed(Widget page) => RepaintBoundary(key: boundary, child: page);

void main() {
  group('transition-state goldens (spec frontend/0020)', () {
    const phone = Size(390, 844);
    const board = Size(1024, 900);

    Future<void> shoot(
      WidgetTester tester,
      Widget page,
      String name, {
      Size size = phone,
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpApp(
        _framed(page),
        componentRegistry: buildComponentRegistry(),
        surfaceSize: size,
        brightness: brightness,
        reducedMotion: true,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    testWidgets('the Holdings tab, light', (tester) async {
      await shoot(tester, const HoldingsFirstRun(), 'holdings_first_run_light');
    });

    testWidgets('the Holdings tab, dark', (tester) async {
      await shoot(
        tester,
        const HoldingsFirstRun(),
        'holdings_first_run_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('the Activity tab, light', (tester) async {
      await shoot(tester, const ActivityFirstRun(), 'activity_first_run_light');
    });

    testWidgets('the Activity tab, dark', (tester) async {
      await shoot(
        tester,
        const ActivityFirstRun(),
        'activity_first_run_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('the catalog index', (tester) async {
      await shoot(
        tester,
        const CatalogIndexLoading(),
        'catalog_index_loading',
        size: board,
      );
    });

    testWidgets('a catalog detail page', (tester) async {
      await shoot(
        tester,
        const CatalogDetailLoading(),
        'catalog_detail_loading',
        size: board,
      );
    });
  });
}
