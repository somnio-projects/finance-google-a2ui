import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_entry_tile.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(ActivityPage, () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, ActivityBloc.timelineView, 'ActivityTimeline');
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(
        const ActivityPage(),
        viewsRepository: repository,
        surfaceSize: const Size(390, 2400),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'binds the chips, the note, the sections and the rows verbatim',
      (tester) async {
        await pump(tester);
        expect(find.text('Activity'), findsOneWidget);
        expect(find.text('✓ All'), findsOneWidget);
        expect(find.text('Dividends'), findsOneWidget);
        expect(
          find.text('Simulated activity — resets each session.'),
          findsOneWidget,
        );
        expect(find.text('TODAY'), findsOneWidget);
        expect(find.text('THIS WEEK'), findsOneWidget);
        expect(find.text('Dividend — VOO'), findsOneWidget);
        expect(find.text(r'$1.62/sh · 85 sh · qualified'), findsOneWidget);
        expect(find.text(r'+$137.70'), findsOneWidget);
        expect(find.text('Deposit — Bank transfer'), findsOneWidget);
        expect(find.text('Sold 20 VOO'), findsOneWidget);
        expect(find.text('ST gain'), findsOneWidget);
        expect(find.text(r'+$1,738 realized'), findsOneWidget);
        expect(find.text('Bought 250 PYPL'), findsOneWidget);
        expect(find.text(r'-$22,150.00'), findsOneWidget);
        expect(find.text('Buy'), findsWidgets);
        expect(find.byType(ActivityEntryTile), findsWidgets);
      },
    );

    testWidgets('a chip refetches with its kind', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Sells'));
      await tester.pumpAndSettle();
      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[ActivityBloc.timelineView],
          options: <String, String>{'kind': 'sell'},
        ),
      ).called(1);
    });

    testWidgets('shows the backend failure verbatim', (tester) async {
      stubFailure(
        repository,
        ActivityBloc.timelineView,
        const TransportFailure('offline'),
      );
      await pump(tester);
      expect(find.text('offline'), findsOneWidget);
    });

    testWidgets('spins while loading', (tester) async {
      await tester.pumpApp(const ActivityPage(), viewsRepository: repository);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group(ActivityEntryTile, () {
    testWidgets(
      'a long-term sell wears the teal badge; an unknown kind a dot',
      (tester) async {
        final sell = _entry(const <String, dynamic>{
          'key': 't',
          'kind': 'sell',
          'title': 'Sold 25 VOO',
          'detail': r'25 sh @ $528.00 · Sep 8',
          'amount': <String, dynamic>{
            'amount': '13200',
            'display': r'$13,200.00',
          },
          'tone': 'flat',
          'badge': 'Sell',
          'realized': <String, dynamic>{
            'amount': <String, dynamic>{'amount': '-100', 'display': r'-$100'},
            'text': r'-$100 realized',
            'trend': 'down',
          },
          'term': <String, dynamic>{'term': 'long', 'label': 'LT gain'},
        });
        final odd = _entry(const <String, dynamic>{
          'key': 'o',
          'kind': 'fee',
          'title': 'Fee',
          'detail': 'x',
          'amount': <String, dynamic>{'amount': '-1', 'display': r'-$1.00'},
          'tone': 'down',
          'badge': 'Fee',
        });
        await tester.pumpApp(
          Column(
            children: <Widget>[
              ActivityEntryTile(entry: sell),
              ActivityEntryTile(entry: odd),
            ],
          ),
        );
        expect(find.text('LT gain'), findsOneWidget);
        expect(find.text(r'-$100 realized'), findsOneWidget);
        expect(find.text('·'), findsOneWidget);
      },
    );
  });
}

/// One `groups[].entries[]` row, read the way the view reads it — through a
/// parent that carries the discriminator.
ViewPayload _entry(Map<String, dynamic> row) =>
    ViewPayload.fromJson(<String, dynamic>{
      'view': 'activity.timeline.v1',
      'entries': <Map<String, dynamic>>[row],
    }).rows('entries').single;
