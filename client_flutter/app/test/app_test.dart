import 'package:finance_a2ui_client/main.dart';
import 'package:finance_a2ui_client/src/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the login surface', (WidgetTester tester) async {
    await tester.pumpWidget(FinanceA2UiApp(config: AppConfig.fromMap({})));

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
  });
}
