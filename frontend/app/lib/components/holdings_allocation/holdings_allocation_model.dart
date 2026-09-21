import 'package:equatable/equatable.dart';

/// One allocation category, with everything the card draws.
///
/// The two figures travel as the backend's own `*.display` strings and the
/// share travels as a raw `double`. They are **disjoint on purpose**:
/// [weight] is only ever an angle and [weightDisplay] is only ever text, so
/// there is no expression anywhere in this component that turns one into the
/// other. That is prohibition N-1/N-2 made structural rather than remembered
/// — the same shape `AttributionStep` uses.
class AllocationCategory extends Equatable {
  /// Creates a category.
  const AllocationCategory({
    required this.key,
    required this.label,
    required this.valueDisplay,
    required this.weightDisplay,
    required this.weight,
  });

  /// The payload's `key`, e.g. `BTC` — or `other` for the residual bucket the
  /// backend adds and the client never computes.
  final String key;

  /// The payload's `label`, e.g. `Bitcoin`.
  final String label;

  /// The payload's `value.display`, e.g. `$38,550.00`. Drawn verbatim.
  final String valueDisplay;

  /// The payload's `weight.display`, e.g. `59.27%`. Drawn verbatim.
  ///
  /// Never derived from [weight], and never used to derive it. The backend
  /// rounds to the view's `precision` option; recomputing this string here
  /// would silently disagree with the server at the second decimal.
  final String weightDisplay;

  /// The payload's raw `weight.value`, **for arc geometry only**.
  ///
  /// Read through `ViewPayload.geometry`, the one number seam (ADR-L D-14).
  /// It becomes a sweep in radians and reaches no `Text`.
  final double weight;

  @override
  List<Object?> get props => <Object?>[
    key,
    label,
    valueDisplay,
    weightDisplay,
    weight,
  ];
}

/// Everything `holdings.allocation.v1` renders.
class AllocationData extends Equatable {
  /// Creates the model.
  const AllocationData({
    required this.title,
    required this.totalLabel,
    required this.totalDisplay,
    required this.categories,
  });

  /// The payload's `title`, e.g. `Allocation by holding`.
  final String title;

  /// The payload's `total.label`, e.g. `Total market value`.
  final String totalLabel;

  /// The payload's `total.amount.display`, e.g. `$65,038.60`.
  final String totalDisplay;

  /// The payload's `categories`, in the order the backend sent them (N-10).
  final List<AllocationCategory> categories;

  /// Whether the backend sent no categories at all — an empty portfolio.
  ///
  /// The catalog declares `categories` with `state: "empty"`, so this is a
  /// state the contract has, not one the client invented.
  bool get isEmpty => categories.isEmpty;

  /// The raw shares the donut is swept from, in payload order.
  List<double> get weights => <double>[
    for (final category in categories) category.weight,
  ];

  @override
  List<Object?> get props => <Object?>[
    title,
    totalLabel,
    totalDisplay,
    categories,
  ];
}
