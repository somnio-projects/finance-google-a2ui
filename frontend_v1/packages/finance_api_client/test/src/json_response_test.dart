import 'package:finance_api_client/finance_api_client.dart';
import 'package:test/test.dart';

void main() {
  group(JsonResponse, () {
    test('a 200 carries a body and is not a revalidation', () {
      const response = JsonResponse(
        statusCode: 200,
        body: <String, dynamic>{'view': 'holdings.allocation.v1'},
        etag: '"de120f2"',
      );
      expect(response.isNotModified, isFalse);
      expect(response.body, isA<Map<String, dynamic>>());
      expect(response.etag, equals('"de120f2"'));
    });

    test('a 304 is a success with no body', () {
      const response = JsonResponse(
        statusCode: 304,
        body: null,
        etag: '"de120f2"',
      );
      expect(response.isNotModified, isTrue);
      expect(response.body, isNull);
    });

    test('supports value equality', () {
      expect(
        const JsonResponse(statusCode: 200, body: 1, etag: null),
        equals(const JsonResponse(statusCode: 200, body: 1, etag: null)),
      );
    });

    test('props are correct', () {
      expect(
        const JsonResponse(statusCode: 200, body: 1, etag: 'e').props,
        equals(<Object?>[200, 1, 'e']),
      );
    });
  });
}
