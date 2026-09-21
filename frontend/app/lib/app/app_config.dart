import 'package:equatable/equatable.dart';

/// Everything the app reads from its build environment.
///
/// Values arrive through `--dart-define` and are read in **exactly one
/// place**, here, so no widget, bloc or repository ever reaches for an
/// ambient value. That is the Flutter counterpart of the backend rule "config
/// only through `Settings`, never `os.environ` in application code".
class AppConfig extends Equatable {
  /// Creates a configuration explicitly, as tests do.
  const AppConfig({required this.backendBaseUrl, required this.devBearerToken});

  /// Reads the configuration from the compile-time environment.
  factory AppConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: 'http://localhost:8000',
    );
    const token = String.fromEnvironment('BACKEND_DEV_TOKEN');
    return AppConfig(
      backendBaseUrl: Uri.parse(baseUrl),
      devBearerToken: token.isEmpty ? null : token,
    );
  }

  /// Where the finance backend lives, e.g. `http://localhost:8000`.
  final Uri backendBaseUrl;

  /// A local-development bearer token, or `null` when none was supplied.
  ///
  /// **This is a development affordance and a known gap** (`frontend/
  /// SECURITY.md` G-1). A `--dart-define` is compiled into the bundle, so the
  /// value is readable by anyone who can read the build output: only a token
  /// minted by `cd backend && make token` for a local stack may go here, never
  /// a credential for a deployed environment. Real sign-in replaces it.
  final String? devBearerToken;

  @override
  List<Object?> get props => <Object?>[backendBaseUrl, devBearerToken];
}
