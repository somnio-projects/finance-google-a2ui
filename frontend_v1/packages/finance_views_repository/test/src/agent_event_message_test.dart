import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

void main() {
  group('parseAgentEvent message', () {
    test('reads the answer text', () {
      final event = parseAgentEvent(<String, dynamic>{
        'kind': 'message',
        'role': 'agent',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'text', 'text': 'BTC led the move.'},
        ],
      });
      expect(event, equals(const AgentAnswered(text: 'BTC led the move.')));
    });

    test('reads the recommended chips, and drops a half-formed one', () {
      final event = parseAgentEvent(<String, dynamic>{
        'kind': 'message',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'text', 'text': 'up'},
        ],
        'suggestions': <dynamic>[
          <String, dynamic>{'key': 'tax-lots', 'label': 'Tax lots'},
          <String, dynamic>{'key': 'allocation'},
          'not a chip',
        ],
      });
      expect((event! as AgentAnswered).suggestions, const <Suggestion>[
        Suggestion(key: 'tax-lots', label: 'Tax lots'),
      ]);
    });

    test('joins several text parts in order, verbatim', () {
      final event = parseAgentEvent(<String, dynamic>{
        'kind': 'message',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'text', 'text': 'up '},
          <String, dynamic>{'kind': 'data', 'payload': 1},
          <String, dynamic>{'kind': 'text', 'text': 'on the month'},
        ],
      });
      expect((event! as AgentAnswered).text, equals('up on the month'));
    });

    test('reads a turn that recommended no chip', () {
      // The null-model path: an answer and nothing else.
      final event = parseAgentEvent(<String, dynamic>{
        'kind': 'message',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'text', 'text': 'No provider.'},
        ],
      });
      expect((event! as AgentAnswered).suggestions, isEmpty);
    });

    test('ignores a message with no parts list', () {
      expect(parseAgentEvent(<String, dynamic>{'kind': 'message'}), isNull);
    });
  });

  group('parseAgentEvent error', () {
    test('reads the safe code and message', () {
      // This frame arrives AFTER the terminal status (spec §8.5), which is
      // why the stream is read to its end.
      expect(
        parseAgentEvent(<String, dynamic>{
          'kind': 'error',
          'code': 'dependency-unavailable',
          'message': 'model provider unavailable',
        }),
        equals(
          const AgentFailed(
            code: 'dependency-unavailable',
            message: 'model provider unavailable',
          ),
        ),
      );
    });

    test('ignores an error missing its code or message', () {
      expect(
        parseAgentEvent(<String, dynamic>{'kind': 'error', 'code': 'x'}),
        isNull,
      );
    });
  });

  group('parseAgentEvent unknown kinds', () {
    test('ignores a kind this client does not model', () {
      // The surface adds event kinds additively, so an unrecognised one must
      // not break a turn.
      expect(
        parseAgentEvent(<String, dynamic>{'kind': 'artifact-update'}),
        isNull,
      );
      expect(parseAgentEvent(<String, dynamic>{}), isNull);
    });
  });
}
