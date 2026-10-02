import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_app/features/shell/view/tab_failure.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'home_harness.dart';

/// GGU-110 AC-1: Home drew its own failure sentence, with no way out. It now
/// draws the tabs' shared state, which has one.
void main() {
  group('$HomePage after a failure', () {
    testWidgets('Try again re-issues both requests', (tester) async {
      final home = HomeHarness();
      when(
        () => home.repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>['portfolio.summary.v1'],
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async =>
            const Err<RenderedViews>(TransportFailure('the request timed out')),
      );
      await home.pump(tester);
      expect(find.byType(TabFailure), findsOneWidget);
      expect(find.text('the request timed out'), findsOneWidget);

      home.stub('portfolio.summary.v1', home.summary);
      await tester.tap(find.text(TabFailure.retryLabel));
      await tester.pumpAndSettle();

      expect(find.byType(TabFailure), findsNothing);
      expect(find.text('Total portfolio value'), findsOneWidget);
      verify(
        () => home.repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>['portfolio.summary.v1'],
          options: any(named: 'options'),
        ),
      ).called(2);
    });
  });
}
