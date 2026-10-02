import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group('the timeline draws every term badge the seed can produce', () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, ActivityBloc.timelineView, 'ActivityTimeline');
    });

    testWidgets('all four, because the ledger has both signs in both terms', (
      tester,
    ) async {
      // The badge said `ST gain` whatever the sign until spec backend/0035
      // OD-5, and nothing caught it because the seed held one sale and it
      // was a gain. These four assertions are what stops that returning.
      await tester.pumpApp(
        const ActivityPage(),
        viewsRepository: repository,
        surfaceSize: const Size(390, 6000),
      );
      await tester.pumpAndSettle();

      expect(find.text('ST gain'), findsWidgets);
      expect(find.text('LT gain'), findsWidgets);
      expect(find.text('ST loss'), findsWidgets);
      expect(find.text('LT loss'), findsWidgets);
    });
  });
}
