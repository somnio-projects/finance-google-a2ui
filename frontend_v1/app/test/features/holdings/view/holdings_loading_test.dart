import 'dart:async';

import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_skeleton.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_class_rows.dart';
import 'package:finance_app/features/holdings/view/holdings_first_run.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_app/features/holdings/view/position_tile.dart';
import 'package:finance_app/skeleton/skeleton_rows.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group('Holdings transition states (spec frontend/0020)', () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, HoldingsBloc.positionsView, 'PositionList');
      stubView(repository, HoldingsBloc.allocationView, 'HoldingsSummary');
    });

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      const HoldingsPage(),
      viewsRepository: repository,
      componentRegistry: buildComponentRegistry(),
      surfaceSize: const Size(390, 2400),
      reducedMotion: true,
    );

    /// Makes the next card request hang, and returns its completer.
    Completer<Result<RenderedViews>> deferCard() {
      final pending = Completer<Result<RenderedViews>>();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>[HoldingsBloc.allocationView],
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) => pending.future);
      return pending;
    }

    testWidgets('AC-1 the first paint is the tab, in shimmer', (tester) async {
      await pump(tester);
      expect(find.byType(HoldingsFirstRun), findsOneWidget);
      // The ring is the component's own skeleton, through the registry —
      // this page draws no second placeholder for it (0015 OD-3).
      expect(find.byType(HoldingsAllocationSkeleton), findsOneWidget);
      // AC-4 of 0015 carried forward: no figure, no backend word.
      expect(find.text('Total value'), findsNothing);
      expect(find.text(r'$482,915.20'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(HoldingsFirstRun), findsNothing);
    });

    testWidgets('AC-2 a regrouping greys the ring and keeps the chrome', (
      tester,
    ) async {
      await pump(tester);
      await tester.pumpAndSettle();
      final pending = deferCard();
      await tester.tap(find.text('By sector'));
      await tester.pump();

      // Kept: everything `group_by` does not govern.
      expect(find.text('Total value'), findsOneWidget);
      expect(find.text(r'$482,915.20'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('By sector'), findsOneWidget);
      expect(find.byType(PositionList), findsOneWidget);
      // Replaced: the ring, and with it the other grouping's labels.
      expect(find.byType(HoldingsAllocationSkeleton), findsOneWidget);
      expect(find.text('Other'), findsNothing);

      pending.complete(
        Ok<RenderedViews>(
          exampleEnvelope(HoldingsBloc.allocationView, 'HoldingsSummary'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HoldingsAllocationSkeleton), findsNothing);
      expect(find.text('Other'), findsWidgets);
    });

    testWidgets('AC-3 a regrouping greys the class rows too', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('By asset class').last);
      await tester.pumpAndSettle();
      expect(find.byType(HoldingsClassRows), findsOneWidget);

      final pending = deferCard();
      await tester.tap(find.text('By sector'));
      await tester.pump();
      expect(find.byType(HoldingsClassRows), findsNothing);
      expect(find.byType(SkeletonRows), findsOneWidget);

      pending.complete(
        Ok<RenderedViews>(
          exampleEnvelope(HoldingsBloc.allocationView, 'HoldingsSummary'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HoldingsClassRows), findsOneWidget);
      expect(find.byType(SkeletonRows), findsNothing);
    });
  });
}
