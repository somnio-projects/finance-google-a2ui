import 'dart:async';
import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../client_harness.dart';

http.Response _problem(int status, String code) => http.Response(
  jsonEncode(<String, dynamic>{
    'type': 'https://errors.finance-a2ui/$code',
    'title': 'x',
    'status': status,
    'detail': 'd',
    'instance': '/v1/x',
    'request_id': 'r',
  }),
  status,
  headers: <String, String>{'content-type': 'application/problem+json'},
);

void main() {
  group('$FinanceApiClient postJson', () {
    test('posts the body as JSON with the bearer, and decodes', () async {
      final harness = ClientHarness(
        (_) async => jsonOk(<String, dynamic>{'ok': true}),
        tokenProvider: () async => 't0k3n',
      );
      final result = await harness.client.postJson(
        '/v1/things',
        body: <String, String>{'email': 'a@b.test'},
      );
      expect(result.valueOrNull?.body, equals(<String, dynamic>{'ok': true}));
      expect(harness.only.method, equals('POST'));
      expect(harness.only.headers['content-type'], equals('application/json'));
      expect(harness.only.headers['authorization'], equals('Bearer t0k3n'));
      expect(harness.only.body, equals('{"email":"a@b.test"}'));
    });

    test(
      'an unauthenticated post carries no bearer and no body when none',
      () async {
        var signedOut = 0;
        final harness = ClientHarness(
          (_) async => _problem(401, 'auth/missing-token'),
          tokenProvider: () async => 't0k3n',
          onUnauthenticated: () => signedOut++,
        );
        final result = await harness.client.postJson(
          '/v1/open',
          authenticated: false,
        );
        expect(harness.only.headers.containsKey('authorization'), isFalse);
        expect(harness.only.body, isEmpty);
        // A 401 on a route that never had a token is an answer, not a sign-out.
        expect(result.failureOrNull, isA<ProblemFailure>());
        expect(signedOut, equals(0));
      },
    );

    test(
      'a 401 on an authenticated call tells the session it is over',
      () async {
        var signedOut = 0;
        final harness = ClientHarness(
          (_) async => _problem(401, 'auth/expired-token'),
          tokenProvider: () async => 'stale',
          onUnauthenticated: () => signedOut++,
        );
        await harness.client.getJson('/v1/me');
        await harness.client.postJson('/v1/things');
        expect(signedOut, equals(2));
      },
    );

    test('a 401 with nobody listening is still just the failure', () async {
      final harness = ClientHarness(
        (_) async => _problem(401, 'auth/expired-token'),
      );
      final result = await harness.client.getJson('/v1/me');
      expect(result.failureOrNull, isA<ProblemFailure>());
    });

    test('a 202 with no body is a success with a null body', () async {
      final harness = ClientHarness((_) async => http.Response('', 202));
      final result = await harness.client.postJson(
        '/v1/access-requests',
        authenticated: false,
      );
      expect(result.valueOrNull?.statusCode, equals(202));
      expect(result.valueOrNull?.body, isNull);
    });

    test('transport failures are typed like the read path', () async {
      final refused = ClientHarness(
        (_) async => throw http.ClientException('down'),
      );
      expect(
        (await refused.client.postJson('/v1/x')).failureOrNull,
        isA<TransportFailure>(),
      );
      final slow = ClientHarness((_) async => throw TimeoutException('slow'));
      expect(
        (await slow.client.postJson('/v1/x')).failureOrNull,
        isA<TransportFailure>(),
      );
    });
  });
}
