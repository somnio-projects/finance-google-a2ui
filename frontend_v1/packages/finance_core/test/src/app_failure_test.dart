import 'package:finance_core/finance_core.dart';
import 'package:test/test.dart';

void main() {
  group(AppFailure, () {
    const problem = ProblemDetails(
      type: 'https://errors.finance-a2ui/portfolio/unknown-view',
      title: 'Not Found',
      status: 404,
      detail: "view 'nope.thing.v1' is not registered",
    );

    group(TransportFailure, () {
      test('reports a stable code and the message it was given', () {
        const failure = TransportFailure('the request timed out');
        expect(failure.code, equals('transport-unavailable'));
        expect(failure.message, equals('the request timed out'));
      });

      test('supports value equality', () {
        expect(
          const TransportFailure('offline'),
          equals(const TransportFailure('offline')),
        );
        expect(
          const TransportFailure('offline'),
          isNot(equals(const TransportFailure('timeout'))),
        );
      });
    });

    group(ProblemFailure, () {
      test('takes its code and message from the problem document', () {
        const failure = ProblemFailure(problem);
        expect(failure.code, equals('portfolio/unknown-view'));
        expect(failure.message, equals(problem.detail));
        expect(failure.problem, equals(problem));
      });

      test('props are the problem itself', () {
        expect(const ProblemFailure(problem).props, equals(<Object?>[problem]));
      });
    });

    group(ContractFailure, () {
      const failure = ContractFailure('total.amount.display', 'a string');

      test('names the path and what was expected there', () {
        expect(failure.code, equals('contract-violation'));
        expect(
          failure.message,
          equals('payload is missing a string at "total.amount.display"'),
        );
      });

      test('props are the path and the expectation', () {
        expect(
          failure.props,
          equals(<Object?>['total.amount.display', 'a string']),
        );
      });
    });

    test('a switch over the sealed hierarchy is exhaustive', () {
      String describe(AppFailure failure) => switch (failure) {
        TransportFailure() => 'transport',
        ProblemFailure() => 'problem',
        ContractFailure() => 'contract',
      };
      expect(describe(const TransportFailure('x')), equals('transport'));
      expect(describe(const ProblemFailure(problem)), equals('problem'));
      expect(describe(const ContractFailure('a', 'b')), equals('contract'));
    });
  });
}
