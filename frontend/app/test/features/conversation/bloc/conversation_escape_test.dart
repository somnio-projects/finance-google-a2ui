import 'dart:async';

import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import 'conversation_harness.dart';

/// Builds a bloc whose turn stream RAISES instead of ending.
///
/// `AgentRepository` now converts a stream error into an `AgentFailed`, so in
/// production nothing reaches the bloc this way. This suite exists because
/// "nothing should" is what the status was trusting before, and the cost of
/// being wrong is the whole screen: an exception out of the handler leaves
/// the state at `running`, Bloc hands it to `onError`, the typing indicator
/// never stops and the composer never re-enables. The `finally` is a second
/// lock, and a lock nobody has tried is not a lock.
ConversationBloc _blocWhoseTurnThrows(Object failure) {
  final agent = MockAgentRepository();
  final reads = MockViewsRepository();
  when(
    () => agent.startTurn(
      text: any(named: 'text'),
      action: any(named: 'action'),
      messageId: any(named: 'messageId'),
      contextId: any(named: 'contextId'),
    ),
  ).thenAnswer((_) => Stream<AgentEvent>.error(failure));
  when(
    () => reads.fetchPortfolioViews(
      portfolioId: any(named: 'portfolioId'),
      views: any(named: 'views'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => Ok<RenderedViews>(renderedViews()));
  return ConversationBloc(agentRepository: agent, viewsRepository: reads);
}

/// Sends a message to a bloc whose turn raises, and returns where the
/// bloc came to rest.
///
/// Deliberately NOT `blocTest`. Written with `blocTest` and an `errors:`
/// matcher, this suite passed with the fix reverted: the handler's exception
/// ends `act` and `verify` is never reached, so the assertion that mattered
/// never ran. That is the "a green check is evidence only if it could have
/// been red" trap, caught by mutating the bloc and watching the suite stay
/// green. `runZonedGuarded` keeps the unhandled error from failing the test
/// while leaving the assertion on the main path, where it cannot be skipped.
Future<ConversationState> _restingStateAfter(Object failure) async {
  final escaped = <Object>[];
  ConversationBloc? built;
  // The bloc is CONSTRUCTED inside the zone, not merely driven inside it:
  // Bloc's event subscription runs in the zone where the bloc was created,
  // so a bloc built outside sends its unhandled error to the test
  // framework's zone instead of this handler — which is what the first
  // version of this helper did, and it failed for that reason rather than
  // for the reason it was testing.
  await runZonedGuarded(() async {
    built = _blocWhoseTurnThrows(failure)
      ..add(const ConversationMessageSent('what moved my portfolio?'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }, (error, _) => escaped.add(error));
  final bloc = built!;
  final resting = bloc.state;
  await bloc.close();
  // The failure really did escape the handler — otherwise this suite would
  // be asserting the happy path under a misleading name.
  expect(escaped, isNotEmpty);
  return resting;
}

void main() {
  group('$ConversationBloc when something escapes the turn', () {
    test('still leaves the running state', () async {
      final resting = await _restingStateAfter(Exception('dropped'));

      // Anything other than `idle` is a permanently disabled composer.
      expect(resting.status, ConversationStatus.idle);
    });

    test('keeps the user turn it had already echoed', () async {
      final resting = await _restingStateAfter(Exception('dropped'));

      expect(resting.entries, hasLength(1));
      expect(
        resting.entries.single,
        const UserSaid('what moved my portfolio?'),
      );
    });

    test('leaves the running state for a raised object that is not an '
        'Exception', () async {
      final resting = await _restingStateAfter('a string');

      expect(resting.status, ConversationStatus.idle);
    });
  });
}
