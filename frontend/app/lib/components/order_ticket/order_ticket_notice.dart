import 'package:finance_app/charts/chart_palette.dart';
import 'package:flutter/material.dart';

/// The design's validation banner — why the last edit did not take.
///
/// The design draws it for "Exceeds available cash"; here it carries whatever
/// the **backend** said, which for a rejected option is its RFC 9457 `detail`
/// and for an unreachable backend is this app's own wording. Never a stack
/// trace, never a library message (ADR-L §4).
///
/// It is a notice, not a revert. The control keeps the value the reader
/// typed, so they can see what was rejected and correct it (spec 0006 AC-5).
class OrderTicketNotice extends StatelessWidget {
  /// Creates the notice.
  const OrderTicketNotice({required this.message, super.key});

  /// The message, rendered verbatim.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.barLoss.withValues(alpha: 0.10),
          border: Border.all(color: palette.barLoss.withValues(alpha: 0.40)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 18,
                color: palette.barLoss,
                semanticLabel: 'Rejected',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.barLoss,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
