/// The window between "the provider vouched" and "the registry answered".
///
/// The TL asked for it in as many words: *"si se loguea debería haber un
/// cartel o un spinner que te diga que está aprovisionando"*. Before this it
/// showed the sign-in form unchanged, so somebody who had just signed in saw
/// the button they had pressed and concluded it had failed.
library;

import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_app/features/sign_in/view/sign_in_provisioning_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('SignInProvisioningNote', () {
    testWidgets('says what is happening, with a spinner', (tester) async {
      await tester.pumpApp(const SignInProvisioningNote());

      expect(find.text(SignInProvisioningNote.message), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('the provisioning state', () {
    test('keeps the buttons disabled', () {
      // Offering the buttons again mid-provisioning invites a second
      // sign-in on top of the first.
      const state = SignInState(status: SignInStatus.provisioning);

      expect(state.isBusy, isTrue);
      expect(state.isProvisioning, isTrue);
    });

    test('is not the same as a request merely being in flight', () {
      // `busy` covers the popup, where "setting up your account" is a lie.
      const busy = SignInState(status: SignInStatus.busy);

      expect(busy.isBusy, isTrue);
      expect(busy.isProvisioning, isFalse);
    });

    test('an idle screen says nothing about provisioning', () {
      const idle = SignInState();

      expect(idle.isBusy, isFalse);
      expect(idle.isProvisioning, isFalse);
    });
  });
}
