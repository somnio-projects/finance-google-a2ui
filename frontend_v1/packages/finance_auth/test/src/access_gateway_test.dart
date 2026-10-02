import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:test/test.dart';

import '../auth_harness.dart';

void main() {
  group(AccessGateway, () {
    test('a preview answer without a token is a contract failure', () async {
      final backend = FakeBackend(previewToken: '');
      final gateway = AccessGateway(apiClient: backend.client);
      final result = await gateway.previewSignIn('demo@somnio.dev');
      expect(result.failureOrNull, isA<ContractFailure>());
    });

    test('a failed access call carries the failure through', () async {
      final backend = FakeBackend()..accessStatus = 500;
      final gateway = AccessGateway(apiClient: backend.client);
      expect((await gateway.access()).isOk, isFalse);
    });

    test('a failed request-access call carries the failure through', () async {
      final backend = FakeBackend()..requestStatus = 503;
      final gateway = AccessGateway(apiClient: backend.client);
      expect((await gateway.requestAccess('a@b.test')).isOk, isFalse);
    });
  });
}
