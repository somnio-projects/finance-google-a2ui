import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/shell/view/tab_failure.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

/// GGU-110 AC-1, on the other tab that draws the same failure state.
void main() {
  group('$ActivityPage after a failure', () {
    testWidgets('Try again re-issues the timeline request', (tester) async {
      final repository = _MockViewsRepository();
      stubFailure(
        repository,
        ActivityBloc.timelineView,
        const TransportFailure('the request timed out'),
      );
      await tester.pumpApp(
        const ActivityPage(),
        viewsRepository: repository,
        surfaceSize: const Size(390, 6000),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabFailure), findsOneWidget);

      stubView(repository, ActivityBloc.timelineView, 'ActivityTimeline');
      await tester.tap(find.text(TabFailure.retryLabel));
      await tester.pumpAndSettle();

      expect(find.byType(TabFailure), findsNothing);
      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[ActivityBloc.timelineView],
          options: any(named: 'options'),
        ),
      ).called(2);
    });
  });
}
