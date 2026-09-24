import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_rows.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scenario_comparison_harness.dart';

/// The card's one cross-column figure, and the one place the client could
/// have been tempted to compute something.
///
/// `spread.amount.display` arrives formatted and the two ends arrive as
/// method tokens; nothing here subtracts one column from another (N-2).
/// Split out of `_component_test.dart` for the budget — these four are all
/// about `spread` and nothing else is.
void main() {
  group(ScenarioSpread, () {
    const component = ScenarioComparisonComponent();
    late Map<String, dynamic> example;

    setUp(() {
      example = scenarioExample();
    });

    test('binds the measured difference and names both ends', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.spread.amountDisplay, r'$6,000.00');
      expect(data.spread.highest, 'FIFO');
      expect(data.spread.lowest, 'LIFO');
      expect(data.spread.namesAnyEnd, isTrue);
    });

    test('agrees with the payload flag it deliberately does not read', () {
      // `namesAnyEnd` stands in for `spread.differs`, which `ViewPayload`
      // cannot read (`specs/frontend/0004` OD-2). Sound only while the
      // contract keeps them in step, so the **published** example is checked
      // against the flag it actually carries.
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.spread.namesAnyEnd, (example['spread']! as Map)['differs']);
    });

    test('names any end the backend named, not only both of them', () {
      // The contract makes `highest` and `lowest` `default null`
      // **independently**, so one-end-only is a payload it permits. This is
      // the assertion that distinguishes `||` from `&&`: under `&&` the card
      // would drop a name the backend sent and claim the methods coincide.
      final one = component.read(
        ViewPayload.fromJson(withOneSpreadEnd(example)),
      );
      expect(one.spread.highest, 'FIFO');
      expect(one.spread.lowest, isNull);
      expect(one.spread.namesAnyEnd, isTrue);
    });

    test('names no end when the backend named neither', () {
      final flat = withoutSpreadEnds(example);
      final same = component.read(ViewPayload.fromJson(flat));
      expect(same.spread.namesAnyEnd, isFalse);
      expect(same.spread.highest, isNull);
      expect(same.spread.lowest, isNull);
    });
  });
}
