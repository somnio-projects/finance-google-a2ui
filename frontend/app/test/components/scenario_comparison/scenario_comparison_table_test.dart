import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_header_row.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_table.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scenario_comparison_harness.dart';

void main() {
  group(ScenarioComparisonTable, () {
    testWidgets('rules each metric row with the measured hairline', (
      tester,
    ) async {
      await pumpScenarioCard(tester, scenarioData());
      final border = _rowBorder(tester);
      expect(border.top.color, const Color(0xFFF0EDF5));
      expect(border.top.width, 1);
    });

    testWidgets('rules the dark artboard a step darker', (tester) async {
      await pumpScenarioCard(
        tester,
        scenarioData(),
        brightness: Brightness.dark,
      );
      expect(_rowBorder(tester).top.color, const Color(0xFF202128));
    });

    testWidgets('heads each column with its method and the label', (
      tester,
    ) async {
      await pumpScenarioCard(tester, scenarioData());
      expect(find.text(ScenarioComparisonHeaderRow.metricHeading), findsOne);
      for (final method in <String>['FIFO', 'LIFO', 'HIFO']) {
        // Scoped to the table: the footer also prints two of these three,
        // as `spread.highest` and `spread.lowest`.
        expect(_inTable(find.text(method)), findsOneWidget);
      }
      // Rendered whole: splitting the label on its dash would be N-5.
      expect(find.text('FIFO — oldest lots first'), findsOneWidget);
      expect(find.text('HIFO — dearest lots first'), findsOneWidget);
    });

    testWidgets('names the four metrics the contract carries', (tester) async {
      await pumpScenarioCard(tester, scenarioData());
      for (final label in <String>[
        'Cost basis',
        'Realized P/L',
        'Short-term',
        'Long-term',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('renders no row at all when there are no scenarios', (
      tester,
    ) async {
      // The contract declares `columns` may be empty. The card then has
      // nothing to compare and says so by showing no figures, rather than
      // throwing on a list it could not index.
      final payload = ViewPayload.fromJson(
        withColumnCount(scenarioExample(), 0),
      );
      await pumpScenarioCard(
        tester,
        const ScenarioComparisonComponent().read(payload),
      );
      expect(_inTable(find.text('FIFO')), findsNothing);
      expect(find.text(r'$7,740.00'), findsNothing);
      expect(find.text('Cost basis'), findsOneWidget);
    });
  });
}

Finder _inTable(Finder matching) => find.descendant(
  of: find.byType(ScenarioComparisonTable),
  matching: matching,
);

Border _rowBorder(WidgetTester tester) {
  final decorated = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(ScenarioComparisonTable),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (decorated.decoration as BoxDecoration).border! as Border;
}
