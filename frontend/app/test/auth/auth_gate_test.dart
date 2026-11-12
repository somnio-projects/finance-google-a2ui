import 'package:finance_app/auth/auth_gate.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/startup_fakes.dart';

Uri _at(String location) => Uri.parse(location);

void main() {
  group(AuthGate, () {
    test('waits on the start-up surface, remembering the location', () {
      // GGU-163 and GGU-154: an unknown session is neither signed in nor
      // out, and the tab the person loaded is carried, not dropped.
      final gate = AuthGate(fakeAuthRepository());
      addTearDown(gate.dispose);
      expect(gate.state.status, AuthStatus.unknown);
      expect(gate.redirectFor(_at(AppRoutes.home)), AppRoutes.startup);
      expect(gate.redirectFor(_at('/holdings')), '/starting?from=%2Fholdings');
      expect(gate.redirectFor(_at('/starting?from=%2Fholdings')), isNull);
      expect(
        gate.redirectFor(_at('/sign-in?from=%2Fask')),
        '/starting?from=%2Fask',
      );
    });

    test('sends a stranger to sign-in, still remembering', () async {
      final repository = fakeAuthRepository();
      final gate = AuthGate(repository);
      addTearDown(gate.dispose);
      await repository.restore();
      expect(
        gate.redirectFor(_at('/starting?from=%2Factivity')),
        '/sign-in?from=%2Factivity',
      );
      expect(gate.redirectFor(_at(AppRoutes.home)), AppRoutes.signIn);
      expect(gate.redirectFor(_at('/sign-in?from=%2Factivity')), isNull);
    });

    test('lets a restored person through, to where they were', () async {
      final repository = startupRepository();
      final gate = AuthGate(repository);
      addTearDown(gate.dispose);
      var notified = 0;
      gate.addListener(() => notified++);
      await repository.restore();
      await Future<void>.delayed(Duration.zero);
      expect(notified, greaterThan(0));
      expect(gate.redirectFor(_at('/activity')), isNull);
      expect(gate.redirectFor(_at('/starting?from=%2Factivity')), '/activity');
      // AC: the magic link's route survives the sign-in screen too.
      expect(gate.redirectFor(_at('/sign-in?from=%2Fholdings')), '/holdings');
      expect(gate.redirectFor(_at(AppRoutes.signIn)), AppRoutes.home);
    });

    test('keeps an unreachable registry on the start-up surface', () async {
      // GGU-159: a 429 is not a sign-out.
      final repository = startupRepository(answers: <Object>[rateLimited()]);
      final gate = AuthGate(repository);
      addTearDown(gate.dispose);
      await repository.restore();
      expect(repository.state.status, AuthStatus.unavailable);
      expect(gate.redirectFor(_at('/starting?from=%2Fask')), isNull);
      expect(gate.redirectFor(_at('/ask')), '/starting?from=%2Fask');
    });
  });

  group('rememberedRoute', () {
    test('keeps a trailing slash on a route that is not a gateway', () {
      expect(
        rememberedRoute(_at('/starting?from=%2Fholdings%2F')),
        '/holdings/',
      );
    });

    test('honours an in-app path with its query', () {
      expect(
        rememberedRoute(_at('/starting?from=%2Fask%3Fask%3Dhi')),
        '/ask?ask=hi',
      );
    });

    test('falls back to Home for anything that could leave or loop', () {
      for (final from in <String?>[
        null,
        'https://evil.test/',
        '//evil.test/',
        '/starting',
        '/sign-in?from=%2Fask',
        '/starting#x',
        '/starting/',
        '/sign-in/',
        '/sign-in//?from=%2Fask',
      ]) {
        final uri = Uri(
          path: AppRoutes.startup,
          queryParameters: <String, String>{AppRoutes.fromParameter: ?from},
        );
        expect(rememberedRoute(uri), AppRoutes.home, reason: from);
      }
    });
  });
}
