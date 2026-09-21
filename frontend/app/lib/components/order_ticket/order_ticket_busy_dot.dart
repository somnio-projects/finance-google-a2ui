import 'package:flutter/material.dart';

/// The in-flight marker: a control being re-rendered is busy, not broken.
class OrderTicketBusyDot extends StatelessWidget {
  /// Creates the marker.
  const OrderTicketBusyDot({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(12),
    child: SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}
