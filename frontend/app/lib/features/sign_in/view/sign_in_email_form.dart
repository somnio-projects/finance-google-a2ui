import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_app/features/sign_in/view/sign_in_email_check.dart';
import 'package:finance_app/features/sign_in/view/sign_in_field_decoration.dart';
import 'package:finance_app/features/sign_in/view/sign_in_submit_button.dart';
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
  static const String label = SignInSubmitButton.label;

  /// The primary button's words when finishing an e-mail sign-in.
  static const String finishLabel = SignInSubmitButton.finishLabel;

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
  bool _invalid = false;

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
    final valid = looksLikeEmail(email);
    setState(() => _invalid = !valid);
    if (valid) widget.onSubmitted(email);
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
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            onSubmitted: (_) => _submit(),
            style: TextStyle(fontSize: 15, color: tokens.title),
            cursorColor: tokens.fieldFocus,
            decoration: signInFieldDecoration(tokens, focused: focused),
          ),
        ),
        if (_invalid)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Semantics(
              liveRegion: true,
              child: Text(
                invalidEmailMessage,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          )
        else if (focused || widget.finishing || sent)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              sent ? SignInEmailForm.linkSent : SignInEmailForm.helper,
              style: TextStyle(fontSize: 11.5, color: tokens.helper),
            ),
          ),
        const SizedBox(height: 14),
        SignInSubmitButton(
          busy: widget.state.isBusy,
          finishing: widget.finishing,
          onPressed: _submit,
        ),
      ],
    );
  }
}
