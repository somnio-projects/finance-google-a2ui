import 'package:finance_app/features/shell/view/shell_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(ShellTabBar, () {
    testWidgets('draws the four tabs the design names, in its order', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: ShellTabBar(currentIndex: 0, onSelected: (_) {}),
        ),
      );
      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ShellTabBar),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .toList();
      expect(
        labels,
        equals(<String>['Home', 'Holdings', 'Activity', 'Assistant']),
      );
    });

    testWidgets('weights the selected label and reports a tap by index', (
      tester,
    ) async {
      final tapped = <int>[];
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: ShellTabBar(
            currentIndex: 2,
            onSelected: tapped.add,
          ),
        ),
      );
      final activity = tester.widget<Text>(find.text('Activity'));
      final home = tester.widget<Text>(find.text('Home'));
      expect(activity.style?.fontWeight, FontWeight.w500);
      expect(home.style?.fontWeight, FontWeight.w400);
      await tester.tap(find.text('Assistant'));
      expect(tapped, equals(<int>[3]));
    });

    testWidgets('marks the selected tab for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: ShellTabBar(currentIndex: 1, onSelected: (_) {}),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Holdings')),
        matchesSemantics(
          label: 'Holdings',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home')),
        matchesSemantics(label: 'Home', isButton: true, hasSelectedState: true),
      );
      handle.dispose();
    });
  });
}
