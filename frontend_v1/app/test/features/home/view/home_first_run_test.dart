import 'package:finance_app/charts/sparkline_chart.dart';
import 'package:finance_app/components/portfolio_summary/home_hero.dart';
import 'package:finance_app/components/portfolio_summary/home_hero_loading.dart';
import 'package:finance_app/components/portfolio_summary/home_range_selector.dart';
import 'package:finance_app/features/home/view/home_first_run.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/catalog_snapshot.dart';
import '../../../helpers/pump_app.dart';

void main() {
  group(HomeFirstRun, () {
    testWidgets('lays the page out as shimmer, with one caption', (
      tester,
    ) async {
      await tester.pumpApp(
        const HomeFirstRun(),
        surfaceSize: const Size(390, 1200),
      );
      // Header (4) · hero label, total, change, spark, range (5) · card,
      // questions, movers (3).
      expect(find.byType(SkeletonShimmer), findsNWidgets(12));
      expect(find.byType(HomeHeroLoading), findsOneWidget);
      expect(find.text(HomeHeroLoading.caption), findsOneWidget);
      // No word the backend owns is on screen before it has spoken.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('draws under the dark theme', (tester) async {
      await tester.pumpApp(
        const HomeFirstRun(),
        brightness: Brightness.dark,
        surfaceSize: const Size(390, 1200),
      );
      expect(find.byType(HomeFirstRun), findsOneWidget);
    });
  });

  group('HomeHero while loading', () {
    testWidgets('keeps the total and shimmers the change and the sparkline', (
      tester,
    ) async {
      final payload = ViewPayload.fromJson(
        CatalogSnapshot.load().exampleFor('PortfolioSummary'),
      );
      await tester.pumpApp(
        HomeHero(
          payload: payload,
          range: '1m',
          loading: true,
          onRangeSelected: (_) {},
        ),
        surfaceSize: const Size(390, 600),
      );
      expect(find.text(r'$482,915.20'), findsOneWidget);
      expect(find.text('Total portfolio value'), findsOneWidget);
      expect(find.byType(HomeHeroLoading), findsOneWidget);
      expect(find.byType(SparklineChart), findsNothing);
      expect(find.textContaining('+0.46%', findRichText: true), findsNothing);
      // The range strip stays, so the person can change their mind.
      expect(find.byType(HomeRangeSelector), findsOneWidget);
      final spark = tester.widget<SkeletonShimmer>(
        find.byType(SkeletonShimmer).last,
      );
      expect(spark.height, HomeHeroLoading.sparkHeight);
    });
  });
}
