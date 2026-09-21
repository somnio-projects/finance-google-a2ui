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

  group('parseAgentEvent render-intent', () {
    test('reads the view and its options', () {
      final event = parseAgentEvent(<String, dynamic>{
        'kind': 'render-intent',
        'index': 0,
        'renderIntent': <String, dynamic>{
          'view': 'holdings.allocation.v1',
          'options': <String, dynamic>{'top_n': 5},
        },
      });
      expect(
        event,
        equals(
          const AgentSurfaceReady(
            index: 0,
            view: 'holdings.allocation.v1',
            options: <String, String>{'top_n': '5'},
          ),
        ),
      );
    });

    test('defaults to no options when the intent carries none', () {
      final event = parseAgentEvent(<String, dynamic>{
        'kind': 'render-intent',
        'index': 1,
        'renderIntent': <String, dynamic>{'view': 'payoff.curve.v1'},
      });
      expect((event! as AgentSurfaceReady).options, isEmpty);
    });

    test('ignores an intent with no view, no index or no object', () {
      expect(
        parseAgentEvent(<String, dynamic>{
          'kind': 'render-intent',
          'index': 0,
          'renderIntent': <String, dynamic>{'options': <String, dynamic>{}},
        }),
        isNull,
      );
      expect(
        parseAgentEvent(<String, dynamic>{
          'kind': 'render-intent',
          'renderIntent': <String, dynamic>{'view': 'a.b.v1'},
        }),
        isNull,
      );
    });
  });

  group('readOptions', () {
    test('keeps scalars and drops what has no query encoding', () {
      // N-7: the options schema is the server's. A nested value has no
      // encoding this client is allowed to invent, so it is dropped rather
      // than guessed — a guess would be a 422 for the whole request.
      expect(
        readOptions(<String, dynamic>{
          'top_n': 5,
          'sort': 'weight',
          'raw': true,
          'nested': <String, dynamic>{'a': 1},
          'list': <int>[1, 2],
        }),
        equals(<String, String>{
          'top_n': '5',
          'sort': 'weight',
          'raw': 'true',
        }),
      );
    });

    test('returns nothing when options are absent or not an object', () {
      expect(readOptions(null), isEmpty);
      expect(readOptions('top_n=5'), isEmpty);
    });
  });
}
