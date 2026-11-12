// Non-const instances on purpose: equality must hold between two distinct
// objects, which `const` would canonicalise into one.
// ignore_for_file: prefer_const_constructors
import 'package:finance_app/features/startup/bloc/startup_bloc.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartupEvent', () {
    group(StartupAuthChanged, () {
      test('supports value equality and carries the state', () {
        const auth = AuthState(status: AuthStatus.restoring);
        expect(StartupAuthChanged(auth), equals(StartupAuthChanged(auth)));
        expect(StartupAuthChanged(auth).props, equals(<Object?>[auth]));
      });
    });

    group(StartupRetryRequested, () {
      test('supports value equality and has no props', () {
        expect(StartupRetryRequested(), equals(StartupRetryRequested()));
        expect(StartupRetryRequested().props, isEmpty);
      });
    });
  });

  group(StartupState, () {
    test('defaults to the neutral wait', () {
      expect(StartupState().props, equals(<Object?>[null, false]));
    });
  });
}
