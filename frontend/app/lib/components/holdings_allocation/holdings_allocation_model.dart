import 'package:equatable/equatable.dart';
import 'package:finance_app/components/holdings_allocation/allocation_gain.dart';
import 'package:finance_app/components/holdings_allocation/allocation_group.dart';

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

/// Everything `holdings.allocation.v1` puts on screen.
class AllocationData extends Equatable {
  /// Creates the model.
  const AllocationData({
    required this.title,
    required this.totalLabel,
    required this.totalDisplay,
    required this.categories,
    this.groups = const <AllocationGroup>[],
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

  /// `groups[]` — every grouping the toggle offers, in the backend's order.
  ///
  /// Empty is a legitimate payload: a host that cannot re-request draws no
  /// toggle, and a card built from a literal in a test carries none.
  final List<AllocationGroup> groups;

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
    groups,
    groupBy,
    centerCount,
    centerUnit,
    totalGain,
    headline,
  ];
}
