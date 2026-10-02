part of 'view_payload.dart';

/// The boolean accessor, a part of [ViewPayload]'s library rather than a
/// method on the class: it reads the same private path walker, and the class
/// file stays inside the 150-line budget without shedding a comment.
extension ViewPayloadFlag on ViewPayload {
  /// Reads the boolean at [path], e.g. `is_cash`.
  ///
  /// The contract marks a few facts as flags rather than words — whether a
  /// row is the settlement fund — and the client only *branches* on one; it
  /// never prints it, so a flag can never become a figure a human reads.
  /// Throws [PayloadContractException] when the path is absent or is not a
  /// boolean, for the same reason [text] does (N-3).
  bool flag(String path) {
    final value = _at(path);
    if (value is! bool) {
      throw PayloadContractException(ContractFailure(path, 'a boolean'));
    }
    return value;
  }
}
