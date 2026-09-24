/// The stubs and the tree `home_view_test.dart` and
/// `home_view_loading_test.dart` share.
///
/// Extracted so both suites stay inside the 150-line budget — the remedy
/// `.claude/rules/frontend/testing.md` §3 prescribes when a test file grows,
/// rather than dropping the comments that say why each assertion exists.
library;

import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/catalog_snapshot.dart';
import '../../../helpers/pump_app.dart';

/// A stand-in for the repository the Home tab reads both views from.
class MockViewsRepository extends Mock implements ViewsRepository;

/// The Home tab's two payloads, stubbed to answer at once.
class HomeHarness {
  /// Builds the repository and stubs both views with the snapshot examples.
  HomeHarness() {
    final snapshot = CatalogSnapshot.load();
    summary = snapshot.exampleFor('PortfolioSummary');
    // The Home card asks for `headline=false`: the backend then omits the
    // gain block, which is what tells the component a shell draws the
    // title. Mirror that here rather than pumping the headline variant.
    allocation = <String, dynamic>{
      ...snapshot.exampleFor('HoldingsSummary'),
      'group_by': 'asset_class',
    }..remove('total_gain');
    stub('portfolio.summary.v1', summary);
    stub('holdings.allocation.v1', allocation);
  }

  /// The repository the page reads.
  final MockViewsRepository repository = MockViewsRepository();

  /// `portfolio.summary.v1`'s example.
  late final Map<String, dynamic> summary;

  /// `holdings.allocation.v1`'s example, as the Home card asks for it.
  late final Map<String, dynamic> allocation;

  /// Wraps [example] in a rendered-views envelope under [view].
  RenderedViews envelope(String view, Map<String, dynamic> example) =>
      RenderedViews.fromJson(<String, dynamic>{
        'as_of': '2026-01-15T12:00:00Z',
        'portfolio_id': 'current',
        'views': <String, dynamic>{view: example},
      });

  /// Stubs [view] to answer [example] for any options.
  void stub(String view, Map<String, dynamic> example) {
    when(
      () => repository.fetchPortfolioViews(
        portfolioId: any(named: 'portfolioId'),
        views: <String>[view],
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => Ok(envelope(view, example)));
  }

  /// Pumps the page at phone width, tall enough for every section to build.
  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpApp(
      const HomePage(),
      viewsRepository: repository,
      componentRegistry: buildComponentRegistry(),
      surfaceSize: const Size(390, 1600),
    );
    if (settle) await tester.pumpAndSettle();
  }
}
