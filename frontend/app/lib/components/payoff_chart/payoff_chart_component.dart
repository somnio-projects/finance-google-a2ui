import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_card.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_model.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `payoff.curve.v1` — what a proposed order makes as the price moves.
///
/// Field paths come from the backend's generated catalog entry (digest
/// `6a69670692d0`), and `catalog_contract_test.dart` checks [viewId] and
/// [a2uiComponent] against `view-catalog.snapshot.json`, so a rename on the
/// backend turns the suite red rather than showing a placeholder.
///
/// Every figure drawn is a `*.display`, `label` or `text` member. The raw
/// `at.amount` and `value.amount` are read **only** through
/// [ViewPayload.geometry] and only to place the line (N-4, ADR-L D-14).
class PayoffChartComponent extends ViewComponent {
  /// Creates the component.
  const PayoffChartComponent();

  @override
  String get viewId => 'payoff.curve.v1';

  @override
  String get a2uiComponent => 'PayoffChart';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      PayoffChartCard(data: read(payload));

  /// Reads [payload] into the model the card draws.
  ///
  /// Exposed so the binding can be asserted without a widget tree, and so a
  /// golden can pump the card from a literal.
  PayoffChartData read(ViewPayload payload) => PayoffChartData(
    title: payload.text('title'),
    disclosure: payload.text('disclosure'),
    totals: <PayoffFact>[
      for (final total in payload.rows('totals'))
        PayoffFact(
          label: total.text('label'),
          text: total.text('amount.display'),
        ),
    ],
    lines: <PayoffLine>[for (final line in payload.rows('series')) _line(line)],
    annotations: <PayoffFact>[
      for (final note in payload.rows('annotations'))
        PayoffFact(label: note.text('label'), text: note.text('text')),
    ],
  );

  /// Reads one `series[]` entry.
  ///
  /// The two raw members are the only numbers this component touches, and
  /// both become canvas coordinates and nothing else. The price is read
  /// twice over on purpose — `at.amount` places the point, `label` is the
  /// tick the reader sees — which is the pair GGU-53 added precisely so a
  /// client would never have to parse a formatted price back into a number.
  PayoffLine _line(ViewPayload line) {
    final points = line.rows('points');
    return PayoffLine(
      name: line.text('name'),
      points: <PayoffPoint>[
        for (final point in points)
          PayoffPoint(
            at: point.geometry('at.amount'),
            value: point.geometry('value.amount'),
          ),
      ],
      tickLabels: <String>[for (final point in points) point.text('label')],
    );
  }
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every
/// component module exposes exactly one `register`, which is what
/// `binding_rules_test.dart` checks.
void register(ComponentRegistry registry) =>
    registry.register(const PayoffChartComponent());
