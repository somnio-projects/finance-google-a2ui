import 'package:finance_app/app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppConfig, () {
    test('supports value equality', () {
      final a = AppConfig(
        backendBaseUrl: Uri.parse('http://localhost:8000'),
        devBearerToken: 'x',
      );
      final b = AppConfig(
        backendBaseUrl: Uri.parse('http://localhost:8000'),
        devBearerToken: 'x',
      );
      expect(a, equals(b));
    });

    test('props are correct', () {
      final url = Uri.parse('http://localhost:8000');
      expect(
        AppConfig(backendBaseUrl: url, devBearerToken: null).props,
        equals(<Object?>[url, null]),
      );
    });

    group('fromEnvironment', () {
      test('defaults to the local stack when nothing is defined', () {
        // The test binary carries no --dart-define, so this exercises the
        // default branch; the defined branch is exercised by a build that
        // passes one, and by the explicit constructor above.
        final config = AppConfig.fromEnvironment();
        expect(
          config.backendBaseUrl,
          equals(Uri.parse('http://localhost:8000')),
        );
      });

      test('reports no credential when the define is empty', () {
        expect(AppConfig.fromEnvironment().devBearerToken, isNull);
      });
    });
  });
}
