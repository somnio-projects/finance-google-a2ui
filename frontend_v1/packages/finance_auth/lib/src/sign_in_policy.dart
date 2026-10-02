import 'package:finance_core/finance_core.dart';

/// `GET /v1/sign-in-policy` — which door this deployment has (spec backend/0043).
///
/// The sign-in screen makes a claim about who may sign in, and it has to make
/// it *before* anybody has a token, which is the one moment
/// `GET /v1/me/access` cannot be asked. This is the answer, and it is the
/// backend's: the client does not infer the door from a compiled-in flag
/// (OD-1), because a second declaration of one fact is free to disagree with
/// the first.
enum SignInPolicy {
  /// A verified identity the registry has never seen is admitted and enrolled.
  open,

  /// Only an `invited` or `active` account may in; everyone else may ask.
  inviteOnly;

  /// The wire value of [open], as the backend writes it.
  static const String openValue = 'open';

  /// The wire value of [inviteOnly], as the backend writes it.
  static const String inviteOnlyValue = 'invite-only';

  /// Reads the policy, or reports the field the payload lacks (N-3).
  ///
  /// An unrecognised value is a contract failure rather than a default. A
  /// third door is planned for (the backend's field is an enumeration, not a
  /// boolean), and guessing which of these two it resembles is how a client
  /// ends up making the false claim this type exists to remove.
  static Result<SignInPolicy> fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const Err<SignInPolicy>(
        ContractFailure('<response>', 'a sign-in policy object'),
      );
    }
    return switch (json['enrolment']) {
      openValue => const Ok<SignInPolicy>(SignInPolicy.open),
      inviteOnlyValue => const Ok<SignInPolicy>(SignInPolicy.inviteOnly),
      _ => const Err<SignInPolicy>(
        ContractFailure('enrolment', "'open' or 'invite-only'"),
      ),
    };
  }

  /// Whether the screen should offer the design's invite line and its link.
  ///
  /// Only [inviteOnly] does. An [open] deployment shows nothing there, and an
  /// unknown policy — a read still in flight, or one that failed — shows
  /// nothing either, which is why the screen holds a `SignInPolicy?` and asks
  /// this of it rather than branching on two booleans (OD-4, OD-5).
  bool get offersInvite => this == SignInPolicy.inviteOnly;
}
