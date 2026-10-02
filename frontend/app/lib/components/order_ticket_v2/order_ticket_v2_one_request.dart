import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:flutter/material.dart';

/// Lets one stepper or slider edit through, and no second one until it is
/// answered (GGU-149).
///
/// The host's `isBusy` already disables the controls while a re-render is in
/// flight, but only from the frame **after** it learns of the edit. A fast
/// double tap lands both presses before that frame, and each sends the value
/// the *old* payload carried — two requests for one step, answered out of
/// step with what the reader pressed. This latch closes that gap: the first
/// edit passes, every later one is dropped until a new payload arrives or the
/// host reports the request settled. Nothing here computes a value (N-2): the
/// edit sent is always one the payload wrote.
class OrderTicketV2OneRequest extends StatefulWidget {
  /// Guards [onLegsChanged] for the card that renders [data].
  const OrderTicketV2OneRequest({
    required this.data,
    required this.isBusy,
    required this.onLegsChanged,
    required this.builder,
    super.key,
  });

  /// The payload on screen; a different one means the last edit was answered.
  final OrderTicketV2Data data;

  /// Whether the host is re-rendering; its fall means the edit settled.
  final bool isBusy;

  /// Where an edit goes; null keeps every control read-only.
  final ValueChanged<String>? onLegsChanged;

  /// Builds the card with the guarded callback — null while one is in flight.
  final Widget Function(ValueChanged<String>? send) builder;

  @override
  State<OrderTicketV2OneRequest> createState() =>
      _OrderTicketV2OneRequestState();
}

class _OrderTicketV2OneRequestState extends State<OrderTicketV2OneRequest> {
  bool _inFlight = false;

  @override
  void didUpdateWidget(OrderTicketV2OneRequest oldWidget) {
    super.didUpdateWidget(oldWidget);
    final answered = widget.data != oldWidget.data;
    final settled = oldWidget.isBusy && !widget.isBusy;
    if (answered || settled) _inFlight = false;
  }

  @override
  Widget build(BuildContext context) {
    final send = widget.onLegsChanged;
    if (send == null || widget.isBusy || _inFlight) {
      return widget.builder(null);
    }
    return widget.builder((legs) {
      if (_inFlight) return;
      setState(() => _inFlight = true);
      send(legs);
    });
  }
}
