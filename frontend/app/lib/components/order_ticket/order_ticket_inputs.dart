import 'package:finance_app/components/order_ticket/order_ticket_field_control.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:flutter/material.dart';

/// The ticket's editable options, laid out.
///
/// **The set is not chosen here.** It is whatever `inputs[]` declared, in the
/// order the backend published it (N-10), so a bound added, removed or
/// renamed on the backend arrives without this file changing.
///
/// [onChanged] null means no host can honour an edit, so the controls render
/// disabled rather than pretending (spec 0006 AC-10).
class OrderTicketInputs extends StatelessWidget {
  /// Creates the input row.
  const OrderTicketInputs({
    required this.fields,
    required this.onChanged,
    required this.pendingOption,
    required this.isWide,
    super.key,
  });

  /// The editable options, in arrival order.
  final List<OrderTicketField> fields;

  /// Called with the option name and its new value; null disables every
  /// control.
  final void Function(String option, String value)? onChanged;

  /// The option whose re-request is in flight, if any.
  final String? pendingOption;

  /// Whether there is room to lay the controls out side by side.
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      for (final field in fields)
        OrderTicketFieldControl(
          field: field,
          onChanged: onChanged,
          isBusy: pendingOption == field.option,
        ),
    ];
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final control in controls)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: control,
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final control in controls)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: control),
      ],
    );
  }
}
