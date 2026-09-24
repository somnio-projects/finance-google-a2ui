import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_app/features/sign_in/view/sign_in_email_form.dart';
import 'package:finance_app/features/sign_in/view/sign_in_google_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('a busy form disables both buttons and spins', (tester) async {
    var pressed = 0;
    await tester.pumpApp(
      Scaffold(
        body: Column(
          children: <Widget>[
            SignInGoogleButton(busy: true, onPressed: () => pressed++),
            SignInEmailForm(
              state: const SignInState(
                status: SignInStatus.busy,
                email: 'a@b.test',
              ),
              usesEmailLink: false,
              onSubmitted: (_) => pressed++,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text(SignInGoogleButton.label));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(pressed, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'a@b.test',
    );
  });
}
