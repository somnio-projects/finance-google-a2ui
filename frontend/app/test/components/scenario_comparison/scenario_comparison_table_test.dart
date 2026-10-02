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
      // `columns[].caption` is the design's second line.
      expect(_inTable(find.text('default order')), findsOneWidget);
      // And `columns[].label` — which the redesigned frame has no slot for
      // — is still on the screen, announced whole rather than drawn. It is
      // never split on its dash; reading structure out of a server string
      // would be N-5.
      // `findsWidgets`, not `findsOneWidget`: a semantics label matches
      // every element carrying it, and a `Semantics` node is two.
      expect(
        find.bySemanticsLabel(RegExp('FIFO — oldest lots first')),
        findsWidgets,
      );
      expect(
        find.bySemanticsLabel(RegExp('HIFO — dearest lots first')),
        findsWidgets,
      );
    });

    testWidgets('names every metric the contract carries', (tester) async {
      // Read from the payload rather than listed here: the row names are the
      // backend's since spec 0051, so a list in this file would assert that
      // a Dart constant equals itself.
      final data = scenarioData();
      await pumpScenarioCard(tester, data);

      expect(data.metrics, isNotEmpty);
      for (final row in data.metrics) {
        // Scoped to the table: `Proceeds` is also a caption in the subject
        // strip above it, because one sale is the card's premise and the
        // frame repeats it per column (backend spec 0051 OD-3).
        expect(_inTable(find.text(row.label)), findsOneWidget);
      }
    });

    testWidgets('renders no row at all when there are no scenarios', (
      tester,
    ) async {
      // Unreachable through the contract — `methods` declares
      // `minItems: 2` — so this is a *defined* answer rather than a
      // declared one, the same honest framing `metricFlex(4)` gets. The
      // card shows no figures rather than throwing on a list it could not
      // index.
      final payload = ViewPayload.fromJson(
        withColumnCount(scenarioExample(), 0),
      );
      await pumpScenarioCard(
        tester,
        const ScenarioComparisonComponent().read(payload),
      );
      expect(_inTable(find.text('FIFO')), findsNothing);
      expect(find.text(r'$7,740.00'), findsNothing);
      // The row names survive an empty comparison: they are the backend's
      // `rows[]`, which does not depend on how many columns there are.
      // `Cost basis` used to be one of them and is not a drawn row any more
      // — the frame's four are Proceeds, Realized gain, Est. tax and Net
      // after tax (backend spec 0051). The field is still served.
      expect(find.text('Realized gain'), findsOneWidget);
    });
  });
}

Finder _inTable(Finder matching) => find.descendant(
  of: find.byType(ScenarioComparisonTable),
  matching: matching,
);

/// The hairline above the first metric row.
///
/// Selected by the property that makes it a row rule — a border on the top
/// edge and nothing else — rather than by being the table's first
/// `DecoratedBox`. The redesign put two decorated boxes *above* the rows,
/// the recommendation pill and a winning cell's tint, and `.first` silently
/// started reading the pill's border. A finder that keeps matching after the
/// thing it was aimed at moved is worse than one that breaks.
Border _rowBorder(WidgetTester tester) {
  final boxes = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(ScenarioComparisonTable),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.border)
      .whereType<Border>()
      .where(
        (border) =>
            border.top != BorderSide.none && border.left == BorderSide.none,
      );
  return boxes.first;
}
