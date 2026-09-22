import 'package:finance_app/features/conversation/view/assistant_chips.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group(SuggestionChips, () {
    testWidgets('lists every chip in the backend order and reports a tap', (
      tester,
    ) async {
      final tapped = <Suggestion>[];
      const chips = <Suggestion>[
        Suggestion(key: 'tax-lots', label: 'Tax lots'),
        Suggestion(key: 'allocation', label: 'What do I hold?'),
        Suggestion(key: 'biggest-drivers', label: 'Biggest drivers'),
      ];
      await tester.pumpApp(
        Scaffold(
          body: SuggestionChips(suggestions: chips, onTap: tapped.add),
        ),
      );
      final xs = <double>[
        for (final chip in chips) tester.getTopLeft(find.text(chip.label)).dx,
      ];
      expect(xs, xs.toList()..sort());
      await tester.tap(find.text('What do I hold?'));
      expect(tapped, <Suggestion>[chips[1]]);
    });

    testWidgets('draws nothing without chips', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: SuggestionChips(
            suggestions: const <Suggestion>[],
            onTap: (_) {},
          ),
        ),
      );
      expect(find.byType(ListView), findsNothing);
    });
  });
}
