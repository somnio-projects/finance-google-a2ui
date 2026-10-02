import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_app/features/shell/view/tab_failure.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

/// GGU-110 AC-1: the tab used to show a sentence with no way out of it.
void main() {
  group('$HoldingsPage after a failure', () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubFailure(
        repository,
        HoldingsBloc.positionsView,
        const TransportFailure('the request timed out'),
      );
      stubView(repository, HoldingsBloc.allocationView, 'HoldingsSummary');
    });

    testWidgets('a timed-out read is a visible state with a way out', (
      tester,
    ) async {
      await tester.pumpApp(
        const HoldingsPage(),
        viewsRepository: repository,
        componentRegistry: buildComponentRegistry(),
        surfaceSize: const Size(390, 2400),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TabFailure), findsOneWidget);
      expect(find.text('the request timed out'), findsOneWidget);

      // The backend recovers; the tap re-issues the tab's own request.
      stubView(repository, HoldingsBloc.positionsView, 'PositionList');
      await tester.tap(find.text(TabFailure.retryLabel));
      await tester.pumpAndSettle();

      expect(find.byType(TabFailure), findsNothing);
      expect(find.text('Total value'), findsOneWidget);
      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[HoldingsBloc.positionsView],
          options: any(named: 'options'),
        ),
      ).called(2);
    });
  });
}
