import 'package:finance_app/features/sign_in/view/sign_in_email_check.dart';
import 'package:finance_app/features/sign_in/view/sign_in_email_form.dart';
import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  group('the e-mail check (GGU-155)', () {
    const bad = <String>['not-an-email', 'a@b', 'a b@c.d', '@c.de', 'a@.com'];
    const good = <String>['demo@somnio.dev', 'a.b+c@x.co.uk'];

    test('refuses what is not shaped like an address', () {
      for (final value in bad) {
        expect(looksLikeEmail(value), isFalse, reason: value);
      }
    });

    test('accepts what is', () {
      for (final value in good) {
        expect(looksLikeEmail(value), isTrue, reason: value);
      }
    });

    group('on the sign-in page', () {
      late FakeIdentity identity;

      Future<void> pump(WidgetTester tester) async {
        identity = FakeIdentity(isConfigured: true);
        await tester.pumpApp(
          SignInPage(link: Uri.parse('http://localhost:5173/')),
          authRepository: fakeAuthRepository(identity: identity),
          surfaceSize: const Size(390, 844),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('an invalid address shows an error and sends nothing', (
        tester,
      ) async {
        await pump(tester);
        await tester.enterText(find.byType(TextField), 'not-an-email');
        await tester.tap(find.text(SignInEmailForm.label));
        await tester.pumpAndSettle();
        expect(find.text(invalidEmailMessage), findsOneWidget);
        expect(identity.calls, isEmpty);
        expect(find.text(SignInEmailForm.linkSent), findsNothing);
      });

      testWidgets('typing again clears the error; a valid address sends', (
        tester,
      ) async {
        await pump(tester);
        await tester.enterText(find.byType(TextField), 'not-an-email');
        await tester.tap(find.text(SignInEmailForm.label));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'demo@somnio.dev');
        await tester.pump();
        expect(find.text(invalidEmailMessage), findsNothing);
        await tester.tap(find.text(SignInEmailForm.label));
        await tester.pumpAndSettle();
        expect(identity.calls, <String>['link:demo@somnio.dev']);
        expect(find.text(SignInEmailForm.linkSent), findsOneWidget);
      });
    });
  });
}
