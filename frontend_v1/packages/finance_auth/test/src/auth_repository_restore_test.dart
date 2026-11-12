import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../auth_harness.dart';

http.Response _problem(int status, String code, {String? retryAfter}) =>
    http.Response(
      jsonEncode(<String, dynamic>{
        'type': 'https://errors.finance-a2ui/$code',
        'title': 'Problem',
        'status': status,
        'detail': 'The registry said $status.',
      }),
      status,
      headers: <String, String>{
        'content-type': 'application/problem+json',
        'retry-after': ?retryAfter,
      },
    );

/// GGU-159 and GGU-163: what restoring a stored session can end in.
void main() {
  group('AuthRepository restore', () {
    late ScriptedIdentity identity;
    late FakeBackend backend;
    late List<AuthStatus> seen;

    AuthRepository build() {
      final repository = AuthRepository(
        identity: identity,
        access: AccessGateway(apiClient: backend.client),
      );
      repository.changes.listen((state) => seen.add(state.status));
      return repository;
    }

    setUp(() {
      identity = ScriptedIdentity(restored: 'restored-token');
      backend = FakeBackend();
      seen = <AuthStatus>[];
    });

    test(
      'is restoring, not provisioning, while the registry answers',
      () async {
        final repository = build();
        await repository.restore();
        await Future<void>.delayed(Duration.zero);
        expect(seen, <AuthStatus>[AuthStatus.restoring, AuthStatus.signedIn]);
      },
    );

    test('a 429 keeps the session, with its Retry-After', () async {
      backend.accessAnswers.add(
        _problem(429, 'rate-limited', retryAfter: '60'),
      );
      final repository = build();
      await repository.restore();
      final state = repository.state;
      expect(state.status, AuthStatus.unavailable);
      expect(state.isStarting, isTrue);
      expect(state.session?.token, 'restored-token');
      expect(state.failure?.code, 'rate-limited');
      expect(
        (state.failure! as ProblemFailure).retryAfter,
        const Duration(seconds: 60),
      );
    });

    test('a 5xx problem is unavailable too', () async {
      backend.accessAnswers.add(_problem(503, 'dependency-unavailable'));
      final repository = build();
      await repository.restore();
      expect(repository.state.status, AuthStatus.unavailable);
    });

    test('a 401 or a 403 problem ends the session', () async {
      for (final status in <int>[401, 403]) {
        backend.accessAnswers.add(_problem(status, 'auth/denied'));
        final repository = build();
        await repository.restore();
        expect(
          repository.state.status,
          AuthStatus.signedOut,
          reason: '$status',
        );
        expect(repository.state.session, isNull);
      }
    });

    test('retry asks again with the same session, and admits', () async {
      backend.accessAnswers.add(_problem(429, 'rate-limited'));
      final repository = build();
      await repository.restore();
      identity.restored = null;
      await repository.retry();
      expect(repository.state.allowsShell, isTrue);
      expect(backend.requests, hasLength(2));
      // No new link, no new provider sign-in: the same session was re-asked.
      expect(identity.calls.where((call) => call.startsWith('link')), isEmpty);
    });

    test('retry does nothing unless the registry was unavailable', () async {
      final repository = build();
      await repository.retry();
      expect(repository.state.status, AuthStatus.unknown);
      expect(backend.requests, isEmpty);
    });

    test('a bare 401 on the check ends the session and stays ended', () async {
      late final AuthRepository repository;
      final client = FinanceApiClient(
        baseUrl: Uri.parse('http://localhost:8000'),
        tokenProvider: () async => 't',
        onUnauthenticated: () => repository.handleUnauthenticated(),
        httpClient: MockClient((_) async => http.Response('', 401)),
      );
      repository = AuthRepository(
        identity: identity,
        access: AccessGateway(apiClient: client),
      );
      await repository.restore();
      expect(repository.state.status, AuthStatus.signedOut);
      expect(repository.state.isStarting, isFalse);
    });
  });
}
