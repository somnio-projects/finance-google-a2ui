import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_app/features/holdings/view/position_tile.dart';
import 'package:finance_app/features/shell/view/tab_app_bar.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(HoldingsPage, () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, HoldingsBloc.positionsView, 'PositionList');
      stubView(repository, HoldingsBloc.allocationView, 'HoldingsSummary');
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(
        const HoldingsPage(),
        viewsRepository: repository,
        componentRegistry: buildComponentRegistry(),
        surfaceSize: const Size(390, 2400),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('binds the header, the toggle and the first row expanded', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.descendant(
          of: find.byType(TabAppBar),
          matching: find.text('Holdings'),
        ),
        findsOneWidget,
      );
      expect(find.text('Total value'), findsOneWidget);
      // Twice on purpose: the header card prints it, and so does the
      // allocation example the stub serves — a stub cannot honour
      // `headline=false`, which is what hides the second one in the app.
      expect(find.text(r'$482,915.20'), findsWidgets);
      expect(
        find.text(
          r'▲ +$61,204 · +14.5% all-time unrealized',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('By asset class'), findsNWidgets(2));
      expect(find.text('By sector'), findsOneWidget);
      expect(find.text('✓ By position'), findsOneWidget);
      expect(find.text('NVIDIA Corp'), findsWidgets);
      expect(find.text(r'90 sh · avg $826.67'), findsOneWidget);
      expect(find.text(r'▲ +$34,019 (+45.7%)'), findsOneWidget);
      // The expanded row shows its three stats and the hand-off.
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('▲ +4.2%'), findsWidgets);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Ask the assistant about this'), findsOneWidget);
    });

    testWidgets(
      'tapping a row moves the expansion, tapping it again collapses',
      (tester) async {
        await pump(tester);
        // The donut's legend names Apple too; the row is the one inside the
        // list.
        final apple = find.descendant(
          of: find.byType(PositionList),
          matching: find.text('Apple Inc.'),
        );
        await tester.tap(apple);
        await tester.pumpAndSettle();
        expect(find.text(r'300 sh · avg $135.40'), findsOneWidget);
        expect(find.text(r'$233.18'), findsOneWidget);
        await tester.tap(apple);
        await tester.pumpAndSettle();
        expect(find.text('Ask the assistant about this'), findsNothing);
      },
    );

    testWidgets('the toggle asks the card for sectors', (tester) async {
      await pump(tester);
      await tester.tap(find.text('By sector'));
      await tester.pumpAndSettle();
      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[HoldingsBloc.allocationView],
          options: HoldingsBloc.allocationOptions('sector'),
        ),
      ).called(1);
    });

    testWidgets('the segment switches to the class rows', (tester) async {
      await pump(tester);
      await tester.tap(find.text('By asset class').last);
      await tester.pumpAndSettle();
      expect(find.byType(PositionList), findsNothing);
      expect(find.text('✓ By asset class'), findsOneWidget);
      expect(find.text('Other'), findsWidgets);
    });

    testWidgets('shows the backend failure verbatim', (tester) async {
      stubFailure(
        repository,
        HoldingsBloc.positionsView,
        const TransportFailure('offline'),
      );
      await pump(tester);
      expect(find.text('offline'), findsOneWidget);
    });

    // The first paint is `HoldingsFirstRun`; that is AC-1 and it lives in
    // holdings_loading_test.dart with the rest of 0018.
    testWidgets('the quiet icons say they are not wired yet', (tester) async {
      // In a Scaffold, because the icon answers with a SnackBar.
      await tester.pumpApp(
        const Scaffold(body: HoldingsPage()),
        viewsRepository: repository,
        componentRegistry: buildComponentRegistry(),
        surfaceSize: const Size(390, 2400),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pump();
      expect(
        find.text('Search is not part of this preview yet.'),
        findsOneWidget,
      );
    });
  });
}
