import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/catalog_snapshot.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/tab_fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

/// The catalog's example for [component] with its list emptied — what the
/// backend answers when a filter kept nothing (spec backend/0035 AC-8).
RenderedViews _emptied(String view, String component, String list) {
  final example = Map<String, dynamic>.from(
    CatalogSnapshot.load().exampleFor(component),
  )..[list] = <dynamic>[];
  return RenderedViews.fromJson(<String, dynamic>{
    'as_of': '2026-01-15T12:00:00Z',
    'portfolio_id': 'current',
    'views': <String, dynamic>{view: example},
  });
}

void _stubEmpty(
  ViewsRepository repository,
  String view,
  String component,
  String list,
) {
  when(
    () => repository.fetchPortfolioViews(
      portfolioId: any(named: 'portfolioId'),
      views: <String>[view],
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => Ok<RenderedViews>(_emptied(view, component, list)));
}

void main() {
  group('an empty list is a sentence, not a failure (AC-6)', () {
    late ViewsRepository repository;

    setUp(() => repository = _MockViewsRepository());

    testWidgets('Activity prints the payload sentence', (tester) async {
      _stubEmpty(
        repository,
        ActivityBloc.timelineView,
        'ActivityTimeline',
        'groups',
      );

      await tester.pumpApp(
        const ActivityPage(),
        viewsRepository: repository,
        surfaceSize: const Size(390, 1200),
      );
      await tester.pumpAndSettle();

      expect(find.text('No activity matches this filter.'), findsOneWidget);
      // Still a success: the chips and the note are drawn beside it.
      expect(find.text('✓ All'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Holdings prints the payload sentence', (tester) async {
      _stubEmpty(
        repository,
        HoldingsBloc.positionsView,
        'PositionList',
        'positions',
      );
      stubView(repository, HoldingsBloc.allocationView, 'HoldingsSummary');

      await tester.pumpApp(
        const Scaffold(body: HoldingsPage()),
        viewsRepository: repository,
        componentRegistry: ComponentRegistry(),
        surfaceSize: const Size(390, 1200),
      );
      await tester.pumpAndSettle();

      expect(find.text('No holdings match this filter.'), findsOneWidget);
      // The header is still the whole portfolio's (spec backend/0035 OD-4).
      expect(find.text(r'$482,915.20'), findsOneWidget);
    });
  });
}
