import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_card.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_changes.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_component.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:finance_app/theme/app_spacing.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Renders whatever [OrderTicketBloc] holds for `order.ticket.v2`.
///
/// The host that makes the ticket interactive: it builds the card itself so
/// it can attach [OrderTicketV2Card.onLegsChanged], and forwards the string a
/// stepper hands it as the `legs` option, unchanged — the bloc debounces and
/// re-requests exactly as it does for v1 (spec frontend/0006 AC-1..AC-9).
/// The component stays the single owner of the payload's shape: the binding
/// is [OrderTicketV2Component.read] and nothing here reads a path.
class OrderTicketV2View extends StatelessWidget {
  /// Creates the view.
  const OrderTicketV2View({super.key});

  /// The component whose binding this view renders.
  static const OrderTicketV2Component component = OrderTicketV2Component();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Draft order')),
      body: BlocBuilder<OrderTicketBloc, OrderTicketState>(
        builder: (context, state) {
          final payload = state.payload;
          // Before the first payload there is nothing to keep on screen; once
          // one has arrived it stays through every later state, including a
          // refused edit.
          if (payload == null) {
            return switch (state.status) {
              OrderTicketStatus.rejected => _Failure(
                message: state.rejection ?? 'The request failed.',
              ),
              // The component's own `Loading · skeleton`, reached through
              // the component this view already holds — the same seam
              // `ComponentSkeletonHost` uses (spec 0015 OD-3, 0020 AC-7).
              _ => Padding(
                padding: EdgeInsets.all(AppSpacing.of(context).md),
                child: OrderTicketV2View.component.skeleton(context),
              ),
            };
          }
          return _Ticket(state: state, payload: payload);
        },
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.state, required this.payload});

  final OrderTicketState state;
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final spacing = AppSpacing.of(context);
    final OrderTicketV2Data data;
    try {
      data = OrderTicketV2View.component.read(payload);
    } on PayloadContractException catch (error) {
      // Built here rather than through `ComponentHost`, so this view owes the
      // reader what the host does: a violation shown, naming the path (N-3).
      return _Failure(message: error.failure.message);
    }
    return ListView(
      padding: EdgeInsets.all(spacing.md),
      children: <Widget>[
        OrderTicketV2Card(
          data: data,
          isBusy: state.status == OrderTicketStatus.updating,
          rejection: state.rejection,
          changed: changedKeys(_readOrNull(state.previous), data),
          onLegsChanged: (legs) => context.read<OrderTicketBloc>().add(
            OrderTicketOptionChanged(
              option: OrderTicketV2Component.legsOption,
              value: legs,
            ),
          ),
        ),
      ],
    );
  }

  /// Reads the superseded payload, tolerating one this build cannot bind:
  /// it is bookkeeping for the mark, and degrades to "mark nothing".
  OrderTicketV2Data? _readOrNull(ViewPayload? previous) {
    if (previous == null) return null;
    try {
      return OrderTicketV2View.component.read(previous);
    } on PayloadContractException {
      return null;
    }
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppSpacing.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
            SizedBox(height: spacing.sm),
            // The backend's own safe message, verbatim.
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
