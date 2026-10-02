import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_app/features/sign_in/view/sign_in_field_decoration.dart';
import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';

/// The e-mail field, its focused helper and `Continue with email`.
///
/// Three copies the design prints: the resting field (L1), the focused field
/// with `Use your provisioned work email` (L2), and — when the person came
/// back through a link — the same field asking them to confirm the address.
class SignInEmailForm extends StatefulWidget {
  /// Creates the form.
  const SignInEmailForm({
    required this.state,
    required this.onSubmitted,
    required this.usesEmailLink,
    this.finishing = false,
    super.key,
  });

  /// The helper under the focused field.
  static const String helper = 'Use your provisioned work email';

  /// The primary button's words.
  static const String label = 'Continue with email';

  /// The primary button's words when finishing an e-mail sign-in.
  static const String finishLabel = 'Finish signing in';

  /// The sentence shown once a link went out.
  static const String linkSent =
      'Check your inbox — we sent you a sign-in link.';

  /// The screen's state.
  final SignInState state;

  /// Whether the person came back through a link.
  final bool finishing;

  /// Whether the button sends a link (Firebase) or signs in (preview).
  final bool usesEmailLink;

  /// Called with the trimmed e-mail.
  final ValueChanged<String> onSubmitted;

  @override
  State<SignInEmailForm> createState() => _SignInEmailFormState();
}

class _SignInEmailFormState extends State<SignInEmailForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.state.email,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _controller.text.trim();
    if (email.isEmpty) {
      _focus.requestFocus();
      return;
    }
    widget.onSubmitted(email);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LoginTokens.of(context);
    final focused = _focus.hasFocus;
    final sent = widget.state.status == SignInStatus.linkSent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 56,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: !widget.state.isBusy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onSubmitted: (_) => _submit(),
            style: TextStyle(fontSize: 15, color: tokens.title),
            cursorColor: tokens.fieldFocus,
            decoration: signInFieldDecoration(tokens, focused: focused),
          ),
        ),
        if (focused || widget.finishing || sent)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              sent ? SignInEmailForm.linkSent : SignInEmailForm.helper,
              style: TextStyle(fontSize: 11.5, color: tokens.helper),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: widget.state.isBusy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: tokens.primary,
              foregroundColor: tokens.primaryText,
              disabledBackgroundColor: tokens.primary.withValues(alpha: 0.6),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: widget.state.isBusy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.primaryText,
                    ),
                  )
                : Text(
                    widget.finishing
                        ? SignInEmailForm.finishLabel
                        : SignInEmailForm.label,
                  ),
          ),
        ),
      ],
    );
  }
}
