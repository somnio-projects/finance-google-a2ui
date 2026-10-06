import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// The quantity between `−` and `+`, typeable (spec backend/0054).
///
/// **It parses nothing.** The backend serves [entry] — the whole `legs`
/// option value with this leg's units left as [placeholder] — and a submit
/// sends that value with what was typed put in the hole, verbatim (N-2). The
/// options model judges the result like any other `legs` value, so a typo is
/// the backend's 422, not a rule written here — and no input filter either,
/// because a client rule beside a server bound is N-8.
///
/// The field shows [display] — the backend's string — and goes back to it
/// whenever a new render arrives, so it never holds a figure the payload
/// does not.
class OrderTicketV2QuantityField extends StatefulWidget {
  /// Creates the field.
  const OrderTicketV2QuantityField({
    required this.display,
    required this.entry,
    required this.color,
    required this.onLegsChanged,
    super.key,
  });

  /// The hole in [entry], as the backend writes it (spec backend/0054).
  static const String placeholder = '{units}';

  /// What the field shows: `quantity.display`.
  final String display;

  /// The `legs` template, or null when this payload carries none.
  final String? entry;

  /// The text colour the stepper chose (changed or at rest).
  final Color color;

  /// Receives the `legs` value to send; null makes the field read-only.
  final ValueChanged<String>? onLegsChanged;

  @override
  State<OrderTicketV2QuantityField> createState() => _QuantityFieldState();
}

class _QuantityFieldState extends State<OrderTicketV2QuantityField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.display,
  );

  @override
  void didUpdateWidget(OrderTicketV2QuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.display != widget.display) _controller.text = widget.display;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String typed) {
    final send = widget.onLegsChanged;
    final entry = widget.entry;
    final units = typed.trim();
    if (send == null || entry == null || units.isEmpty) return;
    if (units == widget.display) return;
    send(entry.replaceFirst(OrderTicketV2QuantityField.placeholder, units));
  }

  @override
  Widget build(BuildContext context) {
    final editable = widget.onLegsChanged != null && widget.entry != null;
    return IntrinsicWidth(
      child: TextField(
        controller: _controller,
        readOnly: !editable,
        textAlign: TextAlign.center,
        style: OrderTicketV2Text.quantity(widget.color),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        ),
        onSubmitted: _submit,
        onTapOutside: (_) {
          if (FocusManager.instance.primaryFocus?.hasFocus ?? false) {
            _submit(_controller.text);
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
      ),
    );
  }
}
