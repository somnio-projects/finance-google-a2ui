import 'package:finance_app/auth/auth_gate.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';

void main() {
  group(AuthGate, () {
    test('sends a stranger to sign-in and leaves them there', () {
      final gate = AuthGate(fakeAuthRepository());
      addTearDown(gate.dispose);
      expect(gate.state.status, AuthStatus.unknown);
      expect(gate.redirectFor(AppRoutes.home), AppRoutes.signIn);
      expect(gate.redirectFor(AppRoutes.activity), AppRoutes.signIn);
      expect(gate.redirectFor(AppRoutes.signIn), isNull);
    });

    test(
      'lets a signed-in person through, and off the sign-in screen',
      () async {
        final repository = fakeAuthRepository();
        final gate = AuthGate(repository);
        addTearDown(gate.dispose);
        var notified = 0;
        gate.addListener(() => notified++);
        await repository.signInWithEmail(
          'demo@somnio.dev',
          continueUrl: Uri.parse('http://x'),
        );
        // The stream delivers a microtask later than the await returns.
        await Future<void>.delayed(Duration.zero);
        expect(notified, greaterThan(0));
        expect(gate.redirectFor(AppRoutes.home), isNull);
        expect(gate.redirectFor(AppRoutes.signIn), AppRoutes.home);
      },
    );
  });
}
