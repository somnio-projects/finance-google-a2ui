import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_chrome.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_control_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// The ticket's buttons, drawn from `controls[]` — every word the backend's.
///
/// **This widget used to carry the copy.** `Review order` and `Save as draft`
/// were `static const` strings here: design's words compiled into the bundle,
/// unable to follow the `locale` option, which is N-9 with the sentence
/// pointing the wrong way. The backend serves them now (spec backend/0050),
/// with the enabled state and the reason beside each, and this widget spells
/// nothing.
///
/// It still draws every control **disabled**, and that is the payload's
/// statement rather than this widget's: `enabled` is a declared flag, false
/// on everything the ticket serves, because `effect: "recalculate"` is the
/// whole contract and the disclosure says nothing is ever sent, placed or
/// settled (spec backend/0018 OD-2). A button that looked live would be the
/// showcase's worst bug (spec frontend/0013 OD-3) — so when one does become
/// live, it becomes live *in the payload*, and this widget follows.
class OrderTicketV2Buttons extends StatelessWidget {
  /// Creates the buttons for [controls], in arrival order (N-10).
  const OrderTicketV2Buttons({required this.controls, super.key});

  /// The button's height, measured from the design.
  static const double height = 44;

  /// The gap between a button and whatever follows it.
  static const double gap = 8;

  /// What the ticket declared, rendered in the order it arrived.
  final List<OrderTicketV2Control> controls;

  @override
  Widget build(BuildContext context) {
    final chrome = OrderTicketV2Chrome.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final control in controls) ...<Widget>[
          _Control(control: control, chrome: chrome),
          if (control != controls.last) const SizedBox(height: gap),
        ],
      ],
    );
  }
}

/// One declared control, primary or secondary.
class _Control extends StatelessWidget {
  const _Control({required this.control, required this.chrome});

  final OrderTicketV2Control control;
  final OrderTicketV2Chrome chrome;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      control.label,
      style: control.isPrimary
          ? OrderTicketV2Text.button(chrome.buttonText)
          : OrderTicketV2Text.link(chrome.buttonText),
    );
    return Semantics(
      button: true,
      enabled: control.enabled,
      label: control.label,
      // The reason travels with the control, so what a screen reader hears is
      // the sentence the backend wrote rather than one composed here.
      hint: control.reason,
      excludeSemantics: true,
      child: control.isPrimary
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: chrome.buttonSurface,
                borderRadius: BorderRadius.circular(
                  OrderTicketV2Buttons.height / 2,
                ),
              ),
              child: SizedBox(
                height: OrderTicketV2Buttons.height,
                child: Center(child: label),
              ),
            )
          : Center(child: label),
    );
  }
}
