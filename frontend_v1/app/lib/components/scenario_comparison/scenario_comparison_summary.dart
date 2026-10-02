import 'package:flutter/foundation.dart';

/// The header pill and the footer sentence, both server-written.
///
/// The sentence arrives with its figures already in it. Assembling prose
/// around two numbers is exactly what N-9 keeps on the server.
@immutable
class ScenarioSummary {
  /// Creates the summary.
  const ScenarioSummary({required this.badge, required this.text});

  /// The payload's `summary.badge`, e.g. `Best result`.
  final String badge;

  /// The payload's `summary.text`, rendered verbatim.
  final String text;
}
