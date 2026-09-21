import 'package:finance_core/finance_core.dart';
import 'package:test/test.dart';

void main() {
  group(ProblemDetails, () {
    Map<String, dynamic> validJson() => <String, dynamic>{
      'type': 'https://errors.finance-a2ui/auth/expired-token',
      'title': 'Unauthorized',
      'status': 401,
      'detail': 'the credential has expired',
      'instance': '/v1/me',
      'request_id': '68eda88b',
    };

    test('parses every documented field', () {
      final problem = ProblemDetails.tryParse(validJson())!;
      expect(problem.type, equals(validJson()['type']));
      expect(problem.title, equals('Unauthorized'));
      expect(problem.status, equals(401));
      expect(problem.detail, equals('the credential has expired'));
      expect(problem.instance, equals('/v1/me'));
      expect(problem.requestId, equals('68eda88b'));
    });

    test('leaves the optional fields null when absent', () {
      final json = validJson()
        ..remove('instance')
        ..remove('request_id');
      final problem = ProblemDetails.tryParse(json)!;
      expect(problem.instance, isNull);
      expect(problem.requestId, isNull);
    });

    test('ignores optional fields that are not strings', () {
      final json = validJson()
        ..['instance'] = 12
        ..['request_id'] = false;
      final problem = ProblemDetails.tryParse(json)!;
      expect(problem.instance, isNull);
      expect(problem.requestId, isNull);
    });

    test('supports value equality', () {
      expect(
        ProblemDetails.tryParse(validJson()),
        equals(ProblemDetails.tryParse(validJson())),
      );
    });

    group('code', () {
      test('strips the error namespace so call sites compare a short id', () {
        expect(
          ProblemDetails.tryParse(validJson())!.code,
          equals('auth/expired-token'),
        );
      });

      test('returns the whole type when it is not in the namespace', () {
        final json = validJson()..['type'] = 'about:blank';
        expect(ProblemDetails.tryParse(json)!.code, equals('about:blank'));
      });
    });

    group('tryParse', () {
      test('returns null when the body is not a JSON object', () {
        expect(ProblemDetails.tryParse('<html>gateway</html>'), isNull);
        expect(ProblemDetails.tryParse(null), isNull);
        expect(ProblemDetails.tryParse(<int>[1]), isNull);
      });

      test('returns null when a required field is missing or mistyped', () {
        for (final key in <String>['type', 'title', 'status', 'detail']) {
          expect(
            ProblemDetails.tryParse(validJson()..remove(key)),
            isNull,
            reason: 'removing $key must not yield a problem document',
          );
        }
        expect(
          ProblemDetails.tryParse(validJson()..['status'] = '401'),
          isNull,
        );
        expect(ProblemDetails.tryParse(validJson()..['type'] = 1), isNull);
        expect(ProblemDetails.tryParse(validJson()..['title'] = 1), isNull);
        expect(ProblemDetails.tryParse(validJson()..['detail'] = 1), isNull);
      });
    });
  });
}
