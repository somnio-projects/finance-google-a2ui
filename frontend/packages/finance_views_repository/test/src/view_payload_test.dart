import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

import '../fixtures.dart';

void main() {
  group(ViewPayload, () {
    ViewPayload subject() => ViewPayload.fromJson(holdingsAllocationExample);

    group('fromJson', () {
      test('reads the view discriminator', () {
        expect(subject().view, equals('holdings.allocation.v1'));
        expect(subject().json, equals(holdingsAllocationExample));
      });

      test('throws when the payload is not an object', () {
        expect(
          () => ViewPayload.fromJson(const <int>[1]),
          throwsA(
            isA<PayloadContractException>().having(
              (e) => e.failure.path,
              'path',
              equals('<root>'),
            ),
          ),
        );
      });

      test('throws when the view discriminator is missing', () {
        expect(
          () => ViewPayload.fromJson(const <String, dynamic>{'title': 'x'}),
          throwsA(
            isA<PayloadContractException>().having(
              (e) => e.failure.path,
              'path',
              equals('view'),
            ),
          ),
        );
      });
    });

    group('text', () {
      test('reads a nested pre-formatted string by dotted path', () {
        expect(subject().text('total.amount.display'), equals(r'$65,038.60'));
        expect(subject().text('title'), equals('Allocation by holding'));
      });

      test('throws naming the path when it is absent', () {
        expect(
          () => subject().text('total.amount.nope'),
          throwsA(
            isA<PayloadContractException>().having(
              (e) => e.failure.message,
              'message',
              contains('total.amount.nope'),
            ),
          ),
        );
      });

      test('throws when the path stops at a non-object', () {
        expect(
          () => subject().text('title.deeper'),
          throwsA(isA<PayloadContractException>()),
        );
      });

      test('throws when the value is not a string', () {
        expect(
          () => subject().text('total'),
          throwsA(isA<PayloadContractException>()),
        );
      });
    });

    group('optionalText', () {
      test('reads a string that is present', () {
        expect(
          subject().optionalText('title'),
          equals('Allocation by holding'),
        );
      });

      test('returns null when absent or not a string', () {
        expect(subject().optionalText('subtitle'), isNull);
        expect(subject().optionalText('total'), isNull);
      });
    });

    group('rows', () {
      test('reads repeated objects in the order the backend sent them', () {
        final rows = subject().rows('categories');
        expect(
          rows.map((row) => row.text('key')),
          equals(<String>['BTC', 'ETH', 'SOL', 'LINK', 'DOGE']),
        );
      });

      test('keeps the parent view id so violations name the component', () {
        expect(
          subject().rows('categories').first.view,
          equals('holdings.allocation.v1'),
        );
      });

      test('throws when the path is not an array', () {
        expect(
          () => subject().rows('title'),
          throwsA(
            isA<PayloadContractException>().having(
              (e) => e.failure.expected,
              'expected',
              equals('an array'),
            ),
          ),
        );
      });

      test('throws when an element is not an object', () {
        final payload = ViewPayload.fromJson(const <String, dynamic>{
          'view': 'x.y.v1',
          'rows': <Object?>['not an object'],
        });
        expect(
          () => payload.rows('rows'),
          throwsA(
            isA<PayloadContractException>().having(
              (e) => e.failure.expected,
              'expected',
              equals('an array of objects'),
            ),
          ),
        );
      });
    });
  });

  group(PayloadContractException, () {
    test('describes the failure it carries', () {
      const exception = PayloadContractException(
        ContractFailure('a.b', 'a string'),
      );
      expect(exception.toString(), contains('a.b'));
      expect(exception.failure.expected, equals('a string'));
    });
  });
}
