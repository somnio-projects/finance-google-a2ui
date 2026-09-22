/// Envelopes for the Holdings and Activity tabs, read from the generated
/// catalog so a test binds what the backend really publishes.
library;

import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_snapshot.dart';

/// One envelope with [view] → the catalog's example for [component].
RenderedViews exampleEnvelope(String view, String component) =>
    RenderedViews.fromJson(<String, dynamic>{
      'as_of': '2026-01-15T12:00:00Z',
      'portfolio_id': 'current',
      'views': <String, dynamic>{
        view: CatalogSnapshot.load().exampleFor(component),
      },
    });

/// Stubs [repository] to answer [view] with [component]'s example.
void stubView(ViewsRepository repository, String view, String component) {
  when(
    () => repository.fetchPortfolioViews(
      portfolioId: any(named: 'portfolioId'),
      views: <String>[view],
      options: any(named: 'options'),
    ),
  ).thenAnswer(
    (_) async => Ok<RenderedViews>(exampleEnvelope(view, component)),
  );
}

/// Stubs [repository] to fail [view] with [failure].
void stubFailure(ViewsRepository repository, String view, AppFailure failure) {
  when(
    () => repository.fetchPortfolioViews(
      portfolioId: any(named: 'portfolioId'),
      views: <String>[view],
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => Err<RenderedViews>(failure));
}
