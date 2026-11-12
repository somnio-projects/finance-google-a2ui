import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';

/// The primary button: `Continue with email`, or a spinner while busy.
class SignInSubmitButton extends StatelessWidget {
  /// Creates the button.
  const SignInSubmitButton({
    required this.busy,
    required this.finishing,
    required this.onPressed,
    super.key,
  });

  /// The primary button's words.
  static const String label = 'Continue with email';

  /// The primary button's words when finishing an e-mail sign-in.
  static const String finishLabel = 'Finish signing in';

  /// Whether a request is in flight.
  final bool busy;

  /// Whether the person came back through a link.
  final bool finishing;

  /// Called on press.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = LoginTokens.of(context);
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.primaryText,
          disabledBackgroundColor: tokens.primary.withValues(alpha: 0.6),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.primaryText,
                ),
              )
            : Text(finishing ? finishLabel : label),
      ),
    );
  }
}
