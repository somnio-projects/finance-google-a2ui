import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_chrome.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// `Review order` and `Save as draft`, as honest placeholders.
///
/// The design draws both; the contract declares no action for either —
/// `effect: "recalculate"` is the whole of what this ticket does, and the
/// disclosure under the card says nothing is ever sent, placed or settled
/// (spec backend/0018 OD-2). So both are drawn **disabled**, in the colours
/// the catalog page gives a button that cannot be pressed, and each says so
/// to a screen reader. When `onSubmit` arrives as a declared surface action
/// (spec backend/0022), the host enables them; until then a button that
/// looked live would be the showcase's worst bug (spec frontend/0013 OD-3).
class OrderTicketV2Buttons extends StatelessWidget {
  /// Creates the buttons.
  const OrderTicketV2Buttons({super.key});

  /// The primary button's label, as the design writes it.
  static const String reviewLabel = 'Review order';

  /// The secondary link's label, as the design writes it.
  static const String saveLabel = 'Save as draft';

  /// What a screen reader hears instead of a promise.
  static const String unavailable = 'Not available in this showcase';

  /// The button's height, measured from the design.
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final chrome = OrderTicketV2Chrome.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          button: true,
          enabled: false,
          label: reviewLabel,
          hint: unavailable,
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: chrome.buttonSurface,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: SizedBox(
              height: height,
              child: Center(
                child: Text(
                  reviewLabel,
                  style: OrderTicketV2Text.button(chrome.buttonText),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          enabled: false,
          label: saveLabel,
          hint: unavailable,
          excludeSemantics: true,
          child: Center(
            child: Text(
              saveLabel,
              style: OrderTicketV2Text.link(chrome.buttonText),
            ),
          ),
        ),
      ],
    );
  }
}
