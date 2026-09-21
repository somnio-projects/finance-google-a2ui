import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/charts/sparkline_chart.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/catalog_snapshot.dart';
import '../../../helpers/pump_app.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(HomePage, () {
    late ViewsRepository repository;
    late Map<String, dynamic> summary;
    late Map<String, dynamic> allocation;

    RenderedViews envelope(String view, Map<String, dynamic> example) =>
        RenderedViews.fromJson(<String, dynamic>{
          'as_of': '2026-01-15T12:00:00Z',
          'portfolio_id': 'current',
          'views': <String, dynamic>{view: example},
        });

    setUp(() {
      repository = _MockViewsRepository();
      final snapshot = CatalogSnapshot.load();
      summary = snapshot.exampleFor('PortfolioSummary');
      // The Home card asks for `headline=false`: the backend then omits the
      // gain block, which is what tells the component a shell draws the
      // title. Mirror that here rather than pumping the headline variant.
      allocation = <String, dynamic>{
        ...snapshot.exampleFor('HoldingsSummary'),
        'group_by': 'asset_class',
      }..remove('total_gain');
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>['portfolio.summary.v1'],
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => Ok(envelope('portfolio.summary.v1', summary)));
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>['holdings.allocation.v1'],
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Ok(envelope('holdings.allocation.v1', allocation)),
      );
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(
        const HomePage(),
        viewsRepository: repository,
        componentRegistry: buildComponentRegistry(),
        surfaceSize: const Size(390, 1600),
      );
      await tester.pumpAndSettle();
    }

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
        find.text(r'▲ +$3,240.18 (+0.68%)  today', findRichText: true),
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
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('Tesla, Inc.'), findsOneWidget);
      expect(find.text('▼ -2.3%'), findsOneWidget);
      expect(find.text(r'$1,204.66'), findsOneWidget);
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      await pump(tester);
      expect(find.text('482915.200000'), findsNothing);
      expect(find.text('3240.180000'), findsNothing);
      expect(find.text('0.006754948381510465147841136276'), findsNothing);
    });

    testWidgets('a range tap asks the backend for that range', (tester) async {
      await pump(tester);
      await tester.tap(find.text('1W'));
      await tester.pumpAndSettle();
      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>['portfolio.summary.v1'],
          options: <String, String>{'range': '1w'},
        ),
      ).called(1);
    });

    testWidgets('shows the backend failure verbatim', (tester) async {
      when(
        () => repository.fetchPortfolioViews(
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

    testWidgets('spins while loading', (tester) async {
      await tester.pumpApp(
        const HomePage(),
        viewsRepository: repository,
        componentRegistry: buildComponentRegistry(),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
