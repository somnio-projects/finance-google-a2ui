import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scenario_comparison_harness.dart';

/// What the card draws when the payload marks nobody.
///
/// Its own file because the card suite is at the budget, and because this is
/// the one assertion that survived spec 0017 OD-4 being superseded: the card
/// reads a ranking, it never invents one.
void main() {
  group('ScenarioComparisonCard silence', () {
    testWidgets('names no winner when the payload names none', (tester) async {
      // **This test used to assert the opposite and that is the point.** It
      // read *"names no winner anywhere on the card"*, because spec
      // `backend/0017` OD-4 held that picking a lot method for someone is tax
      // advice — right while there was no declared rate to rank by. Backend
      // spec 0051 made the rate a printed, bounded option, and the card reads
      // the ranking the server performed.
      //
      // What survives is the half that still holds: the card **invents**
      // nothing. Given a payload that marks nobody, it draws no tag, no tick
      // and no word of its own.
      final payload = ViewPayload.fromJson(withoutVerdict(scenarioExample()));
      await pumpScenarioCard(
        tester,
        const ScenarioComparisonComponent().read(payload),
      );

      expect(find.byIcon(Icons.check), findsNothing);
      for (final word in <String>[
        'Recommended',
        '★ Recommended',
        'best on that row',
      ]) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
      // `higher is better ▲` **is** drawn here, and used to be on the list
      // above. It is not a verdict: it is `rows[].direction_label`, which
      // the backend writes for every row whether or not anyone won it, and
      // the arrow is part of that string rather than a glyph the client
      // prepends (N-1). Silence is about marks the card would have had to
      // invent, and this is one it was given.
      expect(find.textContaining('higher is better ▲'), findsWidgets);
    });
  });
}
