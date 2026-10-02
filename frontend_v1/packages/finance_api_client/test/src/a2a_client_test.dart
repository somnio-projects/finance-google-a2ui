import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:test/test.dart';

import '../a2a_harness.dart';

void main() {
  group('$A2aClient startTurn', () {
    test('posts message/stream to the service root', () async {
      final harness = A2aHarness((_) async => eventStream(capturedTurn));
      await harness.start();
      expect(harness.sent.single.url.path, equals('/'));
      expect(harness.sent.single.method, equals('POST'));
      expect(harness.envelope['method'], equals('message/stream'));
      expect(harness.envelope['jsonrpc'], equals('2.0'));
    });

    test('carries the bearer token and the A2UI extension', () async {
      // Spec client/0003 AC-1: both headers, on POST /.
      final harness = A2aHarness(
        (_) async => eventStream(capturedTurn),
        tokenProvider: () async => 'token-abc',
      );
      await harness.start();
      final headers = harness.sent.single.headers;
      expect(headers['authorization'], equals('Bearer token-abc'));
      expect(headers['x-a2a-extensions'], equals(A2aClient.a2uiExtension));
      expect(headers['accept'], equals('text/event-stream'));
    });

    test('keeps the credential out of the URL', () async {
      // N-14: the token lives in a header and nowhere else.
      final harness = A2aHarness(
        (_) async => eventStream(capturedTurn),
        tokenProvider: () async => 'token-abc',
      );
      await harness.start();
      expect(harness.sent.single.url.toString(), isNot(contains('token-abc')));
    });

    test('sends no authorization header when anonymous', () async {
      final harness = A2aHarness((_) async => eventStream(capturedTurn));
      await harness.start();
      expect(harness.sent.single.headers.containsKey('authorization'), isFalse);
    });

    test('omits contextId when none is supplied', () async {
      final harness = A2aHarness((_) async => eventStream(capturedTurn));
      await harness.start();
      final message = harness.envelope['params']! as Map<String, dynamic>;
      final body = message['message']! as Map<String, dynamic>;
      expect(body.containsKey('contextId'), isFalse);
      expect(body['role'], equals('user'));
      expect(body['parts'], hasLength(1));
    });

    test('echoes contextId when one is supplied', () async {
      final harness = A2aHarness((_) async => eventStream(capturedTurn));
      await harness.start(contextId: 'c2f1b8a4');
      final params = harness.envelope['params']! as Map<String, dynamic>;
      final body = params['message']! as Map<String, dynamic>;
      expect(body['contextId'], equals('c2f1b8a4'));
    });

    test('yields every frame of the captured transcript, in order', () async {
      final harness = A2aHarness((_) async => eventStream(capturedTurn));
      final result = await harness.start();
      final frames = await (result as Ok<Stream<Map<String, dynamic>>>).value
          .toList();
      expect(
        frames.map((frame) => frame['kind']),
        equals(<String>[
          'status-update',
          'render-intent',
          'message',
          'status-update',
        ]),
      );
    });
  });
}
