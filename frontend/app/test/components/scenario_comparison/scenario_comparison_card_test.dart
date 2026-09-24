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
      expect(find.text('NVIDIA Corp'), findsOneWidget);
    });

    testWidgets('states the sale once, as caption and figure', (tester) async {
      await pumpScenarioCard(tester, scenarioData());
      expect(find.byType(ScenarioFact), findsNWidgets(7));
      expect(
        find.text(ScenarioComparisonSubject.symbolCaption),
        findsOneWidget,
      );
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text(r'$1,204.66'), findsOneWidget);
      expect(find.text(r'$36,139.80'), findsOneWidget);
    });

    testWidgets('puts every display string on screen verbatim', (tester) async {
      // N-1: the figures are exactly the strings the backend formatted —
      // the sign is baked in and nothing here prepends one.
      await pumpScenarioCard(tester, scenarioData());
      expect(find.text(r'$22,800.00'), findsOneWidget);
      expect(find.text(r'$28,800.00'), findsNWidgets(2));
      expect(find.text(r'+$13,339.80'), findsNWidgets(2));
      expect(find.text(r'+$7,339.80'), findsNWidgets(4));
      expect(find.text(r'$0.00'), findsNWidgets(3));
      expect(find.text(r'$6,000.00'), findsOneWidget);
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      // N-4: `amount` exists for chart geometry. This card draws no chart,
      // so it reads no raw member at all.
      await pumpScenarioCard(tester, scenarioData());
      for (final raw in <String>[
        '22800.00',
        '28800.00',
        '13339.800000',
        '7339.800000',
        '1204.66',
        '36139.800000',
        '6000.000000',
        '0',
      ]) {
        expect(find.text(raw), findsNothing, reason: 'raw $raw reached a Text');
      }
    });

    testWidgets('names no winner anywhere on the card', (tester) async {
      // spec `backend/0017` OD-4 / `specs/frontend/0004` OD-3. The design
      // ships a `★ Recommended` badge and a green "best on that row" cell;
      // the contract ships neither field, and the card invents neither.
      await pumpScenarioCard(tester, scenarioData());
      for (final word in <String>[
        'Recommended',
        '★ Recommended',
        'best on that row',
        'higher is better ▲',
        'lower is better ▼',
      ]) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    });
  });
}
