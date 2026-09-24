import 'package:finance_app/features/shell/view/session_sheet.dart';
import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('the session sheet appearance row', () {
    Widget opener() => Builder(
      builder: (context) => TextButton(
        onPressed: () => showSessionSheet(context, onSignOut: () {}),
        child: const Text('open'),
      ),
    );

    testWidgets('lists the three choices and selects one', (tester) async {
      final controller = ThemeModeController();
      addTearDown(controller.dispose);
      await tester.pumpApp(opener(), themeMode: controller);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      for (final word in <String>['System', 'Light', 'Dark']) {
        expect(find.text(word), findsOneWidget);
      }
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(controller.value, ThemeMode.dark);
      // The app re-themed underneath the sheet.
      final context = tester.element(find.text('Appearance'));
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testWidgets('is absent when the tree has no controller', (tester) async {
      await tester.pumpApp(opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });
}
