import 'package:finance_app/components/attribution_driver/attribution_driver_card.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_model.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `attribution.driver.v1` — one driver of the day, in detail.
///
/// The card Flow A composes when a waterfall bar is tapped: the agent's
/// `driver_detail` tool asks for this view with the tapped `symbol`, and the
/// conversation renders it below the answer (spec frontend/0014). Field paths
/// come from the backend's generated catalog entry; every figure is a
/// `*.display` string and every word — the caption, the tile labels, the
/// `@` and `of` lines — arrives written (N-1, N-9).
class AttributionDriverComponent extends ViewComponent {
  /// Creates the component.
  const AttributionDriverComponent();

  @override
  String get viewId => 'attribution.driver.v1';

  @override
  String get a2uiComponent => 'DriverDetail';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      AttributionDriverCard(data: read(payload));

  /// Reads [payload] into the model the card draws.
  ///
  /// Exposed so the binding can be asserted without a widget tree.
  AttributionDriverData read(ViewPayload payload) => AttributionDriverData(
    symbol: payload.text('symbol'),
    name: payload.text('name'),
    caption: payload.text('caption'),
    contributionDisplay: payload.text('contribution.display'),
    trend: _trendOf(payload.text('trend'), path: 'trend'),
    tiles: <DriverTile>[
      DriverTile(
        label: payload.text('price_move.label'),
        figure: payload.text('price_move.percent.display'),
        caption: payload.text('price_move.amount.display'),
        trend: _trendOf(
          payload.text('price_move.trend'),
          path: 'price_move.trend',
        ),
      ),
      DriverTile(
        label: payload.text('shares.label'),
        figure: payload.text('shares.units.display'),
        caption: payload.text('shares.caption'),
      ),
      DriverTile(
        label: payload.text('day_share.label'),
        figure: payload.text('day_share.percent.display'),
        caption: payload.text('day_share.caption'),
      ),
    ],
  );

  /// Maps the backend's `up / down / flat` onto the enum.
  ///
  /// A fourth value is a contract violation, not a guess (N-3).
  static DriverTrend _trendOf(String value, {required String path}) =>
      switch (value) {
        'up' => DriverTrend.up,
        'down' => DriverTrend.down,
        'flat' => DriverTrend.flat,
        _ => throw PayloadContractException(
          ContractFailure(path, 'one of "up", "down", "flat"'),
        ),
      };
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every
/// component module exposes exactly one `register`, which is what
/// `binding_rules_test.dart` checks.
void register(ComponentRegistry registry) =>
    registry.register(const AttributionDriverComponent());
