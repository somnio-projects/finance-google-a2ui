import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/widgets.dart';

/// Where a gesture on the weight bar's track goes.
///
/// Its own file for the file budget, and the seam is a real one: **what a
/// touch means** is not the same question as **what the bar looks like**.
///
/// **The pixel-to-index step is `BandScale.bandAt`, not arithmetic here.**
/// `binding_rules_compute_test.dart` needles the rounding mechanisms across
/// `lib/` and is right to — a component is where a rounded figure would do
/// damage. But *"which step did this tap land on"* has an owner already:
/// `finance_charts` takes coordinates, returns indices, sees no payload, and
/// holds the one carve-out that rule makes for exactly this question (ADR-L
/// D-13). Doing it inline would have widened the allow-set to a file that
/// **does** read a payload.
///
/// The index then selects a string the backend wrote, so a pixel becomes a
/// list index and never a quantity (N-2).
///
/// This comment quotes none of those mechanisms, on purpose: the rule greps
/// `lib/` as plain text, comments included.
@immutable
class OrderTicketV2TrackGesture {
  /// Creates the mapping for [stops], reported to [onLegsChanged].
  const OrderTicketV2TrackGesture({
    required this.stops,
    required this.onLegsChanged,
  });

  /// The `legs` values a drag may land on, in the order the backend sent them.
  final List<String> stops;

  /// Where a chosen stop goes; null when no host can honour an edit.
  final ValueChanged<String>? onLegsChanged;

  /// Whether the track accepts a gesture at all.
  ///
  /// A one-stop ladder is a draft with no mix to move — a single leg, or one
  /// whose others are all zero. Dragging it would send the value it already
  /// has, so the track is inert instead.
  bool get isLive => onLegsChanged != null && stops.length > 1;

  /// A handler for a track [width] wide, or null when the track is inert.
  ///
  /// A named member rather than an inline closure so the parameter takes its
  /// type from the signature: the analyzer forbids annotating it inline, and
  /// without one it would infer `dynamic`.
  ValueChanged<Offset>? on(double width) =>
      isLive ? (offset) => onLegsChanged!(_stopAt(offset.dx, width)) : null;

  /// The stop whose band the gesture at [dx] fell in.
  String _stopAt(double dx, double width) {
    final bands = BandScale(count: stops.length, width: width);
    return stops[bands.bandAt(dx) ?? stops.length - 1];
  }
}
