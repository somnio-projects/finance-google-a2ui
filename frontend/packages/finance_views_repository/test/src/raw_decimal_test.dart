import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
// Not exported from the barrel on purpose: `ViewPayload.geometry` is the only
// caller, so the seam is not public API (ADR-L D-14). A test may reach in.
import 'package:finance_views_repository/src/raw_decimal.dart';
import 'package:test/test.dart';

void main() {
  group('rawDecimal', () {
    test('reads the decimal strings the contract actually sends', () {
      // Straight from `attribution.waterfall.v1`'s catalog example: the
      // backend pads to six places, and one bucket carries twelve.
      expect(rawDecimal('start.amount.amount', '56925.00'), 56925);
      expect(rawDecimal('buckets[0].delta.amount', '10230.000000'), 10230);
      expect(rawDecimal('buckets[1].delta.amount', '-2797.500000'), -2797.5);
      expect(
        rawDecimal('end.amount.amount', '65038.600000000000'),
        closeTo(65038.6, 1e-9),
      );
    });

    test('raises a contract violation naming the path it could not read', () {
      // N-3: a malformed raw member is a backend defect to surface, not a
      // value to guess at. The path is in the message so it can be raised.
      expect(
        () => rawDecimal('buckets[0].delta.amount', 'not a number'),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure,
            'failure',
            const ContractFailure(
              'buckets[0].delta.amount',
              'a decimal string',
            ),
          ),
        ),
      );
    });
  });

  group('ViewPayload.geometry', () {
    final payload = ViewPayload.fromJson(const <String, dynamic>{
      'view': 'attribution.waterfall.v1',
      'start': <String, dynamic>{
        'amount': <String, dynamic>{
          'amount': '56925.00',
          'display': r'$56,925.00',
        },
      },
    });

    test('reads the raw member beside a display string', () {
      expect(payload.geometry('start.amount.amount'), 56925);
    });

    test('never hands back the formatted string as a number', () {
      // The display string is right beside the raw one; reading the wrong
      // path must fail loudly rather than parse `$56,925.00` into something.
      expect(
        () => payload.geometry('start.amount.display'),
        throwsA(isA<PayloadContractException>()),
      );
    });

    test('raises when the path is absent', () {
      expect(
        () => payload.geometry('end.amount.amount'),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure,
            'failure',
            const ContractFailure('end.amount.amount', 'a decimal string'),
          ),
        ),
      );
    });
  });
}
