import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:finance_app/theme/theme_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(ThemeToggleButton, () {
    testWidgets('draws nothing without a controller in scope', (tester) async {
      await tester.pumpApp(const ThemeToggleButton());
      expect(find.byKey(ThemeToggleButton.toggleKey), findsNothing);
    });

    testWidgets('offers the opposite of the theme that is showing', (
      tester,
    ) async {
      final controller = (ThemeModeController()..value = ThemeMode.light);
      addTearDown(controller.dispose);
      await tester.pumpApp(
        const Scaffold(body: ThemeToggleButton()),
        themeMode: controller,
      );
      expect(find.byTooltip('Switch to dark appearance'), findsOneWidget);
      await tester.tap(find.byKey(ThemeToggleButton.toggleKey));
      await tester.pumpAndSettle();
      expect(controller.value, ThemeMode.dark);
      expect(find.byTooltip('Switch to light appearance'), findsOneWidget);
      await tester.tap(find.byKey(ThemeToggleButton.toggleKey));
      await tester.pumpAndSettle();
      expect(controller.value, ThemeMode.light);
    });
  });
}
