import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_footer.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scenario_comparison_harness.dart';

void main() {
  group(ScenarioComparisonFooter, () {
    testWidgets('reports the spread and names both ends', (tester) async {
      await pumpScenarioCard(tester, scenarioData());
      expect(find.text(ScenarioComparisonFooter.spreadCaption), findsOneWidget);
      expect(find.text(r'$2,520.00'), findsOneWidget);
      expect(
        find.text(ScenarioComparisonFooter.highestCaption),
        findsOneWidget,
      );
      expect(find.text(ScenarioComparisonFooter.lowestCaption), findsOneWidget);
      // The tokens the backend sent, not a method the client chose. Scoped
      // to the footer: the table heads two of its columns with the same two.
      final footer = find.byType(ScenarioComparisonFooter);
      expect(
        find.descendant(of: footer, matching: find.text('FIFO')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: footer, matching: find.text('LIFO')),
        findsOneWidget,
      );
      expect(find.text(ScenarioComparisonFooter.noDifference), findsNothing);
    });

    testWidgets('names neither end when the methods coincide', (tester) async {
      // spec `backend/0017` AC-6: a tie is reported as a tie, never
      // resolved by picking one.
      final payload = ViewPayload.fromJson(
        withoutSpreadEnds(scenarioExample()),
      );
      await pumpScenarioCard(
        tester,
        const ScenarioComparisonComponent().read(payload),
      );
      expect(find.text(ScenarioComparisonFooter.noDifference), findsOneWidget);
      expect(find.text(ScenarioComparisonFooter.highestCaption), findsNothing);
      expect(find.text(ScenarioComparisonFooter.lowestCaption), findsNothing);
      // The measured difference is still shown — it is a fact either way.
      expect(find.text(ScenarioComparisonFooter.spreadCaption), findsOneWidget);
    });

    testWidgets('renders every note verbatim and drops none', (tester) async {
      // N-9. The second note is the sentence that makes the card's silence
      // on "which method" legible rather than merely absent.
      await pumpScenarioCard(tester, scenarioData());
      expect(find.text('Before tax'), findsOneWidget);
      expect(find.text('Not advice'), findsOneWidget);
      expect(
        find.text(
          'The realised result and its short/long split, before any tax '
          'rate, fee or wash-sale rule.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'No method is recommended: which result is preferable depends on '
          'a tax situation this demo does not know.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows no note when the backend attached none', (tester) async {
      // `notes` defaults to `[]` in the contract.
      final example = <String, dynamic>{
        ...scenarioExample(),
        'notes': <dynamic>[],
      };
      await pumpScenarioCard(
        tester,
        const ScenarioComparisonComponent().read(ViewPayload.fromJson(example)),
      );
      expect(find.text('Before tax'), findsNothing);
      expect(find.text(ScenarioComparisonFooter.spreadCaption), findsOneWidget);
    });

    testWidgets('announces a note as one label-and-text unit', (tester) async {
      await pumpScenarioCard(tester, scenarioData());
      expect(
        find.bySemanticsLabel(RegExp('^Before tax[.] The realised result')),
        findsOneWidget,
      );
    });
  });
}
