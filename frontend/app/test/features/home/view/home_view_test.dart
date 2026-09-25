import 'package:finance_app/charts/sparkline_chart.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'home_harness.dart';

void main() {
  group(HomePage, () {
    late HomeHarness home;

    setUp(() {
      home = HomeHarness();
    });

    Future<void> pump(WidgetTester tester) => home.pump(tester);

    testWidgets('binds the header and hero verbatim from the payload', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Good afternoon'), findsOneWidget);
      expect(find.text('Alex Chen'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Simulated portfolio'), findsOneWidget);
      expect(find.text('Total portfolio value'), findsOneWidget);
      expect(find.text(r'$482,915.20'), findsOneWidget);
      expect(
        find.text(r'▲ +$2,201.05 (+0.46%)  today', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(SparklineChart), findsOneWidget);
    });

    testWidgets('draws the allocation card, questions and movers', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Allocation by holding'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('Suggested questions'), findsOneWidget);
      expect(find.text('💬 What moved my portfolio today?'), findsOneWidget);
      expect(find.text('Top movers today'), findsOneWidget);
      expect(find.text('AVAX'), findsOneWidget);
      expect(find.text('Aave'), findsOneWidget);
      expect(find.text('▼ -4.4%'), findsOneWidget);
      expect(find.text(r'$41.80'), findsOneWidget);
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      await pump(tester);
      expect(find.text('482915.200000000000'), findsNothing);
      expect(find.text('2201.050000000000'), findsNothing);
      expect(find.text('0.004578708573483846897371338039'), findsNothing);
    });

    testWidgets('a range tap asks the backend for that range', (tester) async {
      await pump(tester);
      await tester.tap(find.text('1W'));
      await tester.pumpAndSettle();
      verify(
        () => home.repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>['portfolio.summary.v1'],
          options: <String, String>{'range': '1w'},
        ),
      ).called(1);
    });

    testWidgets('shows the backend failure verbatim', (tester) async {
      when(
        () => home.repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>['portfolio.summary.v1'],
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => const Err<RenderedViews>(TransportFailure('offline')),
      );
      await pump(tester);
      expect(find.text('offline'), findsOneWidget);
    });
  });
}
