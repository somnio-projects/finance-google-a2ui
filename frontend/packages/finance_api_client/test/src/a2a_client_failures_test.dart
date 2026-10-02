import 'dart:async';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../a2a_harness.dart';

/// The failure of [harness]'s only turn.
Future<AppFailure> failureOf(A2aHarness harness) async {
  final result = await harness.start();
  return (result as Err<Stream<Map<String, dynamic>>>).failure;
}

void main() {
  // Spec client/0003 §8.5 / AC-16: the A2A root answers in three shapes and a
  // client parses all of them. N-12: a 200 never means success on its own.
  group('$A2aClient failures', () {
    test('reads a 401 as the problem document it is', () async {
      final harness = A2aHarness(
        (_) async => jsonBody(
          '{"type":"https://errors.finance-a2ui/auth/invalid-token",'
          '"title":"Unauthorized","status":401,"detail":"The token is not '
          'valid."}',
          status: 401,
        ),
      );
      final failure = await failureOf(harness);
      expect(failure, isA<ProblemFailure>());
      expect(failure.code, equals('auth/invalid-token'));
      expect(failure.message, equals('The token is not valid.'));
    });

    test('reads a JSON-RPC error at HTTP 200 as a failure', () async {
      // The shape that makes N-12 load-bearing: the status is 200 and the
      // turn never ran.
      final harness = A2aHarness(
        (_) async => jsonBody(
          '{"jsonrpc":"2.0","id":"1","error":{"code":-32601,'
          '"message":"Unknown method."}}',
        ),
      );
      final failure = await failureOf(harness);
      expect(failure, isA<TransportFailure>());
      expect(failure.message, equals('Unknown method.'));
    });

    test('falls back when a 200 body carries no usable error', () async {
      final harness = A2aHarness((_) async => jsonBody('{"jsonrpc":"2.0"}'));
      final failure = await failureOf(harness);
      expect(failure.message, equals('the agent refused the request'));
    });

    test('falls back when a 200 error carries no message', () async {
      final harness = A2aHarness(
        (_) async => jsonBody('{"error":{"code":-32601}}'),
      );
      final failure = await failureOf(harness);
      expect(failure.message, equals('the agent refused the request'));
    });

    test('reports a non-problem error body without inventing one', () async {
      // A gateway answered, not the service. Synthesising a problem document
      // the backend never sent would be worse than saying so plainly.
      final harness = A2aHarness(
        (_) async => jsonBody('<html>502</html>', status: 502),
      );
      final failure = await failureOf(harness);
      expect(failure, isA<TransportFailure>());
      expect(failure.message, equals('the agent answered 502'));
    });

    test('never lets the http library its own text reach a failure', () async {
      // On BrowserClient the exception message carries the target URL, which
      // is not ours to show a user (N-14).
      final harness = A2aHarness(
        (_) async => throw http.ClientException(
          'XMLHttpRequest error http://localhost:8000/?token=leaked',
        ),
      );
      final failure = await failureOf(harness);
      expect(failure, isA<TransportFailure>());
      expect(failure.message, equals('the agent could not be reached'));
      expect(failure.message, isNot(contains('leaked')));
    });

    test('reports a timeout as its own failure', () async {
      final harness = A2aHarness((_) async => throw TimeoutException('slow'));
      final failure = await failureOf(harness);
      expect(failure.message, equals('the agent timed out'));
    });

    test('bounds the open itself, not only a transport that says slow', () {
      // GGU-110 AC-3: with no limit of its own a connection that never
      // answered was a turn that never ended.
      final client = A2aClient(
        baseUrl: Uri.parse('http://localhost:8000'),
        tokenProvider: anonymousToken,
        timeout: const Duration(milliseconds: 20),
        httpClient: MockClient.streaming(
          (_, _) => Future<http.StreamedResponse>.delayed(
            const Duration(seconds: 5),
            () => eventStream(capturedTurn),
          ),
        ),
      );
      expect(
        client
            .startTurn(text: 'hi', messageId: 'm-1')
            .then(
              (r) => (r as Err<Stream<Map<String, dynamic>>>).failure.message,
            ),
        completion(equals('the agent timed out')),
      );
    });

    test(
      'a credential that cannot be read is a failure, not a throw',
      () async {
        final harness = A2aHarness(
          (_) async => eventStream(capturedTurn),
          tokenProvider: () async => throw StateError('refresh failed'),
        );
        final failure = await failureOf(harness);
        expect(failure, isA<TransportFailure>());
        expect(failure.message, equals(credentialUnavailable));
        expect(harness.sent, isEmpty);
      },
    );
  });
}
