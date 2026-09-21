import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_app/app/app_config.dart';
import 'package:finance_app/app/finance_app.dart';
import 'package:finance_app/components/component_manifest.g.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// The single composition root.
///
/// **Every** dependency in this app is constructed here and nowhere else —
/// the analogue of the backend's `bootstrap.py`, and enforced the same way:
/// `test/architecture/layering_test.dart` fails when an `http.Client`, a
/// `FinanceApiClient` or a `ViewsRepository` is constructed in any other file.
///
/// The rule buys two things. A reader learns the whole dependency graph from
/// one screen, and a test builds the same tree with fakes by calling
/// [buildApp] instead of [bootstrap].
Widget bootstrap({AppConfig? config, http.Client? httpClient}) {
  final resolved = config ?? AppConfig.fromEnvironment();
  final client = httpClient ?? http.Client();
  // Local development only. Real sign-in replaces this provider and
  // nothing else — see AppConfig.devBearerToken and SECURITY.md G-1.
  final tokenProvider = devTokenProvider(resolved);
  final apiClient = FinanceApiClient(
    baseUrl: resolved.backendBaseUrl,
    httpClient: client,
    tokenProvider: tokenProvider,
  );
  // The agent surface is JSON-RPC at the service root, not under /v1, so it
  // gets its own client over the *same* connection pool and the *same*
  // credential source — one token provider, two surfaces.
  final a2aClient = A2aClient(
    baseUrl: resolved.backendBaseUrl,
    httpClient: client,
    tokenProvider: tokenProvider,
  );
  return buildApp(
    viewsRepository: ViewsRepository(apiClient: apiClient),
    agentRepository: AgentRepository(a2aClient: a2aClient),
  );
}

/// The credential source this build uses.
///
/// Named rather than inlined so it can be tested on its own, and so the
/// one place a credential is produced is greppable. Swapping it for a real
/// identity provider is a one-line change here and nowhere else.
AuthTokenProvider devTokenProvider(AppConfig config) =>
    () async => config.devBearerToken;

/// Assembles the widget tree over already-built dependencies.
///
/// Split out of [bootstrap] so a test can supply a fake repository without
/// going anywhere near an `http.Client`.
Widget buildApp({
  required ViewsRepository viewsRepository,
  required AgentRepository agentRepository,
  ComponentRegistry? componentRegistry,
  String? initialLocation,
}) {
  return FinanceApp(
    router: buildRouter(initialLocation: initialLocation),
    viewsRepository: viewsRepository,
    agentRepository: agentRepository,
    componentRegistry: componentRegistry ?? buildComponentRegistry(),
  );
}

/// Builds the registry with every catalog component wired in.
///
/// The wiring itself lives in the generated manifest, so adding a component
/// does not edit this function either.
ComponentRegistry buildComponentRegistry() {
  final registry = ComponentRegistry();
  registerCatalogComponents(registry);
  return registry;
}
