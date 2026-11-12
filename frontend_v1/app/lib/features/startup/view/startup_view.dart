import 'package:finance_app/features/shell/view/tab_failure.dart';
import 'package:finance_app/features/startup/bloc/startup_bloc.dart';
import 'package:finance_app/skeleton/skeleton_pulse.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The start-up surface: the app's mark, breathing, until the session is
/// known — or the registry's sentence and *Try again* when it could not say.
///
/// Neutral on purpose. It names no screen it is about to open and draws no
/// form, because at this point the app does not know which one is next. The
/// failure half is `TabFailure`, the same state and the same *Try again* a
/// tab shows when its own call is rate-limited (GGU-159 AC).
class StartupView extends StatelessWidget {
  /// Creates the view.
  const StartupView({super.key});

  /// What a screen reader hears while the session is restored.
  static const String loadingLabel = 'Loading';

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.page,
      body: SafeArea(
        child: BlocBuilder<StartupBloc, StartupState>(
          builder: (context, state) => switch (state.failure) {
            null => const _Mark(),
            final failure => TabFailure(
              message: failure.message,
              onRetry: state.canRetry
                  ? () => context.read<StartupBloc>().add(
                      const StartupRetryRequested(),
                    )
                  : null,
            ),
          },
        ),
      ),
    );
  }
}

/// The sign-in screen's logo tile, without the words around it.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: StartupView.loadingLabel,
      liveRegion: true,
      child: SkeletonPulse(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: LoginTokens.logoGradient,
            ),
          ),
        ),
      ),
    ),
  );
}
