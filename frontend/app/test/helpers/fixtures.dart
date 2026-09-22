import 'package:finance_views_repository/finance_views_repository.dart';

import 'allocation_example.dart';
import 'catalog_snapshot.dart';

export 'allocation_example.dart';

/// The example payload, parsed.
ViewPayload holdingsAllocationPayload() =>
    ViewPayload.fromJson(holdingsAllocationExample);

/// Every view a tab fetches on mount, read from the snapshot: the Home hero
/// beside the allocation, the Holdings list and the Activity timeline. A tree
/// that mounts the shell can land on any tab, and a tab whose view is missing
/// from the envelope spins forever — which a `pumpAndSettle` reports as a
/// timeout, not as the missing view.
Map<String, dynamic> homeViews() => <String, dynamic>{
  'portfolio.summary.v1': CatalogSnapshot.load().exampleFor('PortfolioSummary'),
  'holdings.positions.v1': CatalogSnapshot.load().exampleFor('PositionList'),
  'activity.timeline.v1': CatalogSnapshot.load().exampleFor('ActivityTimeline'),
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
