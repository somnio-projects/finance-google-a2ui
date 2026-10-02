import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scenario_comparison_harness.dart';

/// How the card reads the redesign's row-major table (backend spec 0051).
///
/// Its own file because the component suite is at the budget, and because
/// these ask a different question: not *"is the figure right"* but *"where
/// did the row name come from"*.
void main() {
  group('ScenarioComparisonComponent rows', () {
    const component = ScenarioComparisonComponent();
    final example = scenarioExample();

    test('takes its row names from the payload, not from itself', () {
      // These four used to be Dart constants, and `specs/frontend/0004` OD-1
      // recorded the gap: the contract had no metric list to take them from.
      // Backend spec 0051 ships one, so a renamed row is a changed contract
      // rather than a changed constant (N-9).
      final data = component.read(ViewPayload.fromJson(example));
      final rows = (example['rows']! as List<dynamic>)
          .cast<Map<String, dynamic>>();

      expect(rows, isNotEmpty);
      expect(
        data.metrics.map((row) => row.label),
        rows.map((row) => row['label']),
      );
      expect(
        data.metrics.map((row) => row.directionLabel),
        rows.map((row) => row['direction_label']),
      );
      expect(
        data.metrics.map((row) => row.winner),
        rows.map((row) => row['winner']),
      );
    });

    test('pairs every row with the column field of that name', () {
      final data = component.read(ViewPayload.fromJson(example));
      final columns = (example['columns']! as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final (index, row) in data.metrics.indexed) {
        final key =
            ((example['rows']! as List<dynamic>)[index]
                as Map<String, dynamic>)['key'];
        expect(row.valueDisplays, <String>[
          for (final column in columns)
            (column[key]! as Map<String, dynamic>)['display']! as String,
        ]);
      }
    });

    test('reads the winner and never decides one', () {
      // N-2: the card holds no raw member, so it could not compare two cells
      // even if it wanted to. What it must not do is *invent* a mark.
      final data = component.read(ViewPayload.fromJson(example));
      final keys = data.columns.map((column) => column.key).toSet();

      for (final row in data.metrics) {
        if (row.winner != null) {
          expect(keys, contains(row.winner));
        }
      }
    });
  });
}
