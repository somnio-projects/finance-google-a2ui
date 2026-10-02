import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:finance_app/theme/theme_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'the sign-in screen can be seen in either theme before signing in',
    (tester) async {
      final controller = (ThemeModeController()..value = ThemeMode.light);
      addTearDown(controller.dispose);
      await tester.pumpApp(
        SignInPage(link: Uri.parse('http://localhost:5173/')),
        authRepository: fakeAuthRepository(),
        themeMode: controller,
        surfaceSize: const Size(390, 844),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ThemeToggleButton.toggleKey), findsOneWidget);
      await tester.tap(find.byKey(ThemeToggleButton.toggleKey));
      await tester.pumpAndSettle();
      expect(controller.value, ThemeMode.dark);
      final context = tester.element(find.text('Portfolio companion'));
      expect(Theme.of(context).brightness, Brightness.dark);
    },
  );
}
