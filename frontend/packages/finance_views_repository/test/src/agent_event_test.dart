import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

void main() {
  // These assert `props` **directly** rather than through `equals`, and that
  // is the point. Every event here is `const`, so Dart canonicalises two
  // identical literals to one instance and `Equatable.==` returns on its
  // `identical` short-circuit — the comparison passes without ever reading
  // `props`. A value type whose equality is never actually evaluated is the
  // kind of thing a green suite hides; naming the fields is what evaluates it.
  group('AgentEvent equality', () {
    test('a started turn carries no state of its own', () {
      expect(const AgentTurnStarted().props, isEmpty);
    });

    test('a terminal event is equal by its state', () {
      expect(
        const AgentTurnEnded(AgentTurnState.inputRequired).props,
        equals(<Object?>[AgentTurnState.inputRequired]),
      );
      expect(
        const AgentTurnEnded(AgentTurnState.failed),
        isNot(equals(const AgentTurnEnded(AgentTurnState.completed))),
      );
    });

    test('a surface is equal by index, view and options', () {
      expect(
        const AgentSurfaceReady(
          index: 2,
          view: 'payoff.curve.v1',
          options: <String, String>{'term': '30d'},
        ).props,
        equals(<Object?>[
          2,
          'payoff.curve.v1',
          <String, String>{'term': '30d'},
        ]),
      );
    });

    test('an answer is equal by its text and its views', () {
      expect(
        const AgentAnswered(text: 'up', views: <String>['a.b.v1']).props,
        equals(<Object?>[
          'up',
          <String>['a.b.v1'],
          <Suggestion>[],
        ]),
      );
    });

    test('a failure is equal by code and message', () {
      expect(
        const AgentFailed(code: 'x', message: 'y').props,
        equals(<Object?>['x', 'y']),
      );
    });

    test('a suggestion is equal by its key and its label', () {
      expect(
        const Suggestion(key: 'tax-lots', label: 'Tax lots'),
        const Suggestion(key: 'tax-lots', label: 'Tax lots'),
      );
      expect(
        const Suggestion(key: 'tax-lots', label: 'Tax lots').props,
        <Object?>['tax-lots', 'Tax lots'],
      );
    });
  });
}
