import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';

/// `GET /v1/me/access` — whether the shell may open, in the backend's words.
///
/// [message] is the sentence the sign-in screen shows verbatim (N-9): the
/// design's *This account isn't provisioned for the preview.* is written on
/// the server, never here.
class AccessDecision extends Equatable {
  /// Creates the decision.
  const AccessDecision({
    required this.provisioned,
    required this.message,
    this.email,
    this.status,
    this.role,
    this.displayName,
  });

  /// Reads the decision, or reports the field the payload lacks (N-3).
  static Result<AccessDecision> fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const Err<AccessDecision>(
        ContractFailure('<response>', 'an access object'),
      );
    }
    final provisioned = json['provisioned'];
    final message = json['message'];
    if (provisioned is! bool) {
      return const Err<AccessDecision>(ContractFailure('provisioned', 'bool'));
    }
    if (message is! String) {
      return const Err<AccessDecision>(ContractFailure('message', 'string'));
    }
    return Ok<AccessDecision>(
      AccessDecision(
        provisioned: provisioned,
        message: message,
        email: json['email'] as String?,
        status: json['status'] as String?,
        role: json['role'] as String?,
        displayName: json['display_name'] as String?,
      ),
    );
  }

  /// Whether the person was invited.
  final bool provisioned;

  /// The backend's sentence about it.
  final String message;

  /// The e-mail the decision is about.
  final String? email;

  /// The registry status, when the e-mail is known.
  final String? status;

  /// `member` or `admin`.
  final String? role;

  /// How the shell greets them.
  final String? displayName;

  @override
  List<Object?> get props => <Object?>[
    provisioned,
    message,
    email,
    status,
    role,
    displayName,
  ];
}
