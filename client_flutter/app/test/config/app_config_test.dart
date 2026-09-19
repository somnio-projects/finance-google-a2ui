import 'package:finance_a2ui_client/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.fromMap', () {
    test('parses a supplied backend base URL', () {
      final config = AppConfig.fromMap({
        AppConfig.backendBaseUrlKey: 'https://api.example.com',
      });

      expect(config.backendBaseUrl, Uri.parse('https://api.example.com'));
    });

    test('falls back to the localhost default when the key is absent', () {
      final config = AppConfig.fromMap({});

      expect(
        config.backendBaseUrl,
        Uri.parse(AppConfig.defaultBackendBaseUrl),
      );
    });

    test('falls back to the localhost default when the value is blank', () {
      final config = AppConfig.fromMap({
        AppConfig.backendBaseUrlKey: '   ',
      });

      expect(
        config.backendBaseUrl,
        Uri.parse(AppConfig.defaultBackendBaseUrl),
      );
    });

    test('throws naming the key when the URL is malformed', () {
      expect(
        () => AppConfig.fromMap({
          AppConfig.backendBaseUrlKey: 'not-a-url',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.name,
            'name',
            AppConfig.backendBaseUrlKey,
          ),
        ),
      );
    });

    test('accepts an uppercase scheme', () {
      final config = AppConfig.fromMap({
        AppConfig.backendBaseUrlKey: 'HTTPS://api.example.com',
      });

      expect(config.backendBaseUrl.isScheme('https'), isTrue);
    });

    test('throws when the scheme is not http(s)', () {
      expect(
        () => AppConfig.fromMap({
          AppConfig.backendBaseUrlKey: 'ftp://example.com',
        }),
        throwsArgumentError,
      );
    });
  });
}
