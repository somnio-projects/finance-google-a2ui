import 'package:finance_app/components/order_ticket/order_ticket_busy_dot.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:flutter/material.dart';

/// One editable option, offered as the control the backend declared.
///
/// **Every bound here comes from the payload and nowhere else.** A
/// `choice` offers exactly [OrderTicketField.choices]; a `text` declares
/// [OrderTicketField.pattern] as its accepted form. The client adds no
/// stricter rule beside the server's (N-8) and **clamps nothing** — a value
/// the backend will reject is sent, rejected, and the rejection is shown,
/// because the 422 is the authority on what is acceptable (spec 0006 AC-6).
///
/// The label is [OrderTicketField.label], server-written, and it is also the
/// control's screen-reader label — an editable field nobody can hear the name
/// of is not done (AC-12).
class OrderTicketFieldControl extends StatelessWidget {
  /// Creates the control.
  const OrderTicketFieldControl({
    required this.field,
    required this.onChanged,
    required this.isBusy,
    super.key,
  });

  /// The option to offer.
  final OrderTicketField field;

  /// Called with the option name and the new value; null disables it.
  final void Function(String option, String value)? onChanged;

  /// Whether this option's re-request is in flight.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return switch (field.control) {
      OrderTicketControl.choice => _ChoiceControl(
        field: field,
        enabled: enabled,
        isBusy: isBusy,
        onChanged: onChanged,
      ),
      OrderTicketControl.text => _TextControl(
        field: field,
        enabled: enabled,
        isBusy: isBusy,
        onChanged: onChanged,
      ),
    };
  }
}

/// A closed list, offering exactly `inputs[].choices`.
class _ChoiceControl extends StatelessWidget {
  const _ChoiceControl({
    required this.field,
    required this.enabled,
    required this.isBusy,
    required this.onChanged,
  });

  final OrderTicketField field;
  final bool enabled;
  final bool isBusy;
  final void Function(String option, String value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Semantics(
      label: field.label,
      value: field.value,
      enabled: enabled,
      child: DropdownButtonFormField<String>(
        initialValue: field.value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: isBusy ? const OrderTicketBusyDot() : null,
        ),
        items: <DropdownMenuItem<String>>[
          for (final choice in field.choices)
            DropdownMenuItem<String>(value: choice, child: Text(choice)),
        ],
        onChanged: enabled
            ? (value) {
                if (value != null) change!(field.option, value);
              }
            : null,
      ),
    );
  }
}

/// Free text, bounded by the server's `pattern` and by nothing else.
class _TextControl extends StatelessWidget {
  const _TextControl({
    required this.field,
    required this.enabled,
    required this.isBusy,
    required this.onChanged,
  });

  final OrderTicketField field;
  final bool enabled;
  final bool isBusy;
  final void Function(String option, String value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Semantics(
      label: field.label,
      value: field.value,
      textField: true,
      enabled: enabled,
      child: TextFormField(
        key: ValueKey<String>('${field.option}:${field.value}'),
        initialValue: field.value,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: field.label,
          // `hint` is the server's sentence for the reader; `pattern` is the
          // machine's copy of the same fact and is deliberately NOT drawn.
          // This used to render `pattern`, which put
          // `^[0-9]{1,9}(\.[0-9]{1,8})?$` under a form field — accurate, and
          // not what a person reads. The client cannot translate the one into
          // the other either: N-5 bans interpreting a server-supplied string,
          // so the sentence is written where the bound is (spec 0026).
          helperText: field.hint,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: isBusy ? const OrderTicketBusyDot() : null,
        ),
        onFieldSubmitted: enabled
            ? (value) => change!(field.option, value)
            : null,
      ),
    );
  }
}
