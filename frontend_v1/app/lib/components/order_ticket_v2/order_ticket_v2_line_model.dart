import 'package:equatable/equatable.dart';

/// One leg of the draft, as `lines[]` carries it.
///
/// [increment] and [decrement] are the **whole `legs` option value** the
/// stepper's `+` and `-` send — written by the backend, because this client
/// may not add one to a share count (N-2). `null` means the move would leave
/// the published bound, and the control is disabled (spec backend/0031 OD-3).
class OrderTicketV2Line extends Equatable {
  /// Creates a line.
  const OrderTicketV2Line({
    required this.key,
    required this.symbol,
    required this.name,
    required this.priceDisplay,
    required this.quantityDisplay,
    required this.notionalDisplay,
    required this.weightDisplay,
    required this.weight,
    required this.increment,
    required this.decrement,
    required this.stops,
    required this.position,
    this.entry,
  });

  /// Stable id: the ticker.
  final String key;

  /// The ticker shown.
  final String symbol;

  /// The asset's name.
  final String name;

  /// `price.display`.
  final String priceDisplay;

  /// `quantity.display`.
  final String quantityDisplay;

  /// `notional.display`.
  final String notionalDisplay;

  /// `weight.display`.
  final String weightDisplay;

  /// `weight.value`, read through `ViewPayload.geometry` **only** to size the
  /// weight bar's fill. It never reaches a `Text` (N-4, ADR-L D-14).
  final double weight;

  /// The `legs` value a `+` sends, or null at the bound.
  final String? increment;

  /// The `legs` value a `-` sends, or null at zero.
  final String? decrement;

  /// Every `legs` value this leg's slider can land on, ascending by this
  /// leg's **weight in the order** and written by the backend — a drag picks
  /// one, it never computes one (N-2). A single entry means the draft has no
  /// mix to move, and the track is not draggable.
  final List<String> stops;

  /// The `legs` value with this leg's units left as `{units}`, for a typed
  /// quantity (spec backend/0054); null on a payload that predates it.
  final String? entry;

  /// Index into [stops] of the value on screen, read as a coordinate.
  ///
  /// It travels as a decimal string because `ViewPayload` has no reader for a
  /// JSON number, and it is read through `geometry` because that is what the
  /// seam is for: a thumb's index is a position, and it never reaches a
  /// `Text` (backend spec 0050 §7b, ADR-L D-14).
  final double position;

  @override
  List<Object?> get props => <Object?>[
    key,
    symbol,
    name,
    priceDisplay,
    quantityDisplay,
    notionalDisplay,
    weightDisplay,
    weight,
    increment,
    decrement,
    stops,
    position,
    entry,
  ];
}
