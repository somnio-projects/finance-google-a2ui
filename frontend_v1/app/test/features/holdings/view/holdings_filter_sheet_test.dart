import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_filter_sheet.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(HoldingsFilterSheet, () {
    late ViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      stubView(repository, HoldingsBloc.positionsView, 'PositionList');
      stubView(repository, HoldingsBloc.allocationView, 'HoldingsSummary');
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(
        const Scaffold(body: HoldingsPage()),
        viewsRepository: repository,
        componentRegistry: ComponentRegistry(),
        surfaceSize: const Size(390, 2400),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the icon opens the payload chips, not literals (AC-4)', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Filter Holdings'));
      await tester.pumpAndSettle();

      expect(find.text(HoldingsFilterSheet.title), findsOneWidget);
      // Every word here came out of `holdings.positions.v1`'s `filters[]`.
      expect(find.text('✓ All'), findsOneWidget);
      for (final label in <String>[
        'Layer 1',
        'Layer 2',
        'Infrastructure',
        'DeFi',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('picking a chip refetches and closes the sheet (AC-4)', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Filter Holdings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Layer 2'));
      await tester.pumpAndSettle();

      expect(find.text(HoldingsFilterSheet.title), findsNothing);
      verify(
        () => repository.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[HoldingsBloc.positionsView],
          options: <String, String>{'asset_class': 'layer2'},
        ),
      ).called(1);
    });

    testWidgets('reopening marks the chip in force', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Filter Holdings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DeFi'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Filter Holdings'));
      await tester.pumpAndSettle();

      expect(find.text('✓ DeFi'), findsOneWidget);
      expect(find.text('✓ All'), findsNothing);
    });
  });
}
