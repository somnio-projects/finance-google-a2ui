import 'package:equatable/equatable.dart';

/// Firebase's **public** web config (ADR-B D-10: only public config ships
/// client-side). Absent when the build carries no `FIREBASE_API_KEY`, which is
/// the local stack: there the design's e-mail path is the backend's preview
/// sign-in (spec backend/0027 OD-3) and the Google button says it is not
/// configured, rather than pretending.
class FirebaseConfig extends Equatable {
  /// Creates the config.
  const FirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.projectId,
    required this.authDomain,
    required this.messagingSenderId,
  });

  /// The web API key — public by design, restricted by Google to this app.
  final String apiKey;

  /// `1:<project number>:web:<hash>`.
  final String appId;

  /// The Firebase project, also the token audience the backend checks.
  final String projectId;

  /// Where the sign-in popup and the e-mail link are hosted.
  final String authDomain;

  /// The project number.
  final String messagingSenderId;

  @override
  List<Object?> get props => <Object?>[
    apiKey,
    appId,
    projectId,
    authDomain,
    messagingSenderId,
  ];
}

/// Build-time configuration.
///
/// Values arrive through `--dart-define` and are read in **exactly one**
/// place — `layering_test.dart` fails any other `String.fromEnvironment`.
/// There is no credential here any more: sign-in produces the bearer at run
/// time (spec frontend/0008; `SECURITY.md` G-1 closed).
class AppConfig extends Equatable {
  /// Creates the config.
  const AppConfig({required this.backendBaseUrl, this.firebase});

  /// Reads the `--dart-define`s.
  factory AppConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: 'http://localhost:8000',
    );
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    return AppConfig(
      backendBaseUrl: Uri.parse(baseUrl),
      firebase: apiKey.isEmpty
          ? null
          : const FirebaseConfig(
              apiKey: apiKey,
              appId: String.fromEnvironment('FIREBASE_APP_ID'),
              projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
              authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
              messagingSenderId: String.fromEnvironment(
                'FIREBASE_MESSAGING_SENDER_ID',
              ),
            ),
    );
  }

  /// The API's origin; every request resolves against it.
  final Uri backendBaseUrl;

  /// The identity provider's public config, when this build has one.
  final FirebaseConfig? firebase;

  @override
  List<Object?> get props => <Object?>[backendBaseUrl, firebase];
}
