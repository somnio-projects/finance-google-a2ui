import 'dart:async';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../client_harness.dart';

/// A client whose transport answers after [delay], bounded by [timeout].
FinanceApiClient _slow(Duration delay, {required Duration timeout}) =>
    FinanceApiClient(
      baseUrl: Uri.parse('http://localhost:8000'),
      tokenProvider: anonymousToken,
      timeout: timeout,
      httpClient: MockClient(
        (_) => Future<http.Response>.delayed(
          delay,
          () => jsonOk(<String, dynamic>{}),
        ),
      ),
    );

void main() {
  // GGU-110: a Holdings skeleton that never resolved and had nothing to say.
  // Two paths let a request hang or throw past this class; both are values.
  group('$FinanceApiClient bounds every request', () {
    test("has a limit of its own, well short of the browser's", () {
      expect(
        FinanceApiClient.defaultTimeout,
        equals(const Duration(seconds: 20)),
      );
    });

    test('reports a stalled GET as a timeout instead of waiting', () async {
      final client = _slow(
        const Duration(seconds: 5),
        timeout: const Duration(milliseconds: 20),
      );
      final result = await client.getJson('/v1/views');
      final failure = (result as Err<JsonResponse>).failure;
      expect(failure, isA<TransportFailure>());
      expect(failure.message, equals('the request timed out'));
    });

    test('reports a stalled POST the same way', () async {
      final client = _slow(
        const Duration(seconds: 5),
        timeout: const Duration(milliseconds: 20),
      );
      final result = await client.postJson('/v1/x');
      expect(result.failureOrNull?.message, equals('the request timed out'));
    });

    test('lets a request that answers in time through', () async {
      final client = _slow(Duration.zero, timeout: const Duration(seconds: 1));
      final result = await client.getJson('/v1/views');
      expect(result, isA<Ok<JsonResponse>>());
    });
  });

  group('$FinanceApiClient and a credential it cannot read', () {
    test('a throwing token provider is a failure, not an exception', () async {
      // The provider is the identity SDK refreshing over the network. Its
      // exception used to escape `getJson` untouched and leave the caller's
      // skeleton on screen for ever.
      final harness = ClientHarness(
        (_) async => jsonOk(<String, dynamic>{}),
        tokenProvider: () async => throw StateError('refresh failed'),
      );
      final result = await harness.client.getJson('/v1/views');
      final failure = (result as Err<JsonResponse>).failure;
      expect(failure, isA<TransportFailure>());
      expect(failure.code, equals('transport-unavailable'));
      expect(failure.message, equals(credentialUnavailable));
      // Nothing left the device: no request without its credential.
      expect(harness.sent, isEmpty);
    });

    test("the SDK's own words never reach the failure", () async {
      final harness = ClientHarness(
        (_) async => jsonOk(<String, dynamic>{}),
        tokenProvider: () async =>
            throw TimeoutException('firebase: token endpoint unreachable'),
      );
      final result = await harness.client.postJson('/v1/x');
      expect(result.failureOrNull?.message, isNot(contains('firebase')));
      expect(result.failureOrNull?.message, equals(credentialUnavailable));
    });

    test('an anonymous call never consults the provider', () async {
      final harness = ClientHarness(
        (_) async => jsonOk(<String, dynamic>{}),
        tokenProvider: () async => throw StateError('must not be called'),
      );
      final result = await harness.client.getJson(
        '/v1/sign-in-policy',
        authenticated: false,
      );
      expect(result, isA<Ok<JsonResponse>>());
    });
  });
}
