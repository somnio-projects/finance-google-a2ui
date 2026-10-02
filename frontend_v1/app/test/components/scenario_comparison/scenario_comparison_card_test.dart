import 'package:finance_app/components/scenario_comparison/scenario_comparison_card.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_subject.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scenario_comparison_harness.dart';

void main() {
  group(ScenarioComparisonCard, () {
    testWidgets('wears the chrome measured from the design', (tester) async {
      // Asserted as constants rather than left to a raster: a 1 px change in
      // the bottom inset is far below what a cross-platform golden resolves
      // (ADR-L D-15), and this card's bottom inset is the one value that
      // differs from the waterfall's.
      expect(ScenarioComparisonCard.radius, 16);
      expect(
        ScenarioComparisonCard.padding,
        const EdgeInsets.fromLTRB(18, 16, 18, 15),
      );
      await pumpScenarioCard(tester, scenarioData());
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(ScenarioComparisonCard),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, const Color(0xFFFDFBFF));
      expect(decoration.border!.top.color, const Color(0xFFEAE7F0));
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('wears the dark artboard in the dark theme', (tester) async {
      await pumpScenarioCard(
        tester,
        scenarioData(),
        brightness: Brightness.dark,
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(ScenarioComparisonCard),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, const Color(0xFF15161C));
      expect(decoration.border!.top.color, const Color(0xFF24252D));
    });

    testWidgets('shows the title and the position it is about', (tester) async {
      await pumpScenarioCard(tester, scenarioData());
      expect(find.text('Same sale, different lot method'), findsOneWidget);
      expect(find.text('Bitcoin'), findsOneWidget);
    });

    testWidgets('states the sale once, as caption and figure', (tester) async {
      await pumpScenarioCard(tester, scenarioData());
      expect(find.byType(ScenarioFact), findsNWidgets(7));
      expect(
        find.text(ScenarioComparisonSubject.symbolCaption),
        findsOneWidget,
      );
      expect(find.text('BTC'), findsOneWidget);
      expect(find.text('0.25'), findsOneWidget);
      expect(find.text(r'$64,250.00'), findsOneWidget);
      // Four times over: once in the subject strip, once per column. The
      // sale is the same in every column by construction, and the frame
      // repeats it so the row-major table is uniform (backend spec 0051
      // OD-3).
      expect(find.text(r'$16,062.50'), findsNWidgets(4));
    });

    testWidgets('puts every display string on screen verbatim', (tester) async {
      // N-1: the figures are exactly the strings the backend formatted —
      // the sign is baked in and nothing here prepends one.
      await pumpScenarioCard(tester, scenarioData());
      // FIFO's estimated tax at the declared default rates, as one literal
      // the reader can check by hand.
      expect(find.text(r'$1,059.38'), findsOneWidget);
      // The rest is derived from the model rather than listed: the table's
      // rows are the backend's since spec 0051, so a hand-counted list would
      // have to be rewritten every time design adds one — and would be
      // asserting the fixture rather than the binding.
      final data = scenarioData();
      for (final row in data.metrics) {
        for (final display in row.valueDisplays) {
          expect(find.text(display), findsWidgets, reason: display);
        }
      }
      expect(find.text(data.spread.amountDisplay), findsWidgets);
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      // N-4: `amount` exists for chart geometry. This card draws no chart,
      // so it reads no raw member at all.
      await pumpScenarioCard(tester, scenarioData());
      for (final raw in <String>[
        '9000.00',
        '10617.00',
        '7062.5000000000',
        '5445.5000000000',
        '64250.00',
        '16062.5000000000',
        '1617.0000000000',
        '0',
      ]) {
        expect(find.text(raw), findsNothing, reason: 'raw $raw reached a Text');
      }
    });
  });
}
