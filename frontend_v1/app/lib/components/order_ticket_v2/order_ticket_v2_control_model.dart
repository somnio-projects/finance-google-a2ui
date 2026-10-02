import 'package:equatable/equatable.dart';

/// One button the ticket draws, as `controls[]` carries it.
///
/// Every word here is the backend's. [label] used to be a `static const` on
/// the buttons widget — design's copy compiled into the bundle, unable to
/// follow the `locale` option, which is N-9 with the sentence pointing the
/// wrong way (backend spec 0050). [reason] is the same: the sentence a
/// screen reader hears is written where the fact lives, not here.
///
/// It is deliberately **not** a surface action. `SurfaceActionRequest` is for
/// something a surface sends back; this ticket sends nothing — `effect` is
/// `recalculate` and the disclosure says nothing is ever placed or settled.
class OrderTicketV2Control extends Equatable {
  /// Creates a control.
  const OrderTicketV2Control({
    required this.key,
    required this.label,
    required this.kind,
    required this.enabled,
    required this.reason,
  });

  /// Stable id the widget keys off: `review`.
  final String key;

  /// What the button says, server-written (N-9).
  final String label;

  /// `primary` or `secondary` — the design's hierarchy, never inferred from
  /// the label.
  final String kind;

  /// Whether pressing it does anything. False on every control this ticket
  /// serves, and a declared flag rather than something this client decides.
  final bool enabled;

  /// Why it is not live, shown and announced verbatim; null when it is.
  final String? reason;

  /// Whether the design wants this drawn as the prominent button.
  bool get isPrimary => kind == 'primary';

  @override
  List<Object?> get props => <Object?>[key, label, kind, enabled, reason];
}
