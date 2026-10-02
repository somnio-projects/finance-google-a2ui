import 'package:finance_app/components/scenario_comparison/scenario_comparison_rows.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

/// Pairs each declared row with the column field of that name.
///
/// The row's label, its direction hint and its winner are all server
/// strings now (backend spec 0051); what stays here is the **mapping from
/// a row key to a payload path**, and it is a `switch` over literals
/// rather than string arithmetic on purpose: every payload path in this app
/// opens with a quote, and `binding_rules_test.dart::payload paths are
/// literals, never variables` fails on one that does not (N-5).
///
/// A key this client does not know is a **contract drift**, not a row to
/// skip: the schema publishes a closed set, so an unknown one means the
/// backend moved and the card would silently lose a row. It raises, and
/// `ComponentHost` shows it (N-3).
List<ScenarioMetricRow> scenarioMetrics(
  ViewPayload payload,
  List<ViewPayload> columns,
) => <ScenarioMetricRow>[
  for (final row in payload.rows('rows'))
    ScenarioMetricRow(
      label: row.text('label'),
      directionLabel: row.text('direction_label'),
      winner: row.optionalText('winner'),
      valueDisplays: _cells(row.text('key'), columns),
    ),
];

/// One display string per column for the row named [key].
List<String> _cells(String key, List<ViewPayload> columns) => switch (key) {
  'proceeds' => <String>[
    for (final column in columns) column.text('proceeds.display'),
  ],
  'realized_pl' => <String>[
    for (final column in columns) column.text('realized_pl.display'),
  ],
  'est_tax' => <String>[
    for (final column in columns) column.text('est_tax.display'),
  ],
  'net_after_tax' => <String>[
    for (final column in columns) column.text('net_after_tax.display'),
  ],
  _ => throw const PayloadContractException(
    ContractFailure('rows[].key', 'a row this component can bind'),
  ),
};
