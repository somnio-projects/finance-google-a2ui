import 'package:finance_app/features/catalog/view/catalog_board.dart';
import 'package:finance_app/features/catalog/view/catalog_grid.dart';
import 'package:finance_app/features/catalog/view/catalog_loading.dart';
import 'package:finance_app/features/catalog/view/catalog_top_bar.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group(CatalogIndexLoading, () {
    testWidgets('keeps the board and its bar, and shimmers the rest', (
      tester,
    ) async {
      await tester.pumpApp(
        const CatalogIndexLoading(),
        surfaceSize: const Size(1024, 1400),
        reducedMotion: true,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CatalogBoard), findsOneWidget);
      // The bar is the page's own chrome, so it is real, not a placeholder.
      expect(find.text(CatalogTopBar.title), findsOneWidget);
      // Header, subtitle, legend, and one block per card.
      expect(
        find.byType(SkeletonShimmer),
        findsNWidgets(3 + CatalogIndexLoading.cardCount),
      );
    });

    testWidgets("lays the cards out in the grid's own column count", (
      tester,
    ) async {
      // Asserted as *geometry*, not as a count: nine blocks appear at every
      // width, because six cards divide by one, two and three alike. Pinning
      // the count would have left `columns: 1` green at 1024 — measured.
      // The claim is that the placeholder reflows exactly where the real grid
      // does, so what must be checked is where the second card sits.
      Future<double> secondCardTop(Size size) async {
        await tester.pumpApp(
          const CatalogIndexLoading(),
          surfaceSize: size,
          reducedMotion: true,
        );
        await tester.pumpAndSettle();
        final cards = find.byType(SkeletonShimmer);
        // Three blocks precede the grid: title, subtitle, legend.
        return tester.getTopLeft(cards.at(4)).dy -
            tester.getTopLeft(cards.at(3)).dy;
      }

      // At the design's width the second card is beside the first.
      expect(CatalogGrid.columnsFor(1024), equals(3));
      expect(await secondCardTop(const Size(1024, 1600)), isZero);
      // On a phone it is below it, a card plus the grid's gap down.
      expect(CatalogGrid.columnsFor(390), equals(1));
      expect(
        await secondCardTop(const Size(390, 2400)),
        equals(CatalogIndexLoading.cardHeight + CatalogGrid.gap),
      );
    });
  });

  group(CatalogDetailLoading, () {
    testWidgets('shimmers the header and the three zones', (tester) async {
      await tester.pumpApp(
        const CatalogDetailLoading(),
        surfaceSize: const Size(1024, 1400),
        reducedMotion: true,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CatalogBoard), findsOneWidget);
      expect(find.text(CatalogTopBar.title), findsOneWidget);
      // Title, subtitle, Zone 1, Zones 2 and 3.
      expect(
        find.byType(SkeletonShimmer),
        findsNWidgets(2 + 1 + CatalogDetailLoading.sideHeights.length),
      );
    });
  });
}
