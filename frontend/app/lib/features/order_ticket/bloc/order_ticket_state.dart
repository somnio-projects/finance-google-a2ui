part of 'order_ticket_bloc.dart';

/// Where the order ticket is in its round trip.
///
/// Loading and rejection are **transport** states and live here, never in a
/// payload — no payload carries an `isLoading` flag
/// (`.claude/rules/frontend/contract-binding.md` §3).
enum OrderTicketStatus {
  /// Nothing requested yet.
  initial,

  /// The first render is on its way; there is no payload to show.
  loading,

  /// An edit's re-render is on its way; the **previous** payload is still on
  /// screen, which is what keeps the ticket readable mid-edit (AC-8).
  updating,

  /// A payload is bound.
  ready,

  /// The last request was refused, or could not be made. The payload already
  /// on screen, if any, stays.
  rejected,
}

/// The order ticket's state.
final class OrderTicketState extends Equatable {
  /// Creates the state.
  const OrderTicketState({
    this.status = OrderTicketStatus.initial,
    this.options = const <String, String>{},
    this.payload,
    this.previous,
    this.pendingOption,
    this.rejection,
  });

  /// Where the round trip is.
  final OrderTicketStatus status;

  /// The declared options in effect, every key published by `inputs[]`.
  final Map<String, String> options;

  /// The payload currently bound, or null before the first render.
  final ViewPayload? payload;

  /// The payload [payload] replaced, kept only so the view can mark which
  /// display strings changed. It is never rendered.
  final ViewPayload? previous;

  /// The option whose re-request is in flight, if any.
  final String? pendingOption;

  /// Why the last request was refused; the backend's own message.
  final String? rejection;

  /// Copies the state.
  ///
  /// Each parameter is a getter rather than a value so that passing `null`
  /// *retains* the old value while `() => null` *clears* it — the shape
  /// `PortfolioViewsState` uses.
  OrderTicketState copyWith({
    OrderTicketStatus Function()? status,
    Map<String, String> Function()? options,
    ViewPayload? Function()? payload,
    ViewPayload? Function()? previous,
    String? Function()? pendingOption,
    String? Function()? rejection,
  }) => OrderTicketState(
    status: status != null ? status() : this.status,
    options: options != null ? options() : this.options,
    payload: payload != null ? payload() : this.payload,
    previous: previous != null ? previous() : this.previous,
    pendingOption: pendingOption != null ? pendingOption() : this.pendingOption,
    rejection: rejection != null ? rejection() : this.rejection,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    options,
    payload,
    previous,
    pendingOption,
    rejection,
  ];
}
