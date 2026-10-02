import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_stepper.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../components/order_ticket_v2/order_ticket_v2_harness.dart';

export '../../order_ticket/bloc/order_ticket_bloc_harness.dart'
    show MockViewsRepository, rejection, stubFetch, testDebounce;

/// An envelope carrying the multi-leg ticket, keyed by the **catalog's** view
/// id — so a bloc asking for the component's literal and a fixture keyed by
/// the contract cannot agree with themselves.
RenderedViews ticketV2Envelope({Map<String, dynamic>? example}) =>
    RenderedViews.fromJson(<String, dynamic>{
      'as_of': '2026-09-22T00:00:00Z',
      'portfolio_id': 'current',
      'views': <String, dynamic>{
        ticketV2ViewId(): example ?? ticketV2Example(),
      },
    });

/// The `+` of [line]'s stepper, found the way a screen reader names it.
Finder plus(OrderTicketV2Line line) =>
    find.bySemanticsLabel(OrderTicketV2Stepper.increaseLabel(line.symbol));
