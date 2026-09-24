import 'package:finance_views_repository/finance_views_repository.dart';

/// The sentence for a turn that failed, chosen by the failure's **code**.
///
/// The Assistant used to print the failure's `message` and `code` as they
/// arrived — `model provider unavailable` over `dependency-unavailable`, in
/// red, where an answer should have been (GGU-111). Both strings are safe;
/// neither is copy. That detail is written for an operator reading a log, and
/// the contract says a client branches on `code`, never on `detail`, because
/// the detail is prose the backend may reword (contract-binding rules §4).
///
/// So the one code whose detail is an operator's gets a sentence about what a
/// person can do. Every other code shows the failure's own `message`: for
/// `transport-unavailable` that message is already this client's copy
/// (`the agent could not be reached`, `the request timed out`, the credential
/// sentence), and for a code this file has never met, inventing a sentence
/// would be a guess wearing the tone of a fact.
///
/// This is the one exception to "a failure shown to a user is the backend's
/// own safe `detail`" (`.claude/rules/frontend/architecture.md` §4), and it
/// is recorded there.
String turnFailureNotice(AgentFailed? failure) => switch (failure?.code) {
  'dependency-unavailable' =>
    'The assistant is not available right now. '
        'Nothing was lost — try again in a moment.',
  null => 'The turn did not finish. Try again.',
  _ => failure!.message,
};

/// The control's words.
const String turnRetryLabel = 'Try again';
