import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

/// A `status-update` frame in state [state].
Map<String, dynamic> status(String state) => <String, dynamic>{
  'kind': 'status-update',
  'status': <String, dynamic>{'state': state},
};

void main() {
  group('parseAgentEvent status-update', () {
    test('reads the opening working status', () {
      expect(
        parseAgentEvent(status('working')),
        equals(const AgentTurnStarted()),
      );
    });

    test('reads completed as a terminal state', () {
      expect(
        parseAgentEvent(status('completed')),
        equals(const AgentTurnEnded(AgentTurnState.completed)),
      );
    });

    test('reads input_required as a terminal state, not an error', () {
      // N-11 / ADR-D D-3. This is the common case for a widget-bearing turn;
      // treating it as a failure would show an error on every success.
      expect(
        parseAgentEvent(status('input_required')),
        equals(const AgentTurnEnded(AgentTurnState.inputRequired)),
      );
    });

    test('reads failed as a terminal state', () {
      expect(
        parseAgentEvent(status('failed')),
        equals(const AgentTurnEnded(AgentTurnState.failed)),
      );
    });

    test('ignores an unknown state and a malformed status', () {
      expect(parseAgentEvent(status('daydreaming')), isNull);
      expect(
        parseAgentEvent(<String, dynamic>{
          'kind': 'status-update',
          'status': 'working',
        }),
        isNull,
      );
    });
  });

  group('parseAgentEvent artifact-update', () {
    Map<String, dynamic> artifact(List<dynamic> parts) => <String, dynamic>{
      'kind': 'artifact-update',
      'taskId': 't-1',
      'artifact': <String, dynamic>{'artifactId': 'a-1', 'parts': parts},
    };
    const a2ui = <String, dynamic>{'mimeType': 'application/a2ui+json'};

    test('decodes every message of every A2UI part, in order', () {
      final event = parseAgentEvent(
        artifact(<dynamic>[
          <String, dynamic>{
            'kind': 'data',
            'metadata': a2ui,
            'data': <dynamic>[
              <String, dynamic>{
                'version': 'v1.0',
                'deleteSurface': <String, dynamic>{'surfaceId': 'a'},
              },
              'not a message',
            ],
          },
          <String, dynamic>{'kind': 'text', 'text': 'not A2UI'},
        ]),
      );
      final messages = (event! as AgentSurfaceMessages).messages;
      expect(messages.first, const DecodedMessage(DeleteSurface('a')));
      expect(messages.last, isA<DecodeFailure>());
    });

    test('ignores an artifact with no A2UI part, or no parts at all', () {
      expect(
        parseAgentEvent(
          artifact(<dynamic>[
            <String, dynamic>{'kind': 'text', 'text': 'x'},
          ]),
        ),
        isNull,
      );
      expect(
        parseAgentEvent(<String, dynamic>{
          'kind': 'artifact-update',
          'artifact': <String, dynamic>{'artifactId': 'a'},
        }),
        isNull,
      );
      expect(
        parseAgentEvent(<String, dynamic>{'kind': 'artifact-update'}),
        isNull,
      );
    });
  });
}
