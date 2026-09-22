import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_app/features/sign_in/view/sign_in_email_form.dart';
import 'package:finance_app/features/sign_in/view/sign_in_footer.dart';
import 'package:finance_app/features/sign_in/view/sign_in_google_button.dart';
import 'package:finance_app/features/sign_in/view/sign_in_hero.dart';
import 'package:finance_app/features/sign_in/view/sign_in_snack.dart';
import 'package:finance_app/theme/login_tokens.dart';
import 'package:finance_app/theme/theme_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The sign-in screen: hero · Google · `or` · e-mail · invite line · footer,
/// at the design's 56/28/28 padding on a 390-wide artboard.
class SignInView extends StatelessWidget {
  /// Creates the view. [emailLink] is set when finishing an e-mail sign-in.
  const SignInView({this.emailLink, super.key});

  /// The design's widest content column.
  static const double maxWidth = 390;

  /// The sign-in link the person came back through, if any.
  final Uri? emailLink;

  @override
  Widget build(BuildContext context) {
    final tokens = LoginTokens.of(context);
    return BlocListener<SignInBloc, SignInState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showSignInSnack(context, state.message!),
      child: Scaffold(
        backgroundColor: tokens.page,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxWidth),
                  child: BlocBuilder<SignInBloc, SignInState>(
                    builder: (context, state) =>
                        _Body(state: state, emailLink: emailLink),
                  ),
                ),
              ),
              // Both artboards exist; this is how a visitor reaches the other
              // one before signing in (spec frontend/0010).
              const Positioned(top: 8, right: 8, child: ThemeToggleButton()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.emailLink});

  final SignInState state;
  final Uri? emailLink;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SignInBloc>();
    final link = emailLink;
    // No flex child and no intrinsic pass: the column is at least the
    // viewport tall, `spaceBetween` parks the footer at the bottom when there
    // is room, and the page scrolls when there is not.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 56, 28, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 84),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SignInHero(),
                  const SizedBox(height: 44),
                  if (link == null) ...<Widget>[
                    SignInGoogleButton(
                      busy: state.isBusy,
                      onPressed: () => bloc.add(const SignInGoogleRequested()),
                    ),
                    const _OrDivider(),
                  ],
                  SignInEmailForm(
                    state: state,
                    finishing: link != null,
                    usesEmailLink: bloc.usesEmailLink,
                    onSubmitted: (email) => bloc.add(
                      link == null
                          ? SignInEmailSubmitted(email)
                          : SignInLinkCompleted(email: email, link: link),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SignInInviteLine(
                    onRequestAccess: (email) =>
                        bloc.add(SignInAccessRequested(email)),
                    requested: state.status == SignInStatus.requested,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: SignInFooter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final tokens = LoginTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: <Widget>[
          Expanded(child: Container(height: 1, color: tokens.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'or',
              style: TextStyle(fontSize: 12, color: tokens.dividerText),
            ),
          ),
          Expanded(child: Container(height: 1, color: tokens.divider)),
        ],
      ),
    );
  }
}
