import 'package:flutter/material.dart';

/// What the screen says between "the provider vouched" and "the registry
/// answered".
///
/// That window used to show the sign-in form unchanged, so a person who had
/// just signed in saw the button they had pressed and assumed it had failed.
/// On a first sign-in the registry is enrolling them (spec `backend/0040`),
/// which is worth saying rather than spinning silently.
///
/// The words are the product's, not a payload's: no backend response exists
/// yet at this point — that is the whole state.
class SignInProvisioningNote extends StatelessWidget {
  /// Creates the note.
  const SignInProvisioningNote({super.key});

  /// What it says. One sentence, and it does not promise a duration it
  /// cannot know.
  static const String message = 'Setting up your account…';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
