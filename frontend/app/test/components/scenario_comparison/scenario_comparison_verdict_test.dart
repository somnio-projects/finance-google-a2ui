import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_value_cell.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scenario_comparison_harness.dart';

/// What the redesign added: a marked winner, a recommended column, a badge
/// and a footer sentence (backend spec 0051).
///
/// Every one of them is **read**. The card holds no raw member, so it could
/// not compare two cells even if it wanted to; what these tests guard is that
/// it does not *invent* a mark, and that it draws the one the backend sent.
void main() {
  group('ScenarioComparison verdict', () {
    ScenarioComparisonData data() => scenarioData();

    testWidgets('ticks exactly the cells the backend marked', (tester) async {
      final model = data();
      final marked = model.metrics.where((row) => row.winner != null).length;
      await pumpScenarioCard(tester, model);

      expect(marked, greaterThan(0));
      expect(find.byType(ScenarioValueCell), findsWidgets);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(marked));
    });

    testWidgets('marks nothing when every row ties', (tester) async {
      // A tie names nobody, and the client must not fill the gap.
      final payload = ViewPayload.fromJson(withoutWinners(scenarioExample()));
      await pumpScenarioCard(
        tester,
        const ScenarioComparisonComponent().read(payload),
      );

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('a marked cell announces why it is marked', (tester) async {
      // The tint is not the only way to know which column won.
      final handle = tester.ensureSemantics();
      final model = data();
      final row = model.metrics.firstWhere((row) => row.winner != null);
      final index = model.columns.indexWhere(
        (column) => column.key == row.winner,
      );
      await pumpScenarioCard(tester, model);

      expect(
        find.bySemanticsLabel(
          '${row.valueDisplays[index]}, ${ScenarioValueCell.winnerLabel}',
        ),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('draws every row name and its direction hint', (tester) async {
      // Both are server strings since spec 0051 — a Dart constant would not
      // follow the `locale` option (N-9).
      final model = data();
      await pumpScenarioCard(tester, model);

      for (final row in model.metrics) {
        expect(find.text(row.directionLabel), findsWidgets);
      }
    });

    testWidgets('draws each column caption and the recommended tag', (
      tester,
    ) async {
      final model = data();
      await pumpScenarioCard(tester, model);

      for (final column in model.columns) {
        expect(find.text(column.caption), findsWidgets);
        if (column.recommendationLabel case final tag?) {
          expect(find.text(tag), findsOneWidget);
        }
      }
    });

    testWidgets('draws the badge and the footer sentence verbatim', (
      tester,
    ) async {
      final model = data();
      await pumpScenarioCard(tester, model);

      expect(find.text(model.summary.badge), findsOneWidget);
      expect(find.text(model.summary.text), findsOneWidget);
    });

    test('a row key this component cannot bind is a contract failure', () {
      // N-3: the schema publishes a closed set, so an unknown key means the
      // backend moved. Skipping the row would lose it silently.
      expect(
        () => const ScenarioComparisonComponent().read(
          ViewPayload.fromJson(withUnknownRow(scenarioExample())),
        ),
        throwsA(isA<PayloadContractException>()),
      );
    });
  });
}
