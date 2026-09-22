import 'dart:async';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_app/app/app_config.dart';
import 'package:finance_app/app/finance_app.dart';
import 'package:finance_app/auth/auth_gate.dart';
import 'package:finance_app/auth/firebase_identity_provider.dart';
import 'package:finance_app/components/component_manifest.g.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/router/app_router.dart';
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
  );
}

/// Assembles the app from already-built dependencies.
///
/// [authRepository] gates the router: without one (the tests that pump one
/// route) every path is open, exactly as before sign-in existed.
Widget buildApp({
  required ViewsRepository viewsRepository,
  required AgentRepository agentRepository,
  required AuthRepository authRepository,
  ComponentRegistry? componentRegistry,
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
  );
}

/// The registry every component module registered itself into.
ComponentRegistry buildComponentRegistry() {
  final registry = ComponentRegistry();
  registerCatalogComponents(registry);
  return registry;
}
