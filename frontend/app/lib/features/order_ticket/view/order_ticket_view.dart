import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_app/components/order_ticket/order_ticket_changes.dart';
import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:finance_app/theme/app_spacing.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Renders whatever [OrderTicketBloc] currently holds.
///
/// This is the host that makes the ticket interactive: it builds the card
/// itself so it can attach [OrderTicketCard.onOptionChanged], rather than
/// going through `ComponentHost`, which has no slot for a callback. The
/// component is still the single owner of the payload's shape — the binding
/// comes from [OrderTicketComponent.read] and nothing here reads a path.
class OrderTicketView extends StatelessWidget {
  /// Creates the view.
  const OrderTicketView({super.key});

  /// The component whose binding this view renders.
  static const OrderTicketComponent component = OrderTicketComponent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order ticket')),
      body: BlocBuilder<OrderTicketBloc, OrderTicketState>(
        builder: (context, state) {
          final payload = state.payload;
          // No payload yet: the first render is the only state with nothing
          // to show. Once one has arrived it stays on screen through every
          // later state, including a rejected edit (AC-7, AC-8).
          if (payload == null) {
            return switch (state.status) {
              OrderTicketStatus.rejected => _Failure(
                message: state.rejection ?? 'The request failed.',
              ),
              _ => const Center(child: CircularProgressIndicator()),
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
    final OrderTicketData data;
    try {
      data = OrderTicketView.component.read(payload);
    } on PayloadContractException catch (error) {
      // This view builds the card itself rather than going through
      // `ComponentHost`, because the host has no slot for the edit callback
      // — so it owes the reader the same thing the host does: a contract
      // violation is *shown*, naming the path, not thrown into a red screen
      // (ADR-L §4, N-3).
      return _Failure(message: error.failure.message);
    }
    final previous = state.previous;
    return ListView(
      padding: EdgeInsets.all(spacing.md),
      children: <Widget>[
        OrderTicketCard(
          data: data,
          pendingOption: state.pendingOption,
          rejection: state.rejection,
          changedFigures: changedFigures(_readOrNull(previous), data),
          onOptionChanged: (option, value) => context
              .read<OrderTicketBloc>()
              .add(OrderTicketOptionChanged(option: option, value: value)),
        ),
      ],
    );
  }

  /// Reads the superseded payload, tolerating one this build cannot bind.
  ///
  /// The previous payload is used only to decide what to *mark*. A contract
  /// violation in it must not take down a ticket that is rendering the
  /// current payload perfectly well, so it degrades to "mark nothing".
  OrderTicketData? _readOrNull(ViewPayload? previous) {
    if (previous == null) return null;
    try {
      return OrderTicketView.component.read(previous);
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
