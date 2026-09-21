import 'package:equatable/equatable.dart';
import 'package:finance_app/components/order_ticket/order_ticket_figure.dart';

/// How an editable option is offered, as `inputs[].control` declares it.
///
/// The contract's enum is `choice / text` and this mirrors it exactly. A third
/// spelling is a contract violation, not a default — the component raises
/// rather than guessing which control the backend meant (N-3).
enum OrderTicketControl {
  /// One of a closed list; `inputs[].choices` is that list.
  choice,

  /// Free text bounded by `inputs[].pattern`, described by `hint`.
  text,
}

/// One editable option, exactly as the payload's `inputs[]` declares it.
///
/// **Editability is derived, never chosen.** The backend publishes one
/// descriptor per option it will accept back, carrying the bound its own
/// options model enforces, so this class is a reading of the contract rather
/// than a decision this app makes. Nothing here is a list the client holds.
class OrderTicketField extends Equatable {
  /// Creates a field descriptor.
  const OrderTicketField({
    required this.option,
    required this.label,
    required this.control,
    required this.value,
    required this.choices,
    required this.pattern,
    required this.hint,
  });

  /// The declared option this control sets, e.g. `side`.
  ///
  /// It is also the name of the payload field carrying the current value —
  /// that naming *is* the interactivity declaration (ADR-K D-3, and
  /// `.claude/rules/backend/presentation.md` §4).
  final String option;

  /// The human label, server-written, rendered verbatim and used as the
  /// control's screen-reader label.
  final String label;

  /// Which control to offer.
  final OrderTicketControl control;

  /// The value in effect, ready to be sent back unchanged.
  final String value;

  /// Every accepted value for a [OrderTicketControl.choice]; empty otherwise.
  ///
  /// This is the declared bound. The client offers these and nothing else,
  /// and adds no rule of its own beside them (N-8).
  final List<String> choices;

  /// The shape a [OrderTicketControl.text] value must match; else `null`.
  ///
  /// Carried and displayed as the field's accepted form. It is a
  /// server-supplied string used as a bound, never compiled into anything
  /// that can run (N-5).
  final String? pattern;

  /// The server's words for what this field accepts. [pattern] is the
  /// machine's copy of the same fact and is never drawn.
  final String? hint;

  @override
  List<Object?> get props => <Object?>[
    option,
    label,
    control,
    value,
    choices,
    pattern,
    hint,
  ];
}

/// Everything `order.ticket.v1` puts on screen.
class OrderTicketData extends Equatable {
  /// Creates the model.
  const OrderTicketData({
    required this.title,
    required this.symbol,
    required this.name,
    required this.side,
    required this.figures,
    required this.fields,
    required this.disclosure,
  });

  /// The payload's `title`.
  final String title;

  /// The payload's `symbol`, e.g. `BTC`.
  final String symbol;

  /// The payload's `name`, e.g. `Bitcoin`.
  final String name;

  /// The payload's `side` — `buy` or `sell`, shown as written.
  final String side;

  /// The figures, in the order the card shows them.
  final List<OrderTicketFigure> figures;

  /// The editable options, in the order the backend published them (N-10).
  final List<OrderTicketField> fields;

  /// The payload's `disclosure`, rendered verbatim in every state (N-9).
  final String disclosure;

  @override
  List<Object?> get props => <Object?>[
    title,
    symbol,
    name,
    side,
    figures,
    fields,
    disclosure,
  ];
}
