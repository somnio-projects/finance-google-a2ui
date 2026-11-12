import 'package:finance_app/features/startup/bloc/startup_bloc.dart';
import 'package:finance_app/features/startup/view/startup_view.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `/starting` — what a signed-in person sees while the app finds out who
/// they are, instead of the sign-in form (GGU-163, GGU-159).
///
/// Owns the bloc's lifetime and is the one place that resolves the
/// [AuthRepository] from the tree (the page/view split of ADR-L).
class StartupPage extends StatelessWidget {
  /// Creates the page.
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthRepository>();
    return BlocProvider<StartupBloc>(
      // Seeded with the state that sent the router here: the change that
      // did so was emitted before this bloc existed to hear it.
      create: (_) =>
          StartupBloc(authRepository: auth)
            ..add(StartupAuthChanged(auth.state)),
      child: const StartupView(),
    );
  }
}
