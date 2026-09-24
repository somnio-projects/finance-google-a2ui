import 'package:finance_api_client/finance_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('anonymousToken', () {
    test('reports no credential', () async {
      expect(await anonymousToken(), isNull);
    });

    test('satisfies $AuthTokenProvider', () {
      const provider = anonymousToken;
      expect(provider, isA<AuthTokenProvider>());
    });
  });
}
