import 'package:finance_app/components/order_ticket/order_ticket_model.dart';

/// Which figures the last re-render changed.
///
/// The design marks the figures that moved after an edit, and this is how
/// that set is decided: by comparing the **display strings** the backend
/// sent, before and after. It is a string comparison and nothing else — no
/// subtraction, no threshold, no sign. The client is not allowed to know
/// whether a figure went up, and does not need to in order to mark it
/// (spec 0006 AC-9).
///
/// [previous] null means there is nothing to compare against — the first
/// render marks nothing, because everything on a first render is new and
/// marking all of it would say nothing.
Set<String> changedFigures(OrderTicketData? previous, OrderTicketData current) {
  if (previous == null) return const <String>{};
  final before = <String, String>{
    for (final figure in previous.figures) figure.name: figure.display,
  };
  return <String>{
    for (final figure in current.figures)
      // A figure the previous render did not carry is not "changed"; it is
      // new, and the contract makes every figure required, so this only
      // guards a payload that broke it.
      if (before.containsKey(figure.name) &&
          before[figure.name] != figure.display)
        figure.name,
  };
}
