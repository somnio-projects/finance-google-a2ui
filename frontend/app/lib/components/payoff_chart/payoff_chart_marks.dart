import 'package:equatable/equatable.dart';

/// One rung of the value axis: where it sits, and what it says there.
///
/// Both halves are the backend's (`value_ticks[]`): the client places the
/// rule at [at] and prints [display] verbatim. It picked neither — a client
/// choosing its own ladder would be computing a figure it then has to format
/// (N-2 and N-1 in one step), which is why the field exists (GGU-146).
class PayoffRung extends Equatable {
  /// Creates a rung.
  const PayoffRung({required this.at, required this.display});

  /// `value_ticks[].amount`, read only as geometry (ADR-L D-14).
  final double at;

  /// `value_ticks[].display`.
  final String display;

  @override
  List<Object?> get props => <Object?>[at, display];
}

/// A reference price the chart draws a line or a dot at.
class PayoffMarker extends Equatable {
  /// Creates a marker.
  const PayoffMarker({
    required this.label,
    required this.display,
    required this.at,
  });

  /// `markers.<name>.label`.
  final String label;

  /// `markers.<name>.at.display`.
  final String display;

  /// `markers.<name>.at.amount`, as geometry.
  final double at;

  /// What the chart writes beside the rule: the backend's two strings, in
  /// that order. The client joins them and writes neither.
  String get caption => '$label $display';

  @override
  List<Object?> get props => <Object?>[label, display, at];
}
