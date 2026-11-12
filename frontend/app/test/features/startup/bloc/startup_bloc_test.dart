import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/startup/bloc/startup_bloc.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/startup_fakes.dart';

const ProblemDetails _limit = ProblemDetails(
  type: 'https://errors.finance-a2ui/rate-limited',
  title: 'Too Many Requests',
  status: 429,
  detail: 'Too many requests. Try again shortly.',
);

const AuthSession _session = AuthSession(token: 't', provider: 'firebase');

AuthState _unavailable(AppFailure failure) => AuthState(
  status: AuthStatus.unavailable,
  session: _session,
  failure: failure,
);

void main() {
  group(StartupBloc, () {
    late AuthRepository repository;
    late Completer<void> window;
    late List<Duration> waited;

    StartupBloc buildBloc() => StartupBloc(
      authRepository: repository,
      wait: (duration) {
        waited.add(duration);
        return window.future;
      },
    );

    setUp(() {
      repository = startupRepository();
      window = Completer<void>();
      waited = <Duration>[];
    });

    test('starts on the neutral wait', () {
      expect(buildBloc().state, const StartupState());
    });

    blocTest<StartupBloc, StartupState>(
      'a failure with no Retry-After offers Try again at once',
      build: buildBloc,
      act: (bloc) => bloc.add(
        StartupAuthChanged(_unavailable(const TransportFailure('offline'))),
      ),
      expect: () => const <StartupState>[
        StartupState(failure: TransportFailure('offline'), canRetry: true),
      ],
    );

    blocTest<StartupBloc, StartupState>(
      'a 429 holds Try again back for its Retry-After window',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(
          StartupAuthChanged(
            _unavailable(
              const ProblemFailure(_limit, retryAfter: Duration(seconds: 60)),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        window.complete();
      },
      expect: () => const <StartupState>[
        StartupState(
          failure: ProblemFailure(_limit, retryAfter: Duration(seconds: 60)),
        ),
        StartupState(
          failure: ProblemFailure(_limit, retryAfter: Duration(seconds: 60)),
          canRetry: true,
        ),
      ],
      verify: (_) => expect(waited, <Duration>[const Duration(seconds: 60)]),
    );

    blocTest<StartupBloc, StartupState>(
      'a window that ends after the failure cleared changes nothing',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(
          StartupAuthChanged(
            _unavailable(
              const ProblemFailure(_limit, retryAfter: Duration(seconds: 1)),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StartupAuthChanged(AuthState()));
        await Future<void>.delayed(Duration.zero);
        window.complete();
      },
      skip: 1,
      expect: () => const <StartupState>[StartupState()],
    );

    blocTest<StartupBloc, StartupState>(
      'Try again is ignored inside the window',
      build: buildBloc,
      seed: () => const StartupState(failure: ProblemFailure(_limit)),
      act: (bloc) => bloc.add(const StartupRetryRequested()),
      expect: () => const <StartupState>[],
      verify: (_) => expect(repository.state.status, AuthStatus.unknown),
    );

    blocTest<StartupBloc, StartupState>(
      'Try again asks the registry again and follows its answer',
      setUp: () => repository = startupRepository(
        answers: <Object>[rateLimited(retryAfter: null), admitted()],
      ),
      build: buildBloc,
      act: (bloc) async {
        await repository.restore();
        await Future<void>.delayed(Duration.zero);
        bloc.add(const StartupRetryRequested());
        await Future<void>.delayed(Duration.zero);
      },
      wait: const Duration(milliseconds: 10),
      expect: () => <Matcher>[
        equals(const StartupState()),
        isA<StartupState>().having((s) => s.canRetry, 'canRetry', isTrue),
        equals(const StartupState()),
      ],
      verify: (_) => expect(repository.state.allowsShell, isTrue),
    );
  });
}
