import 'dart:async';

import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_first_run.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/activity/view/activity_sections.dart';
import 'package:finance_app/skeleton/skeleton_rows.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group('Activity transition states (spec frontend/0020)', () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, ActivityBloc.timelineView, 'ActivityTimeline');
    });

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      const ActivityPage(),
      viewsRepository: repository,
      surfaceSize: const Size(390, 2400),
      reducedMotion: true,
    );

    testWidgets('AC-4 the first paint is the tab, in shimmer', (tester) async {
      await pump(tester);
      expect(find.byType(ActivityFirstRun), findsOneWidget);
      // Title, five chips, the note line, six rows — and not one word of the
      // backend's, because none has arrived (N-9).
      expect(
        find.byType(SkeletonShimmer),
        findsNWidgets(
          2 + ActivityFirstRun.chipCount + ActivityFirstRun.rowCount,
        ),
      );
      expect(find.text('Activity'), findsNothing);
      expect(find.text('✓ All'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityFirstRun), findsNothing);
    });

    testWidgets('AC-5 a filter greys the rows and keeps the chips', (
      tester,
    ) async {
      await pump(tester);
      await tester.pumpAndSettle();
      final pending = Completer<Result<RenderedViews>>();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>[ActivityBloc.timelineView],
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) => pending.future);

      await tester.tap(find.text('Sells'));
      await tester.pump();

      // Kept: the bar, the chips with the tapped one selected, the note.
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('✓ Sells'), findsOneWidget);
      expect(
        find.text('Simulated activity — resets each session.'),
        findsOneWidget,
      );
      // Replaced: the previous filter's rows never show under the new chip.
      expect(find.byType(ActivitySections), findsNothing);
      expect(find.byType(SkeletonRows), findsOneWidget);
      expect(find.text('Dividend — VOO'), findsNothing);

      pending.complete(
        Ok<RenderedViews>(
          exampleEnvelope(ActivityBloc.timelineView, 'ActivityTimeline'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonRows), findsNothing);
      expect(find.byType(ActivitySections), findsOneWidget);
      expect(find.text('Dividend — VOO'), findsOneWidget);
    });
  });
}
