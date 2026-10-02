import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:finance_app/features/order_ticket_v2/view/order_ticket_v2_view.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The interactive multi-leg ticket.
///
/// A page, and the only kind of file allowed to resolve a repository from the
/// tree, because it builds the bloc that needs one (`layering_test.dart`).
///
/// **The bloc is `order.ticket.v1`'s, reused.** `OrderTicketBloc` owns an
/// options map and the single-view round trip that re-renders it, and it
/// takes the view id by injection precisely so a second ticket needs no
/// second bloc (spec frontend/0013 OD-4). Its own route, for the reason v1 has
/// one: `legs` is not an option any other view declares, and the read
/// endpoint applies one flat option set to every view in a request (N-7).
class OrderTicketV2Page extends StatelessWidget {
  /// Creates the page.
  const OrderTicketV2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderTicketBloc>(
      // The view id comes from the component that serves it (N-6).
      create: (context) => OrderTicketBloc(
        viewsRepository: context.read<ViewsRepository>(),
        viewId: OrderTicketV2View.component.viewId,
      )..add(const OrderTicketRequested()),
      child: const OrderTicketV2View(),
    );
  }
}
