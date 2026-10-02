import 'package:equatable/equatable.dart';

/// The all-time gain the design prints under the total (`total_gain`).
///
/// Its own file since GGU-145 added `groups[]` and the model passed the
/// 150-line budget. The seam is the payload's own: this is one block of it.
/// The all-time gain block under the total (`total_gain`).
class AllocationGain extends Equatable {
  /// Creates the block.
  const AllocationGain({
    required this.amountDisplay,
    required this.percentDisplay,
    required this.trend,
    required this.period,
  });

  /// `total_gain.amount.display`, e.g. `+$61,204`.
  final String amountDisplay;

  /// `total_gain.percent.display`, e.g. `+14.5%`.
  final String percentDisplay;

  /// `total_gain.trend`.
  final String trend;

  /// `total_gain.period`, e.g. `all-time`.
  final String period;

  @override
  List<Object?> get props => <Object?>[
    amountDisplay,
    percentDisplay,
    trend,
    period,
  ];
}
