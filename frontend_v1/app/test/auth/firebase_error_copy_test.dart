import 'package:finance_app/auth/firebase_error_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firebaseErrorCopy (GGU-155)', () {
    test('maps known codes, with or without the auth/ prefix', () {
      expect(
        firebaseErrorCopy('invalid-email', null),
        'Enter a valid email address.',
      );
      expect(
        firebaseErrorCopy('auth/too-many-requests', 'x'),
        contains('Too many attempts'),
      );
    });

    test('passes an SDK sentence through', () {
      expect(
        firebaseErrorCopy('expired', 'The link expired.'),
        'The link expired.',
      );
    });

    test('never shows a bare code', () {
      for (final message in <String?>[
        null,
        '',
        'INVALID_EMAIL',
        'Firebase: Error (auth/whatever).',
        '[firebase_auth/x] y',
      ]) {
        expect(firebaseErrorCopy('network', message), firebaseFallbackCopy);
      }
    });
  });
}
