import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/order_ticket/order_ticket_header.dart';
import 'package:finance_app/components/order_ticket/order_ticket_impact.dart';
import 'package:finance_app/components/order_ticket/order_ticket_inputs.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:finance_app/components/order_ticket/order_ticket_notice.dart';
import 'package:flutter/material.dart';

/// Renders `order.ticket.v1` as the design's card.
///
/// The chrome matches the catalog artboard: a 16 px radius and the same
/// hairline the waterfall card uses, so the two sit together in a list.
///
/// **Interactivity is the host's, not this widget's.** [onOptionChanged] is
/// the whole seam: a host that can re-request the view supplies it, and one
/// that cannot leaves it null, in which case the ticket renders read-only
/// rather than offering a control it cannot honour (spec 0006 AC-10). This is
/// the shape `AttributionWaterfallCard` already uses for `onSegmentTap`.
///
/// Nothing here computes. [changedFigures] is a set of figure *names* decided
/// by comparing display strings upstream; this widget only decides how a
/// marked figure looks.
class OrderTicketCard extends StatelessWidget {
  /// Creates the card.
  const OrderTicketCard({
    required this.data,
    this.onOptionChanged,
    this.pendingOption,
    this.rejection,
    this.changedFigures = const <String>{},
    super.key,
  });

  /// The card's corner radius, measured from the design: 16 px.
  static const double radius = 16;

  /// The card's padding, measured from the design: `16px 18px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );

  /// Below this width the figures and controls stack instead of sharing a
  /// row. Material's compact/medium boundary; the design is drawn at 1024.
  static const double wideBreakpoint = 600;

  /// What to render.
  final OrderTicketData data;

  /// Called with an option name and its new value when the reader edits a
  /// control. `null` makes the ticket read-only.
  final void Function(String option, String value)? onOptionChanged;

  /// The option whose re-request is in flight, if any — controls are marked
  /// busy while it is, and the previous figures stay on screen (AC-8).
  final String? pendingOption;

  /// The backend's own `detail` for a rejected edit, or a transport message.
  /// Shown as a notice; the edited value is **not** reverted (AC-5).
  final String? rejection;

  /// Names of the figures whose display string changed in the last render.
  final Set<String> changedFigures;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              OrderTicketHeader(data: data),
              const SizedBox(height: 14),
              OrderTicketImpact(
                figures: data.figures,
                changedFigures: changedFigures,
                isWide: constraints.maxWidth >= wideBreakpoint,
              ),
              const SizedBox(height: 14),
              OrderTicketInputs(
                fields: data.fields,
                onChanged: onOptionChanged,
                pendingOption: pendingOption,
                isWide: constraints.maxWidth >= wideBreakpoint,
              ),
              if (rejection case final String message) ...<Widget>[
                const SizedBox(height: 12),
                OrderTicketNotice(message: message),
              ],
              const SizedBox(height: 12),
              // N-9: the disclosure is a compliance statement and renders
              // verbatim, in every state including the rejected one.
              Text(
                data.disclosure,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.mutedLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
