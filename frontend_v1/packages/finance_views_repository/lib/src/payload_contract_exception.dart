import 'package:finance_core/finance_core.dart';

/// Thrown when a payload does not carry a field the reader asked for.
///
/// This is deliberately loud. Prohibition N-3 says that a value the payload
/// does not carry means *the payload is missing a field* — the client raises
/// it rather than reconstructing it — so a missing path has to be impossible
/// to ignore. The host widget catches it and renders the violation on screen,
/// which puts the defect in front of whoever is looking at the component.
class PayloadContractException implements Exception {
  /// Records that the payload broke its contract at [failure].
  const PayloadContractException(this.failure);

  /// The path that was missing and what was expected there.
  final ContractFailure failure;

  @override
  String toString() => 'PayloadContractException: ${failure.message}';
}
