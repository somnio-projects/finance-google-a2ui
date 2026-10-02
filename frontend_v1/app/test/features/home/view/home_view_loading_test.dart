import 'dart:async';

import 'package:finance_app/charts/sparkline_chart.dart';
import 'package:finance_app/components/portfolio_summary/home_hero_loading.dart';
import 'package:finance_app/features/home/view/home_first_run.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'home_harness.dart';

void main() {
  group('$HomePage while loading', () {
    late HomeHarness home;

    setUp(() {
      home = HomeHarness();
    });

    testWidgets('draws the page as shimmer before the first payload', (
      tester,
    ) async {
      await home.pump(tester, settle: false);
      // Spec 0015 OD-2: the first paint is the page's own shape, not a
      // spinner in a void.
      expect(find.byType(HomeFirstRun), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(HomeFirstRun), findsNothing);
    });

    testWidgets('a range change keeps the total and shimmers the rest', (
      tester,
    ) async {
      await home.pump(tester);
      final pending = Completer<Result<RenderedViews>>();
      when(
        () => home.repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>['portfolio.summary.v1'],
          options: <String, String>{'range': '1m'},
        ),
      ).thenAnswer((_) => pending.future);
      await tester.tap(find.text('1M'));
      await tester.pump();
      // The design's L2: the figure the person has stays, the change and
      // the sparkline give way to the shimmer (spec 0015 OD-1).
      expect(find.text(r'$482,915.20'), findsOneWidget);
      expect(find.byType(HomeHeroLoading), findsOneWidget);
      expect(find.byType(SparklineChart), findsNothing);
      pending.complete(Ok(home.envelope('portfolio.summary.v1', home.summary)));
      await tester.pumpAndSettle();
      expect(find.byType(HomeHeroLoading), findsNothing);
      expect(find.byType(SparklineChart), findsOneWidget);
    });
  });
}
