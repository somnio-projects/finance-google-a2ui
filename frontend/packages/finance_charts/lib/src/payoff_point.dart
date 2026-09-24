import 'package:equatable/equatable.dart';

/// One sampled point of a payoff curve, in geometry terms only.
///
/// Both members are raw `Decimal` values the backend sent beside its
/// `*Display` strings, parsed at the single allow-listed seam
/// (`ViewPayload.geometry`, ADR-L D-14) purely so a line can be placed on a
/// canvas. Nothing here is ever shown: the label for a point travels
/// separately, already formatted, in the app's own model.
///
/// Deliberately carries no name, no label and no display string — this
/// package is the arithmetic half of a chart and holds nothing a reader sees.
class PayoffPoint extends Equatable {
  /// Creates a point at price [at] worth [value].
  const PayoffPoint({required this.at, required this.value});

  /// The price this point was sampled at — the x domain.
  final double at;

  /// The profit or loss at [at] — the y domain. Negative below break-even.
  final double value;

  @override
  List<Object?> get props => <Object?>[at, value];

  @override
  String toString() => 'PayoffPoint($at, $value)';
}
