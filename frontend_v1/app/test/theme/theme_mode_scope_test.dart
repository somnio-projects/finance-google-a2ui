import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ThemeModeController, () {
    test('starts on the device setting and notifies on a choice', () {
      final controller = ThemeModeController();
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);
      expect(controller.value, ThemeMode.system);
      controller.value = ThemeMode.dark;
      expect(controller.value, ThemeMode.dark);
      expect(notified, 1);
    });

    test('names every choice, in the order the sheet lists them', () {
      expect(
        ThemeModeController.choices.map(ThemeModeController.label),
        <String>['System', 'Light', 'Dark'],
      );
    });
  });

  group(ThemeModeScope, () {
    testWidgets('is absent when nothing put one in the tree', (tester) async {
      ThemeModeController? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = ThemeModeScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, isNull);
    });

    testWidgets('hands the controller down', (tester) async {
      final controller = (ThemeModeController()..value = ThemeMode.light);
      addTearDown(controller.dispose);
      ThemeModeController? seen;
      await tester.pumpWidget(
        ThemeModeScope(
          controller: controller,
          child: Builder(
            builder: (context) {
              seen = ThemeModeScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, same(controller));
    });
  });
}
