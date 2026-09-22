import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_app/features/sign_in/view/sign_in_view.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `Login.dc.html` — outside the shell, so a stranger sees no tab bar.
///
/// Owns the bloc's lifetime and is the one place that resolves the
/// [AuthRepository] from the tree (the page/view split of ADR-L). [link] is
/// the page URL: when the identity provider issued it, the screen finishes an
/// e-mail sign-in instead of starting one.
class SignInPage extends StatelessWidget {
  /// Creates the page. [link] defaults to the browser's own URL.
  const SignInPage({this.link, super.key});

  /// The URL the page was opened at, when a test wants to fix it.
  final Uri? link;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthRepository>();
    final opened = link ?? Uri.base;
    return BlocProvider<SignInBloc>(
      create: (_) => SignInBloc(
        authRepository: auth,
        continueUrl: opened.replace(path: AppRoutes.signIn, query: ''),
      ),
      child: SignInView(emailLink: auth.isEmailLink(opened) ? opened : null),
    );
  }
}
