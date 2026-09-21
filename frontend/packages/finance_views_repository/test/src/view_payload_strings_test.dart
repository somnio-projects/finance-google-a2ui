import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

/// `ViewPayload.strings` — the accessor the order ticket's declared bounds
/// arrive through (`inputs[].choices`).
///
/// It is deliberately narrow: a list of the strings the backend wrote, in
/// arrival order, with a loud failure on anything else. A bound that silently
/// decoded to an empty list would be a control offering nothing, which looks
/// like a design choice rather than a broken contract.
void main() {
  ViewPayload payloadWith(Object? choices) => ViewPayload.fromJson(
    <String, dynamic>{'view': 'order.ticket.v1', 'choices': choices},
  );

  group('ViewPayload.strings', () {
    test('reads a list of strings in the order the backend sent it', () {
      expect(
        payloadWith(<String>['buy', 'sell']).strings('choices'),
        equals(<String>['buy', 'sell']),
      );
    });

    test('reads an empty list as an empty list', () {
      // A `text` control declares no choices, and that is not a violation.
      expect(payloadWith(<String>[]).strings('choices'), isEmpty);
    });

    test('raises when the path is absent', () {
      expect(
        () => payloadWith(<String>[]).strings('missing'),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.message,
            'message',
            contains('missing'),
          ),
        ),
      );
    });

    test('raises when the path holds something other than an array', () {
      expect(
        () => payloadWith('buy').strings('choices'),
        throwsA(isA<PayloadContractException>()),
      );
    });

    test('raises when an element is not a string', () {
      // A number in a bound is the contract broken, not a value to coerce —
      // coercing it here would be the first step of N-1.
      expect(
        () => payloadWith(<dynamic>['buy', 2]).strings('choices'),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.message,
            'message',
            contains('an array of strings'),
          ),
        ),
      );
    });
  });
}
