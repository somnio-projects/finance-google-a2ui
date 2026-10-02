import 'package:equatable/equatable.dart';

/// One figure the ticket shows, already formatted by the backend.
///
/// [display] is a `*.display` string and is the only thing that reaches a
/// `Text`. There is no `double` on this class to be tempted into arithmetic
/// with, which is N-2 made structural rather than remembered.
class OrderTicketFigure extends Equatable {
  /// Creates a figure.
  const OrderTicketFigure({
    required this.name,
    required this.label,
    required this.display,
  });

  /// A stable name for this slot, so a changed figure can be marked without
  /// matching on its value.
  final String name;

  /// The caption beside it.
  final String label;

  /// The backend's own formatted string, rendered verbatim.
  final String display;

  @override
  List<Object?> get props => <Object?>[name, label, display];
}
