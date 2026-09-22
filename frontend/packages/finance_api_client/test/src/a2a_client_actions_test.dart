import 'package:finance_api_client/finance_api_client.dart';
import 'package:test/test.dart';

import '../a2a_harness.dart';

void main() {
  group('$A2aClient with a surface action', () {
    test('sends one data part and no text (spec 0022 §3.2)', () async {
      final harness = A2aHarness((_) async => eventStream(capturedTurn));
      await harness.client.startTurn(
        messageId: 'm-2',
        action: 'ask.suggested.v1',
        actionArgs: const <String, String>{'suggestion': 'tax-lots'},
      );
      final params = harness.envelope['params']! as Map<String, dynamic>;
      final message = params['message']! as Map<String, dynamic>;
      final parts = message['parts']! as List<dynamic>;
      expect(parts, hasLength(1));
      expect(parts.single, <String, dynamic>{
        'kind': 'data',
        'data': <String, dynamic>{
          'action': 'ask.suggested.v1',
          'args': <String, String>{'suggestion': 'tax-lots'},
        },
      });
      expect(message['messageId'], 'm-2');
    });
  });
}
