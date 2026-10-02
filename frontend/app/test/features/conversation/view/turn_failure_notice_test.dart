import 'package:finance_app/features/conversation/view/turn_failure_notice.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('turnFailureNotice (GGU-111 AC-1)', () {
    test('a provider outage is a sentence about what to do, not a code', () {
      final notice = turnFailureNotice(
        const AgentFailed(
          code: 'dependency-unavailable',
          message: 'model provider unavailable',
        ),
      );
      expect(notice, contains('try again'));
      expect(notice, isNot(contains('provider')));
      expect(notice, isNot(contains('dependency-unavailable')));
    });

    test(
      'an unreachable agent keeps the sentence the client already wrote',
      () {
        // `transport-unavailable` messages are this client's own copy, written
        // where the failure happened; replacing them here would lose precision.
        expect(
          turnFailureNotice(
            const AgentFailed(
              code: 'transport-unavailable',
              message: 'the agent stopped answering',
            ),
          ),
          equals('the agent stopped answering'),
        );
      },
    );

    test('a turn that ended failed without a reason still has a sentence', () {
      expect(turnFailureNotice(null), contains('Try again'));
    });

    test("a code this app does not know shows the backend's own detail", () {
      // Never invented: an unfamiliar failure keeps the safe `detail` the
      // contract promises, rather than a guess in the tone of a fact.
      expect(
        turnFailureNotice(
          const AgentFailed(code: 'agent/turn-refused', message: 'Refused.'),
        ),
        equals('Refused.'),
      );
    });
  });
}
