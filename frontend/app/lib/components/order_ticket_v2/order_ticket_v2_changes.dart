import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';

/// Which strings the last re-render changed.
///
/// The design highlights the values that moved after a stepper tap — the
/// stepped leg's amount, shares and weight, the other legs' weights, and the
/// panel's total, shares and cash — in indigo. This decides that set the
/// only way this client may: by comparing the **display strings** the backend
/// sent before and after. No subtraction, no threshold, no sign (spec
/// frontend/0006 AC-9, reused for 0013 AC-5).
///
/// Keys are slots, never values: a figure is its `name`, a leg's field is
/// `<key>.<field>`, a weight row is `shift.<key>`. [previous] null means a
/// first render, which marks nothing — everything is new then, and marking
/// all of it would say nothing.
Set<String> changedKeys(
  OrderTicketV2Data? previous,
  OrderTicketV2Data current,
) {
  if (previous == null) return const <String>{};
  final before = _strings(previous);
  final after = _strings(current);
  return <String>{
    for (final entry in after.entries)
      // A slot the previous render did not carry is new, not changed.
      if (before.containsKey(entry.key) && before[entry.key] != entry.value)
        entry.key,
  };
}

/// The keys [changedKeys] uses for one leg, so a widget asks for the same
/// slot the comparison wrote.
abstract final class LineSlots {
  /// The leg's amount.
  static String notional(String key) => '$key.notional';

  /// The leg's share count.
  static String quantity(String key) => '$key.quantity';

  /// The leg's share of the order.
  static String weight(String key) => '$key.weight';

  /// A `Portfolio weight` row's `after` figure.
  static String shift(String key) => 'shift.$key';
}

Map<String, String> _strings(OrderTicketV2Data data) => <String, String>{
  for (final figure in data.figures) figure.name: figure.display,
  for (final line in data.lines) ...<String, String>{
    LineSlots.notional(line.key): line.notionalDisplay,
    LineSlots.quantity(line.key): line.quantityDisplay,
    LineSlots.weight(line.key): line.weightDisplay,
  },
  for (final shift in data.shifts)
    LineSlots.shift(shift.key): shift.afterDisplay,
};

/// The legs whose share count moved — the design tints their whole card.
Set<String> steppedLegs(Set<String> changed, OrderTicketV2Data current) =>
    <String>{
      for (final line in current.lines)
        if (changed.contains(LineSlots.quantity(line.key))) line.key,
    };
