import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:test/test.dart';

/// Feeds [body] through the decoder the way a socket would.
Future<List<Map<String, dynamic>>> decode(String body) =>
    decodeEventStream(Stream<List<int>>.value(utf8.encode(body))).toList();

void main() {
  group('decodeEventStream', () {
    test('decodes one framed event', () async {
      final events = await decode('data: {"kind":"message"}\n\n');
      expect(
        events,
        equals(<Map<String, dynamic>>[
          <String, dynamic>{'kind': 'message'},
        ]),
      );
    });

    test('decodes the transcript the backend actually emits', () async {
      // The captured order from spec client/0003 §8.3, verbatim.
      final events = await decode(
        'data: {"kind":"status-update","status":{"state":"working"}}\n\n'
        'data: {"kind":"render-intent","index":0}\n\n'
        'data: {"kind":"message","role":"agent"}\n\n'
        'data: {"kind":"status-update", '
        '"status":{"state":"input_required"}}\n\n',
      );
      expect(events, hasLength(4));
      expect(events.first['kind'], equals('status-update'));
      expect(events[1]['kind'], equals('render-intent'));
      expect(
        events.last['status'],
        equals(<String, dynamic>{'state': 'input_required'}),
      );
    });

    test('strips exactly one space after the colon', () async {
      // Not `trimLeft`: a payload that legitimately begins with a space must
      // keep the rest of it.
      final withSpace = await decode('data: {"a":" b"}\n\n');
      final withoutSpace = await decode('data:{"a":" b"}\n\n');
      expect(withSpace, equals(withoutSpace));
      expect(withSpace.single['a'], equals(' b'));
    });

    test('ignores every SSE field this surface does not use', () async {
      final events = await decode(
        ': a comment\n'
        'event: ping\n'
        'id: 7\n'
        'retry: 1000\n'
        'data: {"kind":"message"}\n\n',
      );
      expect(events.single['kind'], equals('message'));
    });

    test('yields a trailing event with no closing blank line', () async {
      // The last frame is where an `error` event lives, and it is the one a
      // client that stops early never sees.
      final events = await decode('data: {"kind":"error","code":"x"}');
      expect(events.single['code'], equals('x'));
    });

    test('drops a frame that is not a JSON object', () async {
      final events = await decode(
        'data: not json\n\n'
        'data: 5\n\n'
        '\n'
        'data: {"kind":"message"}\n\n',
      );
      expect(events.single['kind'], equals('message'));
    });

    test('yields nothing for an empty body', () async {
      expect(await decode(''), isEmpty);
    });
  });

  group('decodeJsonObject', () {
    test('returns null for an empty string', () {
      expect(decodeJsonObject(''), isNull);
    });

    test('returns null for a non-object', () {
      expect(decodeJsonObject('[1,2]'), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(decodeJsonObject('{'), isNull);
    });

    test('decodes an object', () {
      expect(decodeJsonObject('{"a":1}'), equals(<String, dynamic>{'a': 1}));
    });
  });
}
