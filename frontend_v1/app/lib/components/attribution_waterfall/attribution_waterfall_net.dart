import 'package:equatable/equatable.dart';

/// Which way the walk's net moved, as the backend declared it.
///
/// The contract's `net.direction` is `up / down / flat`. It is its own enum
/// rather than a `WaterfallStepKind`: a net is not a bar, and `flat` has no
/// bar kind to map onto. The header's colour comes from this field and never
/// from the sign of a figure (N-1).
enum NetDirection {
  /// The walk ended above where it started.
  up,

  /// The walk ended below where it started.
  down,

  /// The walk ended where it started; the backend prints no sign.
  flat,
}

/// The headline of `attribution.waterfall.v1` — *+$3,240 · +0.68%*.
///
/// Both figures arrive **signed** from the backend (GGU-100 AC-1/AC-2); the
/// client joins them with a middle dot and colours them from [direction], and
/// nothing else. The glyph, the parentheses and the pill they sat on were the
/// older catalog page's and went with it (spec frontend/0028 OD-1).
class AttributionNet extends Equatable {
  /// Creates the headline.
  const AttributionNet({
    required this.label,
    required this.amountDisplay,
    required this.percentDisplay,
    required this.direction,
  });

  /// The payload's `net.label`, e.g. `Net`.
  final String label;

  /// The payload's `net.amount.display`, sign included.
  final String amountDisplay;

  /// The payload's `net.percent.display`, sign included.
  final String percentDisplay;

  /// The payload's `net.direction`.
  final NetDirection direction;

  @override
  List<Object?> get props => <Object?>[
    label,
    amountDisplay,
    percentDisplay,
    direction,
  ];
}
