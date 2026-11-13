import 'dart:async';

import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_entry_label.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/activity/view/activity_sections.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group('Activity section headings (GGU-166)', () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, ActivityBloc.timelineView, 'ActivityTimeline');
    });

    List<ViewPayload> groups() => exampleEnvelope(
      ActivityBloc.timelineView,
      'ActivityTimeline',
    ).views[ActivityBloc.timelineView]!.rows('groups');

    // Every labelled node in reading order, as (isHeader, label).
    List<(bool, String)> readingOrder(WidgetTester tester) {
      final out = <(bool, String)>[];
      void walk(SemanticsNode node) {
        if (node.label.isNotEmpty) {
          out.add((node.flagsCollection.isHeader, node.label));
        }
        node
            .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
            .forEach(walk);
      }

      walk(tester.getSemantics(find.byType(ActivitySections)));
      return out;
    }

    // Header, its rows, next header: every row exposed, none lost.
    void expectHeadingsThenRows(WidgetTester tester) {
      expect(readingOrder(tester), <(bool, String)>[
        for (final g in groups()) ...<(bool, String)>[
          (true, g.text('label')),
          for (final e in g.rows('entries')) (false, activityEntryLabel(e)),
        ],
      ]);
    }

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(
        const ActivityPage(),
        viewsRepository: repository,
        surfaceSize: const Size(390, 9000),
      );
      await tester.pumpAndSettle();
    }

    // Holds the next answer back, so the skeleton and cross-fade run.
    Completer<Result<RenderedViews>> holdNextAnswer() {
      final pending = Completer<Result<RenderedViews>>();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>[ActivityBloc.timelineView],
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) => pending.future);
      return pending;
    }

    Future<void> answer(
      WidgetTester tester,
      Completer<Result<RenderedViews>> pending,
    ) async {
      pending.complete(
        Ok<RenderedViews>(
          exampleEnvelope(ActivityBloc.timelineView, 'ActivityTimeline'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
    }

    testWidgets('each section is its own heading, followed by its rows', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final headings = readingOrder(tester).where((n) => n.$1);
      expect(groups().length, greaterThan(1));
      expect(headings.map((n) => n.$2), groups().map((g) => g.text('label')));
      expectHeadingsThenRows(tester);
      handle.dispose();
    });

    testWidgets('the order and every row survive a filter change', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final pending = holdNextAnswer();
      await tester.tap(find.text('Sells'));
      await tester.pump(const Duration(milliseconds: 300));
      await answer(tester, pending);

      expectHeadingsThenRows(tester);
      handle.dispose();
    });

    testWidgets('the order and every row survive a search', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final pending = holdNextAnswer();
      await tester.tap(find.byTooltip('Search Activity'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'staking');
      await tester.pump(const Duration(milliseconds: 400));
      await answer(tester, pending);

      expectHeadingsThenRows(tester);
      handle.dispose();
    });
  });
}
