import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:test/test.dart';

import '../auth_harness.dart';

void main() {
  group(SignInPolicy, () {
    test('reads the two doors the backend can name', () {
      expect(
        SignInPolicy.fromJson(<String, dynamic>{'enrolment': 'open'})
            .valueOrNull,
        SignInPolicy.open,
      );
      expect(
        SignInPolicy.fromJson(<String, dynamic>{'enrolment': 'invite-only'})
            .valueOrNull,
        SignInPolicy.inviteOnly,
      );
    });

    test('an unrecognised door is a contract failure, not a default', () {
      // The field is an enumeration precisely so a third door can be added
      // (spec backend/0043 OD-3). Guessing which of these two it resembles is
      // how the screen would make the false claim it exists to stop making.
      final result = SignInPolicy.fromJson(<String, dynamic>{
        'enrolment': 'domain-restricted',
      });
      expect(result.failureOrNull, isA<ContractFailure>());
      expect((result.failureOrNull! as ContractFailure).code, isNotEmpty);
    });

    test('a body that is not an object is a contract failure', () {
      expect(SignInPolicy.fromJson(null).failureOrNull, isA<ContractFailure>());
    });

    test('only the invite-only door offers the invite line', () {
      expect(SignInPolicy.inviteOnly.offersInvite, isTrue);
      expect(SignInPolicy.open.offersInvite, isFalse);
    });
  });

  group('$AccessGateway.signInPolicy', () {
    test('carries the backend answer through', () async {
      final backend = FakeBackend()..enrolment = SignInPolicy.openValue;
      final gateway = AccessGateway(apiClient: backend.client);
      expect((await gateway.signInPolicy()).valueOrNull, SignInPolicy.open);
    });

    test('asks for it without a credential', () async {
      // Public by contract: it is asked before anybody has a token, so
      // sending one would be the client pretending it already does.
      final backend = FakeBackend();
      await AccessGateway(apiClient: backend.client).signInPolicy();
      final request = backend.requests.single;
      expect(request.url.path, '/v1/sign-in-policy');
      expect(request.headers.containsKey('authorization'), isFalse);
    });

    test('a failed read carries the failure through', () async {
      final backend = FakeBackend()..enrolment = null;
      final gateway = AccessGateway(apiClient: backend.client);
      expect((await gateway.signInPolicy()).isOk, isFalse);
    });

    test('the repository hands the same answer on, unchanged', () async {
      // The bloc talks to the repository, never to the gateway; this is the
      // one line between them and it must not be the place a door changes.
      final backend = FakeBackend()..enrolment = SignInPolicy.openValue;
      final repository = AuthRepository(
        identity: ScriptedIdentity(),
        access: AccessGateway(apiClient: backend.client),
      );
      expect((await repository.signInPolicy()).valueOrNull, SignInPolicy.open);
    });
  });
}
