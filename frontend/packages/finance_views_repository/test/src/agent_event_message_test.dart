import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

void main() {
  group('parseAgentEvent message', () {
    test('reads the answer text and every surface of the turn', () {
      final event = parseAgentEvent(<String, dynamic>{
        'kind': 'message',
        'role': 'agent',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'text', 'text': 'NVDA led the move.'},
        ],
        'renderIntents': <Map<String, dynamic>>[
          <String, dynamic>{'view': 'attribution.waterfall.v1'},
          <String, dynamic>{'view': 'holdings.allocation.v1'},
        ],
      });
      expect(
        event,
        equals(
          const AgentAnswered(
            text: 'NVDA led the move.',
            views: <String>[
              'attribution.waterfall.v1',
              'holdings.allocation.v1',
            ],
          ),
        ),
      );
    });

    test('reads the recommended chips, and drops a half-formed one', () {
      final event = parseAgentEvent(<String, dynamic>{
        'kind': 'message',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'text', 'text': 'up'},
        ],
        'renderIntents': <Map<String, dynamic>>[],
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

    test('reads a turn that produced no surface', () {
      // The null-model path: renderIntents is [] and the turn completes.
      final event = parseAgentEvent(<String, dynamic>{
        'kind': 'message',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'text', 'text': 'No provider.'},
        ],
        'renderIntents': <Map<String, dynamic>>[],
      });
      expect((event! as AgentAnswered).views, isEmpty);
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
