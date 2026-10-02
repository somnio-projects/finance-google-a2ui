import 'package:equatable/equatable.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_control_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_line_model.dart';

export 'order_ticket_v2_control_model.dart';
export 'order_ticket_v2_line_model.dart';

/// One figure of the impact panel, already formatted by the backend.
///
/// [display] is the only thing that reaches a `Text`. There is no `double`
/// on this class to be tempted into arithmetic with (N-2).
class OrderTicketV2Figure extends Equatable {
  /// Creates a figure.
  const OrderTicketV2Figure({
    required this.name,
    required this.label,
    required this.display,
  });

  /// A stable slot name, so a changed figure is marked without matching on
  /// its value: `total`, `fees`, `cash`.
  final String name;

  /// The caption, server-written (N-9).
  final String label;

  /// The backend's own formatted string, rendered verbatim.
  final String display;

  @override
  List<Object?> get props => <Object?>[name, label, display];
}

/// A group's share of the portfolio before and after the order.
class OrderTicketV2Shift extends Equatable {
  /// Creates a shift.
  const OrderTicketV2Shift({
    required this.key,
    required this.label,
    required this.beforeDisplay,
    required this.afterDisplay,
  });

  /// Stable group id, e.g. `technology`.
  final String key;

  /// `Portfolio weight · Technology`, server-written.
  final String label;

  /// `before.display`.
  final String beforeDisplay;

  /// `after.display`.
  final String afterDisplay;

  @override
  List<Object?> get props => <Object?>[key, label, beforeDisplay, afterDisplay];
}

/// Everything `order.ticket.v2` puts on screen.
class OrderTicketV2Data extends Equatable {
  /// Creates the model.
  const OrderTicketV2Data({
    required this.title,
    required this.badge,
    required this.side,
    required this.legs,
    required this.lines,
    required this.figures,
    required this.shifts,
    required this.controls,
    required this.breach,
    required this.message,
    required this.disclosure,
  });

  /// `Draft order · Buy · 3 legs`, server-written.
  final String title;

  /// The header pill as the backend named it: `editable` or `blocked`.
  final String badge;

  /// `buy` or `sell`, shown as written.
  final String side;

  /// The `legs` option in effect — the value an edit starts from.
  final String legs;

  /// The legs, in arrival order (N-10).
  final List<OrderTicketV2Line> lines;

  /// The impact panel's figures, in the order the panel shows them.
  final List<OrderTicketV2Figure> figures;

  /// The weight rows, in arrival order.
  final List<OrderTicketV2Shift> shifts;

  /// The buttons the design draws, in arrival order (N-10). Their words and
  /// their enabled state are the backend's, not this client's.
  final List<OrderTicketV2Control> controls;

  /// `constraints.breach`: `none`, or the bound the draft exceeds.
  final String breach;

  /// `constraints.message`, rendered verbatim when present (N-9).
  final String? message;

  /// The compliance statement, rendered verbatim in every state (N-9).
  final String disclosure;

  /// Whether the backend declared the draft blocked. A declared flag is
  /// read, never a comparison this client performs (spec backend/0031 OD-4).
  bool get isBlocked => breach != 'none';

  @override
  List<Object?> get props => <Object?>[
    title,
    badge,
    side,
    legs,
    lines,
    figures,
    shifts,
    controls,
    breach,
    message,
    disclosure,
  ];
}
