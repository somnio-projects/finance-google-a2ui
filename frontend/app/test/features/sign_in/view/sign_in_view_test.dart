import 'package:finance_app/features/sign_in/view/sign_in_email_form.dart';
import 'package:finance_app/features/sign_in/view/sign_in_footer.dart';
import 'package:finance_app/features/sign_in/view/sign_in_google_button.dart';
import 'package:finance_app/features/sign_in/view/sign_in_hero.dart';
import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  group(SignInPage, () {
    Future<AuthRepository> pump(
      WidgetTester tester, {
      AuthRepository? auth,
      Uri? link,
      Brightness brightness = Brightness.light,
    }) async {
      final repository = auth ?? fakeAuthRepository();
      await tester.pumpApp(
        SignInPage(link: link ?? Uri.parse('http://localhost:5173/')),
        authRepository: repository,
        brightness: brightness,
        surfaceSize: const Size(390, 844),
      );
      // The sign-in policy is read when the page builds its bloc, and the
      // invite line only exists once it answers (spec backend/0043).
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets("prints the design's copy, and no tab bar", (tester) async {
      await pump(tester);
      expect(find.text(SignInHero.title), findsOneWidget);
      expect(find.text(SignInHero.pitch), findsOneWidget);
      expect(find.text(SignInGoogleButton.label), findsOneWidget);
      expect(find.text('or'), findsOneWidget);
      expect(find.text(SignInEmailForm.label), findsOneWidget);
      expect(find.text(SignInInviteLine.link), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.byType(GoogleMark), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the focused field shows the helper (L2)', (tester) async {
      await pump(tester);
      expect(find.text(SignInEmailForm.helper), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.text(SignInEmailForm.helper), findsOneWidget);
    });

    testWidgets('an empty e-mail only focuses the field', (tester) async {
      final repository = await pump(tester);
      await tester.tap(find.text(SignInEmailForm.label));
      await tester.pump();
      expect(repository.state.status, AuthStatus.unknown);
      expect(find.text(SignInEmailForm.helper), findsOneWidget);
    });

    testWidgets('a provisioned e-mail signs in on the local stack', (
      tester,
    ) async {
      final repository = await pump(tester);
      await tester.enterText(find.byType(TextField), ' demo@somnio.dev ');
      await tester.tap(find.text(SignInEmailForm.label));
      await tester.pumpAndSettle();
      expect(repository.state.allowsShell, isTrue);
    });

    testWidgets(
      "an uninvited e-mail shows the backend's sentence and Dismiss (L3)",
      (tester) async {
        await pump(tester);
        await tester.enterText(find.byType(TextField), 'nobody@y.test');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          find.text("This account isn't provisioned for the preview."),
          findsOneWidget,
        );
        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();
        expect(
          find.text("This account isn't provisioned for the preview."),
          findsNothing,
        );
      },
    );

    testWidgets('Google without a provider says so, verbatim', (tester) async {
      await pump(tester);
      await tester.tap(find.text(SignInGoogleButton.label));
      await tester.pumpAndSettle();
      expect(find.text(googleNotConfigured), findsOneWidget);
    });

    test('names the repository and the compliance folder', () {
      expect(SignInFooter.github.host, 'github.com');
      expect(SignInFooter.privacy.path, endsWith('docs/compliance'));
    });
  });

  group(GoogleMarkPainter, () {
    test('never repaints', () {
      expect(
        const GoogleMarkPainter().shouldRepaint(const GoogleMarkPainter()),
        isFalse,
      );
    });
  });
}
