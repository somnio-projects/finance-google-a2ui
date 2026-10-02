import 'package:finance_app/components/payoff_chart/payoff_chart_component.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

import '../../helpers/catalog_snapshot.dart';

/// The backend's own published example for `PayoffChart`.
///
/// Read from `docs/catalog/view-catalog.snapshot.json`, never copied: a copy
/// of a generated artefact is the thing that goes stale (ADR-L D-4).
Map<String, dynamic> payoffExample() =>
    CatalogSnapshot.load().exampleFor('RiskPayoffChart');

/// The example bound through the component under test.
PayoffChartData payoffData() =>
    const PayoffChartComponent().read(ViewPayload.fromJson(payoffExample()));

/// A copy of [example] with [key] removed, for the contract-violation paths.
///
/// The component must **raise** naming the path rather than reconstruct the
/// value (N-3), which is the half of the contract a happy-path test cannot
/// reach.
Map<String, dynamic> without(Map<String, dynamic> example, String key) {
  final copy = <String, dynamic>{...example}..remove(key);
  return copy;
}

/// A copy of [example] carrying no series at all.
///
/// The contract defaults `series` to `[]`, so this is a payload the backend
/// may legitimately send and the card must render rather than throw (AC-5).
Map<String, dynamic> withoutSeries(Map<String, dynamic> example) =>
    <String, dynamic>{...example, 'series': <Map<String, dynamic>>[]};

/// A copy of [example] whose first point's raw price is not a decimal.
///
/// The geometry seam must reject it, because a point that cannot be placed is
/// a broken contract rather than a point to guess at.
Map<String, dynamic> withBadPoint(Map<String, dynamic> example) {
  final series = (example['series'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final points = (series.first['points'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final at = points.first['at'] as Map<String, dynamic>;
  return <String, dynamic>{
    ...example,
    'series': <Map<String, dynamic>>[
      <String, dynamic>{
        ...series.first,
        'points': <Map<String, dynamic>>[
          <String, dynamic>{
            ...points.first,
            'at': <String, dynamic>{...at, 'amount': 'not a decimal'},
          },
          ...points.skip(1),
        ],
      },
      ...series.skip(1),
    ],
  };
}

/// Every raw decimal the example carries, which must never reach the tree.
///
/// Taken from the example itself rather than written out, so the assertion
/// keeps meaning what it says when the backend regenerates the snapshot.
///
/// **The `totals` raws come first on purpose.** They are the ones sitting
/// directly beside a `Text` in the totals row, so they are the likeliest to
/// leak — the series raws never go near a widget, they become coordinates.
/// A set that covered only the series would have been an N-4 assertion
/// pointed away from the risk.
List<String> rawDecimalsOf(Map<String, dynamic> example) {
  final raw = <String>[];
  for (final total
      in (example['totals'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    raw.add((total['amount'] as Map<String, dynamic>)['amount'] as String);
  }
  final series = (example['series'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final line in series) {
    final points = (line['points'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final point in points) {
      raw
        ..add((point['at'] as Map<String, dynamic>)['amount'] as String)
        ..add((point['value'] as Map<String, dynamic>)['amount'] as String);
    }
  }
  return raw;
}
