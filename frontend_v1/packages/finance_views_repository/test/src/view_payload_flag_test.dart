import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:test/test.dart';

void main() {
  group('ViewPayload.flag', () {
    ViewPayload flagged() => ViewPayload.fromJson(const <String, dynamic>{
      'view': 'holdings.positions.v1',
      'is_cash': true,
      'detail': 'Settlement fund',
    });

    test('reads a boolean the client only branches on', () {
      expect(flagged().flag('is_cash'), isTrue);
    });

    test('throws naming the path when absent or not a boolean', () {
      expect(
        () => flagged().flag('detail'),
        throwsA(
          isA<PayloadContractException>().having(
            (e) => e.failure.path,
            'path',
            'detail',
          ),
        ),
      );
      expect(
        () => flagged().flag('missing'),
        throwsA(isA<PayloadContractException>()),
      );
    });
  });
}
