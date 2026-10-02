import 'package:finance_api_client/finance_api_client.dart';
import 'package:test/test.dart';

import '../a2a_harness.dart';

void main() {
  group('$A2aClient with an A2UI DataPart', () {
    test('sends the part verbatim and no text (ADR-M D-6)', () async {
      final harness = A2aHarness((_) async => eventStream(capturedTurn));
      const part = <String, dynamic>{
        'kind': 'data',
        'metadata': <String, dynamic>{'mimeType': 'application/a2ui+json'},
        'data': <dynamic>[],
      };
      await harness.client.startTurn(messageId: 'm-2', dataPart: part);
      final params = harness.envelope['params']! as Map<String, dynamic>;
      final message = params['message']! as Map<String, dynamic>;
      final parts = message['parts']! as List<dynamic>;
      expect(parts, hasLength(1));
      expect(parts.single, part);
      expect(message['messageId'], 'm-2');
    });
  });
}
