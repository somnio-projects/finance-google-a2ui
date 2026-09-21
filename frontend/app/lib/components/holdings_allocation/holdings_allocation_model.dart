import 'package:equatable/equatable.dart';

/// One slice of the allocation, exactly as the payload's `categories[]` says.
///
/// Every string is a `*.display` the backend formatted; [weight] is the one
/// raw member, read only to sweep an arc and size a bar (N-4).
class AllocationCategory extends Equatable {
  /// Creates the slice.
  const AllocationCategory({
    required this.key,
    required this.label,
    required this.valueDisplay,
    required this.weightDisplay,
    required this.weight,
    this.changeDisplay = '',
    this.trend = 'flat',
  });

  /// Stable id (`NVDA`, `equities`, `other`).
  final String key;

  /// Words the legend shows.
  final String label;

  /// `value.display`.
  final String valueDisplay;

  /// `weight.display`.
  final String weightDisplay;

  /// `weight.value`, as geometry.
  final double weight;

  /// `change.display` — the day change, signed by the backend.
  final String changeDisplay;

  /// `trend`: `up`, `down` or `flat`; picks the glyph and the tone.
  final String trend;

  @override
  List<Object?> get props => <Object?>[
    key,
    label,
    valueDisplay,
    weightDisplay,
    weight,
    changeDisplay,
    trend,
  ];
}

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

/// Everything `holdings.allocation.v1` puts on screen.
class AllocationData extends Equatable {
  /// Creates the model.
  const AllocationData({
    required this.title,
    required this.totalLabel,
    required this.totalDisplay,
    required this.categories,
    this.groupBy = 'holding',
    this.centerCount = '',
    this.centerUnit = '',
    this.totalGain,
    this.headline = true,
  });

  /// `title`.
  final String title;

  /// `total.label`.
  final String totalLabel;

  /// `total.amount.display`.
  final String totalDisplay;

  /// `categories[]`, in the backend's order.
  final List<AllocationCategory> categories;

  /// `group_by` — which ramp the slices take.
  final String groupBy;

  /// `center.count`, printed in the donut's hole.
  final String centerCount;

  /// `center.unit`, printed above it (`Classes`, `Holdings`).
  final String centerUnit;

  /// The gain block, when the payload carries it.
  final AllocationGain? totalGain;

  /// Whether the card draws its own title and total — false when a shell
  /// asked for `headline=false` and draws them itself.
  final bool headline;

  /// Whether there is anything to draw.
  bool get isEmpty => categories.isEmpty;

  /// The shares, for the ring and the bar.
  List<double> get weights => <double>[
    for (final category in categories) category.weight,
  ];

  @override
  List<Object?> get props => <Object?>[
    title,
    totalLabel,
    totalDisplay,
    categories,
    groupBy,
    centerCount,
    centerUnit,
    totalGain,
    headline,
  ];
}
