import 'package:finance_app/features/sign_in/view/sign_in_email_form.dart';
import 'package:finance_app/features/sign_in/view/sign_in_footer.dart';
import 'package:finance_app/features/sign_in/view/sign_in_google_button.dart';
import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:finance_app/theme/login_palettes.dart';
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
      return repository;
    }

    testWidgets('with a provider, e-mail sends a link and says so', (
      tester,
    ) async {
      await pump(
        tester,
        auth: fakeAuthRepository(identity: FakeIdentity(isConfigured: true)),
      );
      await tester.enterText(find.byType(TextField), 'demo@somnio.dev');
      await tester.tap(find.text(SignInEmailForm.label));
      await tester.pumpAndSettle();
      expect(find.text(SignInEmailForm.linkSent), findsOneWidget);
    });

    testWidgets(
      'coming back through the link asks to confirm the e-mail and finishes',
      (tester) async {
        final identity = FakeIdentity(isConfigured: true);
        final repository = await pump(
          tester,
          auth: fakeAuthRepository(
            identity: identity,
            provisionedEmails: const <String>{'a@b.test'},
          ),
          link: Uri.parse(
            'http://localhost:5173/sign-in?mode=signIn&oobCode=x',
          ),
        );
        expect(find.text(SignInGoogleButton.label), findsNothing);
        expect(find.text(SignInEmailForm.finishLabel), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'a@b.test');
        await tester.tap(find.text(SignInEmailForm.finishLabel));
        await tester.pumpAndSettle();
        expect(identity.calls, <String>['linked:a@b.test']);
        expect(repository.state.allowsShell, isTrue);
      },
    );

    testWidgets('Request access opens the sheet and acknowledges', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text(SignInInviteLine.link));
      await tester.pumpAndSettle();
      expect(find.text('Request access'), findsWidgets);
      await tester.enterText(find.byType(TextField).last, 'you@company.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(SignInInviteLine.sent), findsOneWidget);
    });

    testWidgets('the sheet ignores an empty e-mail', (tester) async {
      await pump(tester);
      await tester.tap(find.text(SignInInviteLine.link));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Send request'), findsOneWidget);
    });

    testWidgets('wears the dark artboard', (tester) async {
      await pump(tester, brightness: Brightness.dark);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, loginTokensDark.page);
      expect(tester.takeException(), isNull);
    });
  });

  group(SignInFooter, () {});
}
