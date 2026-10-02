import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:finance_app/features/order_ticket/view/order_ticket_view.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The interactive order-ticket surface.
///
/// A page, and the only kind of file allowed to resolve a repository from the
/// tree, because it is the file that builds the bloc that needs one
/// (`layering_test.dart::only a page resolves a repository from the widget
/// tree`).
///
/// It exists as a route of its own because the ticket's options must travel
/// **alone**: the read endpoint applies one flat option set to every view it
/// is asked for, so `side=sell` sent beside `holdings.allocation.v1` would
/// 422 the whole request (N-7, spec 0006 OD-5).
class OrderTicketPage extends StatelessWidget {
  /// Creates the page.
  const OrderTicketPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderTicketBloc>(
      // The view id comes from the component that serves it, so this file
      // declares no literal of its own (N-6).
      create: (context) => OrderTicketBloc(
        viewsRepository: context.read<ViewsRepository>(),
        viewId: OrderTicketView.component.viewId,
      )..add(const OrderTicketRequested()),
      child: const OrderTicketView(),
    );
  }
}
