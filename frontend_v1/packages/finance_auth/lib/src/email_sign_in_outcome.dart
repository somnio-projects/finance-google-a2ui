import 'package:finance_core/finance_core.dart';

/// What the e-mail button did: a link went out, or the person is in.
enum EmailSignInOutcome {
  /// The provider e-mailed a sign-in link; the screen says so.
  linkSent,

  /// The local stack minted a token and the shell may open.
  signedIn,
}

/// Lifts a `Result<void>` into the [outcome] it stands for.
Result<EmailSignInOutcome> emailOutcome(
  Result<void> result,
  EmailSignInOutcome outcome,
) => switch (result) {
  Err<void>(:final failure) => Err<EmailSignInOutcome>(failure),
  Ok<void>() => Ok<EmailSignInOutcome>(outcome),
};
