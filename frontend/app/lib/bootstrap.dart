import 'dart:async';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_app/app/app_config.dart';
import 'package:finance_app/app/finance_app.dart';
import 'package:finance_app/auth/auth_gate.dart';
import 'package:finance_app/auth/firebase_identity_provider.dart';
import 'package:finance_app/components/component_manifest.g.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
// The platform choice for dictation lives HERE, in the composition root,
// rather than in a barrel of one conditional export: such a barrel has no
// executable line, lcov writes no record for it, and the coverage gate would
// then have to excuse a file that does nothing (spec frontend/0022 OD-2).
import 'package:finance_app/speech/speech_stub.dart'
    if (dart.library.js_interop) 'package:finance_app/speech/speech_web.dart';
import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// The composition root — the only file that constructs infrastructure.
///
/// [firebaseAuth] is the initialised SDK when the build carries Firebase's
/// public config (`main.dart` initialises it); without one the identity seam
/// is the [NullIdentityProvider] and the e-mail path is the backend's preview
/// sign-in (spec backend/0027 OD-3). There is no development token any more:
/// the bearer is whatever [AuthRepository.token] answers (`SECURITY.md` G-1).
Widget bootstrap({
  AppConfig? config,
  http.Client? httpClient,
  FirebaseAuth? firebaseAuth,
}) {
  final resolved = config ?? AppConfig.fromEnvironment();
  final client = httpClient ?? http.Client();
  final identity = firebaseAuth == null
      ? const NullIdentityProvider()
      : FirebaseIdentityProvider(auth: firebaseAuth);
  late final AuthRepository auth;
  late final ViewsRepository views;
  Future<String?> token() => auth.token();
  final apiClient = FinanceApiClient(
    baseUrl: resolved.backendBaseUrl,
    httpClient: client,
    tokenProvider: token,
    onUnauthenticated: () => auth.handleUnauthenticated(),
  );
  auth = AuthRepository(
    identity: identity,
    access: AccessGateway(apiClient: apiClient),
    // A cached portfolio must not outlive the credential that read it (G-3).
    onSignedOut: () => views.clearCache(),
  );
  views = ViewsRepository(apiClient: apiClient);
  final a2aClient = A2aClient(
    baseUrl: resolved.backendBaseUrl,
    httpClient: client,
    tokenProvider: token,
  );
  unawaited(auth.restore());
  return buildApp(
    viewsRepository: views,
    agentRepository: AgentRepository(a2aClient: a2aClient),
    authRepository: auth,
    speechRecognizer: createSpeechRecognizer(),
  );
}

/// Assembles the app from already-built dependencies.
///
/// [authRepository] gates the router: without one (the tests that pump one
/// route) every path is open, exactly as before sign-in existed.
///
/// [speechRecognizer] is the dictation seam. It is a parameter rather than a
/// construction because this function is what a test calls, and a test must
/// be able to hand in a fake engine (spec frontend/0022 OD-2).
Widget buildApp({
  required ViewsRepository viewsRepository,
  required AgentRepository agentRepository,
  required AuthRepository authRepository,
  ComponentRegistry? componentRegistry,
  ThemeModeController? themeMode,
  SpeechRecognizer? speechRecognizer,
  String? initialLocation,
  bool gated = true,
}) {
  return FinanceApp(
    router: buildRouter(
      initialLocation: initialLocation,
      gate: gated ? AuthGate(authRepository) : null,
    ),
    viewsRepository: viewsRepository,
    agentRepository: agentRepository,
    authRepository: authRepository,
    componentRegistry: componentRegistry ?? buildComponentRegistry(),
    themeMode: themeMode ?? ThemeModeController(),
    // A tree pumped without one gets the honest no-op: the mic is drawn,
    // answers a tap, and says this build cannot dictate (spec 0022 AC-1).
    speechRecognizer: speechRecognizer ?? const UnsupportedSpeechRecognizer(),
  );
}

/// The registry every component module registered itself into.
ComponentRegistry buildComponentRegistry() {
  final registry = ComponentRegistry();
  registerCatalogComponents(registry);
  return registry;
}
