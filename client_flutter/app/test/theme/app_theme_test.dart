import 'package:finance_a2ui_client/src/config/app_config.dart';
import 'package:finance_a2ui_client/src/features/landing/repository/landing_repository.dart';
import 'package:finance_a2ui_client/src/features/landing/view/landing_page.dart';
import 'package:finance_a2ui_client/src/theme/app_theme.dart';
import 'package:finance_a2ui_client/src/theme/finance_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pumps the real landing surface under a theme built from [tokens] and
  /// returns the colour the brand icon actually rendered with.
  Future<Color?> renderedAccent(
    WidgetTester tester,
    FinanceTokens tokens,
  ) async {
    final repository = LandingRepository(
      serverUrl: Uri.parse(AppConfig.defaultBackendBaseUrl),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(tokens),
        home: LandingPage(
          config: AppConfig.fromMap({}),
          onToggleTheme: () {},
          landingRepository: repository,
        ),
      ),
    );

    // MaterialApp animates theme changes, so the first frame after a pump
    // still carries the previous (lerped) tokens. Settle before reading.
    await tester.pumpAndSettle();

    return tester.widget<Icon>(find.byIcon(Icons.currency_bitcoin)).color;
  }

  testWidgets('swapping one token value re-themes a feature widget', (
    tester,
  ) async {
    const FinanceTokens tokensA = FinanceTokens.light;
    final FinanceTokens tokensB = tokensA.copyWith(
      brandAccent: const Color(0xFF0066FF),
    );

    final Color? before = await renderedAccent(tester, tokensA);
    final Color? after = await renderedAccent(tester, tokensB);

    expect(before, tokensA.brandAccent);
    expect(after, tokensB.brandAccent);
    expect(before, isNot(after));
  });

  testWidgets('light and dark themes both register the tokens', (
    tester,
  ) async {
    for (final ThemeData theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.extension<FinanceTokens>(), isNotNull);
    }
  });
}
