part of 'order_ticket_bloc.dart';

/// Something that happened to the order ticket.
sealed class OrderTicketEvent extends Equatable {
  /// Allows subclasses to declare `const` constructors.
  const OrderTicketEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// The ticket was opened: render it with whatever options are in effect.
final class OrderTicketRequested extends OrderTicketEvent {
  /// Creates the event.
  const OrderTicketRequested();
}

/// The reader changed one declared option.
///
/// [option] is always a name the **payload** published under `inputs[].option`
/// — the widget has no other source for it, which is what makes "only
/// declared options are sent" true by construction rather than by review
/// (spec 0006 AC-1).
final class OrderTicketOptionChanged extends OrderTicketEvent {
  /// Creates the event.
  const OrderTicketOptionChanged({required this.option, required this.value});

  /// The declared option to change, e.g. `side`.
  final String option;

  /// Its new value, exactly as the control produced it.
  ///
  /// Sent as written. Nothing here pads, trims, rounds or coerces it — the
  /// backend's 422 is the authority on whether it is acceptable (N-8).
  final String value;

  @override
  List<Object?> get props => <Object?>[option, value];
}

/// The debounce elapsed: issue the request for the options now in effect.
///
/// Internal to the bloc — the view never adds it. It exists so the debounce
/// is a scheduling concern the bloc owns, rather than a timer a widget holds.
final class OrderTicketReloaded extends OrderTicketEvent {
  /// Creates the event.
  const OrderTicketReloaded();
}
