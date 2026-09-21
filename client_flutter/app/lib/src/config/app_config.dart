/// Build-time application configuration, supplied via `--dart-define`.
///
/// [AppConfig.fromMap] is the testable core; [AppConfig.fromEnv] is a thin
/// adapter over `String.fromEnvironment`. The split matters: `fromEnvironment`
/// is const-folded at compile time, so a test that reads it inline can never
/// exercise a value other than the one the test binary was built with.
class AppConfig {
  const AppConfig({required this.backendBaseUrl});

  /// `--dart-define` key for the backend's base URL.
  static const String backendBaseUrlKey = 'BACKEND_BASE_URL';

  /// Local development default, used when [backendBaseUrlKey] is not supplied.
  ///
  /// This is the one place in the app allowed to hold a URL literal.
  static const String defaultBackendBaseUrl = 'http://localhost:10002';

  /// Base URL of the A2A backend the client talks to.
  final Uri backendBaseUrl;

  /// Builds a config from raw key/value pairs.
  ///
  /// An absent or blank [backendBaseUrlKey] falls back to
  /// [defaultBackendBaseUrl]. A value that is not an absolute http(s) URL
  /// throws an [ArgumentError] naming the key — a typo must fail loudly
  /// rather than silently degrade to localhost.
  factory AppConfig.fromMap(Map<String, String> values) {
    final String raw = (values[backendBaseUrlKey] ?? '').trim();
    final String value = raw.isEmpty ? defaultBackendBaseUrl : raw;

    final Uri? parsed = Uri.tryParse(value);
    if (parsed == null ||
        !(parsed.isScheme('http') || parsed.isScheme('https')) ||
        parsed.host.isEmpty) {
      throw ArgumentError.value(
        raw,
        backendBaseUrlKey,
        'must be an absolute http(s) URL',
      );
    }
    return AppConfig(backendBaseUrl: parsed);
  }

  /// Reads the configuration supplied to this build via `--dart-define`.
  factory AppConfig.fromEnv() => AppConfig.fromMap({
    backendBaseUrlKey: const String.fromEnvironment(backendBaseUrlKey),
  });
}
