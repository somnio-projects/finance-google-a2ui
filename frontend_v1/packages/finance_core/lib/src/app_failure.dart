import 'package:equatable/equatable.dart';
import 'package:finance_core/src/problem_details.dart';

/// Why an operation failed, as a value rather than an exception.
///
/// The hierarchy is `sealed`, so a `switch` over an [AppFailure] is exhaustive
/// and adding a failure kind makes every incomplete handler a compile error
/// instead of a silent fall-through.
///
/// Every subtype carries a [code] that is safe to log and a [message] that
/// is safe to show. Keeping that true is the *producer's* job, not this
/// file's: a `TransportFailure` built from `http.ClientException.message`
/// would smuggle the library's own text — and, on `BrowserClient`, the
/// target URL — straight to a widget. `FinanceApiClient` therefore writes
/// its own wording, and a test holds it to that (`frontend/SECURITY.md`,
/// N-14).
sealed class AppFailure extends Equatable {
  const AppFailure();

  /// Stable, loggable identifier for this failure kind.
  String get code;

  /// Safe, human-readable description. Never contains credentials or PII.
  String get message;

  @override
  List<Object?> get props => <Object?>[code, message];
}

/// The request never produced an HTTP response — socket error, DNS, timeout.
final class TransportFailure extends AppFailure {
  /// Creates a transport failure described by [message].
  const TransportFailure(this.message);

  @override
  final String message;

  @override
  String get code => 'transport-unavailable';
}

/// The backend answered with an RFC 9457 problem document.
final class ProblemFailure extends AppFailure {
  /// Wraps the [problem] the backend returned.
  const ProblemFailure(this.problem);

  /// The document as received.
  final ProblemDetails problem;

  @override
  String get code => problem.code;

  @override
  String get message => problem.detail;

  @override
  List<Object?> get props => <Object?>[problem];
}

/// The response arrived but did not match the shape the contract declares.
///
/// This is the failure that enforces prohibition N-3: when a payload does not
/// carry a field a component binds, the client says so loudly instead of
/// reconstructing the value. [path] names the field that was missing, which is
/// what a reader needs in order to raise it against the backend.
final class ContractFailure extends AppFailure {
  /// Records that [path] was absent or of the wrong type.
  const ContractFailure(this.path, this.expected);

  /// Dotted path into the payload, e.g. `total.amount.display`.
  final String path;

  /// What the contract declares at [path], e.g. `string`.
  final String expected;

  @override
  String get code => 'contract-violation';

  @override
  String get message => 'payload is missing $expected at "$path"';

  @override
  List<Object?> get props => <Object?>[path, expected];
}
