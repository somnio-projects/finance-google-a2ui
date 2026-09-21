import 'package:finance_views_repository/finance_views_repository.dart';

import 'allocation_example.dart';
import 'catalog_snapshot.dart';

export 'allocation_example.dart';

/// The example payload, parsed.
ViewPayload holdingsAllocationPayload() =>
    ViewPayload.fromJson(holdingsAllocationExample);

/// The Home hero's example, read from the snapshot: the shell fetches it
/// beside the allocation, so any tree that mounts the root route needs both.
Map<String, dynamic> homeViews() => <String, dynamic>{
  'portfolio.summary.v1': CatalogSnapshot.load().exampleFor('PortfolioSummary'),
};

/// An envelope carrying [holdingsAllocationExample].
///
/// [extraViews] adds further entries, which is how a test reaches the
/// multi-surface layout the single-view fixture never exercises.
RenderedViews renderedViews({
  String? etag,
  Map<String, dynamic> extraViews = const <String, dynamic>{},
}) => RenderedViews.fromJson(<String, dynamic>{
  'as_of': '2026-09-20T00:00:00Z',
  'portfolio_id': 'current',
  'views': <String, dynamic>{
    'holdings.allocation.v1': holdingsAllocationExample,
    ...extraViews,
  },
}, etag: etag);
