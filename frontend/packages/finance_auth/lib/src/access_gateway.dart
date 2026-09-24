import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_auth/src/access_decision.dart';
import 'package:finance_auth/src/auth_session.dart';
import 'package:finance_auth/src/sign_in_policy.dart';
import 'package:finance_core/finance_core.dart';

/// The provisioning routes of specs backend/0027 and 0043, as calls.
class AccessGateway {
  /// Creates the gateway over the one HTTP client.
  const AccessGateway({required FinanceApiClient apiClient})
    : _apiClient = apiClient;

  final FinanceApiClient _apiClient;

  /// `GET /v1/me/access` for the current token.
  Future<Result<AccessDecision>> access() async =>
      switch (await _apiClient.getJson('/v1/me/access')) {
        Err<JsonResponse>(:final failure) => Err<AccessDecision>(failure),
        Ok<JsonResponse>(:final value) => AccessDecision.fromJson(value.body),
      };

  /// `GET /v1/sign-in-policy` — which door this deployment has.
  ///
  /// Unauthenticated: it is asked before anybody has a token, which is the
  /// whole point of it (spec backend/0043 OD-2).
  Future<Result<SignInPolicy>> signInPolicy() async => switch (await _apiClient
      .getJson('/v1/sign-in-policy', authenticated: false)) {
    Err<JsonResponse>(:final failure) => Err<SignInPolicy>(failure),
    Ok<JsonResponse>(:final value) => SignInPolicy.fromJson(value.body),
  };

  /// `POST /v1/preview-sign-ins` — the local stack's e-mail sign-in.
  Future<Result<AuthSession>> previewSignIn(String email) async =>
      switch (await _apiClient.postJson(
        '/v1/preview-sign-ins',
        body: <String, String>{'email': email},
        authenticated: false,
      )) {
        Err<JsonResponse>(:final failure) => Err<AuthSession>(failure),
        Ok<JsonResponse>(:final value) => _session(value.body, email),
      };

  /// `POST /v1/access-requests` — the *Request access* link.
  Future<Result<void>> requestAccess(String email) async =>
      switch (await _apiClient.postJson(
        '/v1/access-requests',
        body: <String, String>{'email': email},
        authenticated: false,
      )) {
        Err<JsonResponse>(:final failure) => Err<void>(failure),
        Ok<JsonResponse>() => const Ok<void>(null),
      };

  Result<AuthSession> _session(Object? body, String email) {
    final token = body is Map<String, dynamic> ? body['access_token'] : null;
    if (token is! String || token.isEmpty) {
      return const Err<AuthSession>(
        ContractFailure('access_token', 'a non-empty string'),
      );
    }
    return Ok<AuthSession>(
      AuthSession(token: token, provider: 'preview', email: email),
    );
  }
}
