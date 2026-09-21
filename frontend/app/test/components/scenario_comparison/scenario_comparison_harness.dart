import 'package:finance_app/components/scenario_comparison/scenario_comparison_card.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// The A2UI component name the backend publishes for this view.
///
/// The design *index* still calls it `ComparisonCard` while the design's own
/// detail page and the backend both say `ScenarioComparison`. The schema
/// block is the authoritative declaration, and
/// `catalog_contract_test.dart` checks this against the snapshot.
const String scenarioComponentName = 'ScenarioComparison';

/// The backend's published example for this view, read from the generated
/// snapshot rather than copied (`.claude/rules/frontend/testing.md` §5).
Map<String, dynamic> scenarioExample() =>
    CatalogSnapshot.load().exampleFor(scenarioComponentName);

/// The example, read into the model the card draws.
ScenarioComparisonData scenarioData() => const ScenarioComparisonComponent()
    .read(ViewPayload.fromJson(scenarioExample()));

/// The card's outer width on the design's 1024 artboard.
///
/// Its content box is therefore `571.367 − 2×1 border − 2×18 padding =
/// 533.367`, which is the width the designer's grid tracks were measured at
/// and the width `scenario_comparison_table_test.dart` asserts against.
const double designCardWidth = 571.367;

/// The design's content width inside the card.
const double designContentWidth = 533.367;

/// Pumps [data] as the card, at the design's width, in the real theme.
///
/// Scrollable because the card is taller than the 600 px test surface; the
/// widths a geometry assertion reads are unaffected by it.
Future<void> pumpScenarioCard(
  WidgetTester tester,
  ScenarioComparisonData data, {
  Brightness brightness = Brightness.light,
}) => tester.pumpApp(
  Center(
    child: SingleChildScrollView(
      child: SizedBox(
        width: designCardWidth,
        child: ScenarioComparisonCard(data: data),
      ),
    ),
  ),
  brightness: brightness,
);

/// The example with its `columns` trimmed to the first [count] entries.
///
/// The design draws a two-scenario and a three-scenario artboard and the
/// leading track's share differs between them, so both are exercised.
Map<String, dynamic> withColumnCount(Map<String, dynamic> example, int count) {
  final columns = (example['columns']! as List<dynamic>).take(count).toList();
  return <String, dynamic>{...example, 'columns': columns};
}

/// The example with `spread` reporting that no method differed.
///
/// The shape spec `backend/0017` AC-6 describes: when a sale closes the
/// position every method consumes every lot, so the columns coincide, and
/// the backend names neither end rather than picking a winner out of a tie.
Map<String, dynamic> withoutSpreadEnds(Map<String, dynamic> example) {
  final spread = Map<String, dynamic>.from(example['spread']! as Map);
  spread['differs'] = false;
  spread['highest'] = null;
  spread['lowest'] = null;
  return <String, dynamic>{...example, 'spread': spread};
}

/// The example with `spread` naming only its **highest** end.
///
/// Permitted by the contract and not hypothetical: `spread.highest` and
/// `spread.lowest` are each `default null`, **independently**, and neither is
/// tied to `spread.differs`. A card that required both ends would have left
/// this payload undefined on screen.
Map<String, dynamic> withOneSpreadEnd(Map<String, dynamic> example) {
  final spread = Map<String, dynamic>.from(example['spread']! as Map);
  spread['lowest'] = null;
  return <String, dynamic>{...example, 'spread': spread};
}

/// The example with [path] removed from its root, for the N-3 path.
Map<String, dynamic> without(Map<String, dynamic> example, String path) =>
    Map<String, dynamic>.from(example)..remove(path);
