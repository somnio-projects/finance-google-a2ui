import 'package:finance_core/finance_core.dart';
import 'package:test/test.dart';

void main() {
  group(Result, () {
    const failure = TransportFailure('offline');

    test('$Ok reports success and carries its value', () {
      const result = Ok<int>(7);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, equals(7));
      expect(result.failureOrNull, isNull);
    });

    test('$Err reports failure and carries it', () {
      const result = Err<int>(failure);
      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, equals(failure));
    });

    test('supports value equality', () {
      expect(const Ok<int>(7), equals(const Ok<int>(7)));
      expect(const Err<int>(failure), equals(const Err<int>(failure)));
      expect(const Ok<int>(7), isNot(equals(const Ok<int>(8))));
    });

    test('props are correct', () {
      expect(const Ok<int>(7).props, equals(<Object?>[7]));
      expect(const Err<int>(failure).props, equals(<Object?>[failure]));
    });

    group('fold', () {
      test('given an $Ok calls onOk with the value', () {
        expect(
          const Ok<int>(7).fold(onOk: (v) => 'ok $v', onErr: (f) => f.code),
          equals('ok 7'),
        );
      });

      test('given an $Err calls onErr with the failure', () {
        expect(
          const Err<int>(failure)
              .fold(onOk: (v) => 'ok $v', onErr: (f) => f.code),
          equals('transport-unavailable'),
        );
      });
    });
  });
}
