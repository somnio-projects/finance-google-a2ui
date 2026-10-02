import 'package:finance_app/app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppConfig, () {
    const firebase = FirebaseConfig(
      apiKey: 'k',
      appId: '1:1:web:a',
      projectId: 'p',
      authDomain: 'p.firebaseapp.com',
      messagingSenderId: '1',
    );

    test('supports value equality', () {
      final a = AppConfig(
        backendBaseUrl: Uri.parse('http://localhost:8000'),
        firebase: firebase,
      );
      final b = AppConfig(
        backendBaseUrl: Uri.parse('http://localhost:8000'),
        firebase: firebase,
      );
      expect(a, equals(b));
      expect(firebase.props, hasLength(5));
    });

    test('props are correct', () {
      final url = Uri.parse('http://localhost:8000');
      expect(
        AppConfig(backendBaseUrl: url).props,
        equals(<Object?>[url, null]),
      );
    });

    group('fromEnvironment', () {
      test('defaults to the local stack with no identity provider', () {
        final config = AppConfig.fromEnvironment();
        expect(
          config.backendBaseUrl,
          equals(Uri.parse('http://localhost:8000')),
        );
        // No FIREBASE_API_KEY define in a test run: the seam is the null one.
        expect(config.firebase, isNull);
      });
    });
  });
}
