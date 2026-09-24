import 'package:finance_app/features/sign_in/view/sign_in_footer.dart';
import 'package:finance_app/features/sign_in/view/sign_in_google_button.dart';
import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/pump_app.dart';

/// The screen may not claim a door the backend has not named (backend/0043).
///
/// Three cases, and the interesting one is the third: a policy that never
/// arrives must look like the open one, not like the invite-only one. Showing
/// the design's sentence by default is what made this a defect in the first
/// place — a deployment saying *invite-only* when it admits everybody.
void main() {
  group(SignInPage, () {
    Future<void> open(WidgetTester tester, AuthRepository auth) async {
      await tester.pumpApp(
        SignInPage(link: Uri.parse('http://localhost:5173/')),
        authRepository: auth,
        surfaceSize: const Size(390, 844),
      );
    }

    Future<void> pump(WidgetTester tester, AuthRepository auth) async {
      await open(tester, auth);
      await tester.pumpAndSettle();
    }

    testWidgets('an invite-only deployment shows the line and the link', (
      tester,
    ) async {
      // The fake's default: invite-only is the registry it simulates.
      await pump(tester, fakeAuthRepository());
      expect(find.text(SignInInviteLine.sentence), findsOneWidget);
      expect(find.text(SignInInviteLine.link), findsOneWidget);
    });

    testWidgets('an open deployment shows neither', (tester) async {
      await pump(tester, fakeAuthRepository(policy: SignInPolicy.open));
      expect(find.text(SignInInviteLine.sentence), findsNothing);
      expect(find.text(SignInInviteLine.link), findsNothing);
      // The rest of the screen is untouched: this removes a claim, not a
      // way in.
      expect(find.text(SignInGoogleButton.label), findsOneWidget);
    });

    testWidgets('a policy that cannot be read shows neither', (tester) async {
      await pump(tester, fakeAuthRepository(policy: null));
      expect(find.text(SignInInviteLine.sentence), findsNothing);
      expect(find.text(SignInInviteLine.link), findsNothing);
      expect(find.text(SignInGoogleButton.label), findsOneWidget);
    });

    testWidgets('the line is absent before the answer arrives', (tester) async {
      // The first frame only: the read is in flight, the policy is unknown,
      // and the screen is making no claim yet. Then it settles and does.
      await open(tester, fakeAuthRepository());
      expect(find.text(SignInInviteLine.sentence), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text(SignInInviteLine.sentence), findsOneWidget);
    });
  });
}
