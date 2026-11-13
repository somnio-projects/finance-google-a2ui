import 'dart:async';

import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_entry_label.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/activity/view/activity_sections.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group('Activity rows semantics (GGU-157)', () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, ActivityBloc.timelineView, 'ActivityTimeline');
    });

    List<ViewPayload> entries() =>
        exampleEnvelope(ActivityBloc.timelineView, 'ActivityTimeline')
            .views[ActivityBloc.timelineView]!
            .rows('groups')
            .expand((g) => g.rows('entries'))
            .toList();

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

    void expectHeadingsThenRows(WidgetTester tester) {
      final groups = exampleEnvelope(
        ActivityBloc.timelineView,
        'ActivityTimeline',
      ).views[ActivityBloc.timelineView]!.rows('groups');
      final expected = <(bool, String)>[
        for (final g in groups) ...<(bool, String)>[
          (true, g.text('label')),
          for (final e in g.rows('entries')) (false, activityEntryLabel(e)),
        ],
      ];
      expect(readingOrder(tester), expected);
    }

    void expectEveryRowExposed(WidgetTester tester) {
      final all = entries();
      expect(all, isNotEmpty);
      for (final entry in all) {
        final label = activityEntryLabel(entry);
        expect(
          find.bySemanticsLabel(label),
          findsWidgets,
          reason: 'no semantics node for "$label"',
        );
        for (final part in <String>[
          entry.text('title'),
          entry.text('detail'),
          entry.text('amount.display'),
        ]) {
          expect(label, contains(part));
        }
      }
    }

    testWidgets('every row has its own node after a filter change', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const ActivityPage(),
        viewsRepository: repository,
        surfaceSize: const Size(390, 9000),
      );
      await tester.pumpAndSettle();
      expectEveryRowExposed(tester);
      expectHeadingsThenRows(tester);

      final pending = Completer<Result<RenderedViews>>();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>[ActivityBloc.timelineView],
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) => pending.future);
      await tester.tap(find.text('Sells'));
      await tester.pump(const Duration(milliseconds: 300));
      pending.complete(
        Ok<RenderedViews>(
          exampleEnvelope(ActivityBloc.timelineView, 'ActivityTimeline'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      expectEveryRowExposed(tester);
      expectHeadingsThenRows(tester);
      expect(
        find.bySemanticsLabel('Simulated activity — resets each session.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('each section is its own heading, followed by its rows', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const ActivityPage(),
        viewsRepository: repository,
        surfaceSize: const Size(390, 9000),
      );
      await tester.pumpAndSettle();

      final headings = readingOrder(tester).where((n) => n.$1).toList();
      final groups = exampleEnvelope(
        ActivityBloc.timelineView,
        'ActivityTimeline',
      ).views[ActivityBloc.timelineView]!.rows('groups');
      expect(groups.length, greaterThan(1));
      expect(headings.map((n) => n.$2), groups.map((g) => g.text('label')));
      handle.dispose();
    });
  });
}
