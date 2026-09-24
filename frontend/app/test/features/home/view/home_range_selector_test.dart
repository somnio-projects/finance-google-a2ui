import 'package:finance_app/features/home/view/home_range_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group(HomeRangeSelector, () {
    testWidgets('prints the six captions the design prints, in order', (
      tester,
    ) async {
      await tester.pumpApp(
        HomeRangeSelector(selected: '1d', onSelected: (_) {}),
      );
      final captions = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .toList();
      expect(captions, equals(<String>['1D', '1W', '1M', 'YTD', '1Y', 'All']));
      expect(
        rangeSegments.map((s) => s.code),
        equals(<String>['1d', '1w', '1m', 'ytd', '1y', 'all']),
      );
    });

    testWidgets('reports the declared code of the segment tapped', (
      tester,
    ) async {
      final picked = <String>[];
      await tester.pumpApp(
        HomeRangeSelector(selected: '1d', onSelected: picked.add),
      );
      await tester.tap(find.text('YTD'));
      expect(picked, equals(<String>['ytd']));
    });

    testWidgets('fills only the selected segment', (tester) async {
      await tester.pumpApp(
        HomeRangeSelector(selected: '1m', onSelected: (_) {}),
      );
      final selected = tester.widget<Text>(find.text('1M'));
      final other = tester.widget<Text>(find.text('1D'));
      expect(selected.style?.color, isNot(equals(other.style?.color)));
    });
  });
}
