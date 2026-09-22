import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

/// Comfortably past `defaultDebounce`, which the pages do not override.
const Duration _pastTheDebounce = Duration(milliseconds: 400);

void main() {
  group('typing in a tab sends a declared option (AC-2, AC-3)', () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, ActivityBloc.timelineView, 'ActivityTimeline');
      stubView(repository, HoldingsBloc.positionsView, 'PositionList');
      stubView(repository, HoldingsBloc.allocationView, 'HoldingsSummary');
    });

    testWidgets('Activity searches the ledger', (tester) async {
      await tester.pumpApp(
        const ActivityPage(),
        viewsRepository: repository,
        surfaceSize: const Size(390, 1200),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Search Activity'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nvda');
      await tester.pump(_pastTheDebounce);
      await tester.pumpAndSettle();

      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[ActivityBloc.timelineView],
          options: <String, String>{'kind': 'all', 'query': 'nvda'},
        ),
      ).called(1);
    });

    testWidgets('Holdings searches the list and not the card', (tester) async {
      await tester.pumpApp(
        const Scaffold(body: HoldingsPage()),
        viewsRepository: repository,
        componentRegistry: ComponentRegistry(),
        surfaceSize: const Size(390, 1200),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Search Holdings'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'vanguard');
      await tester.pump(_pastTheDebounce);
      await tester.pumpAndSettle();

      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[HoldingsBloc.positionsView],
          options: <String, String>{'query': 'vanguard'},
        ),
      ).called(1);
      // The allocation card was fetched once, on load, and never again: it
      // declares no `query`, and one flat option set per request means
      // sending it there would 422 the lot (N-7).
      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[HoldingsBloc.allocationView],
          options: any(named: 'options'),
        ),
      ).called(1);
    });
  });
}
