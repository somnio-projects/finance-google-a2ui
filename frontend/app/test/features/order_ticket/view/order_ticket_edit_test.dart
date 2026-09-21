import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_app/components/order_ticket/order_ticket_impact.dart';
import 'package:finance_app/components/order_ticket/order_ticket_notice.dart';
import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:finance_app/features/order_ticket/view/order_ticket_page.dart';
import 'package:finance_app/features/order_ticket/view/order_ticket_view.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../components/order_ticket/order_ticket_harness.dart';
import '../../../helpers/pump_app.dart';
import '../bloc/order_ticket_bloc_harness.dart';

/// The edit round trip, end to end through the real page.
///
/// Split from `order_ticket_view_test.dart`, which covers what the surface
/// renders in each state; this covers what happens when the reader changes
/// something. Same subject, split for the 150-line budget.
void main() {
  group('editing the order ticket', () {
    late MockViewsRepository repository;

    setUp(() {
      repository = MockViewsRepository();
      stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
    });

    Future<void> pumpPage(WidgetTester tester) =>
        tester.pumpApp(const OrderTicketPage(), viewsRepository: repository);

    void edit(
      WidgetTester tester, {
      required String option,
      String value = '2',
    }) => tester
        .element(find.byType(OrderTicketView))
        .read<OrderTicketBloc>()
        .add(OrderTicketOptionChanged(option: option, value: value));

    testWidgets('keeps the previous figures while a re-request is in flight', (
      tester,
    ) async {
      // AC-8: the ticket stays readable mid-edit.
      await pumpPage(tester);
      await tester.pumpAndSettle();
      final notional =
          orderTicketExample()['notional']! as Map<String, dynamic>;
      final amount = notional['amount']! as Map<String, dynamic>;

      edit(tester, option: 'size');
      // Two frames: one to deliver the event and emit, one to rebuild. The
      // debounce has not elapsed, so no request has gone out yet — which is
      // exactly the moment this test is about.
      await tester.pump();
      await tester.pump();

      expect(find.text(amount['display']! as String), findsWidgets);
      final card = tester.widget<OrderTicketCard>(find.byType(OrderTicketCard));
      expect(card.pendingOption, 'size');
      await tester.pumpAndSettle();
    });

    testWidgets('marks the figures the backend changed', (tester) async {
      // AC-9 end to end: the mark follows the string the backend sent, and
      // the new figure on screen is that string verbatim.
      await pumpPage(tester);
      await tester.pumpAndSettle();

      stubFetch(
        repository,
        Ok<RenderedViews>(ticketEnvelope(notionalDisplay: r'$99,000.00')),
      );
      edit(tester, option: 'size');
      await tester.pumpAndSettle();

      final card = tester.widget<OrderTicketCard>(find.byType(OrderTicketCard));
      expect(card.changedFigures, equals(<String>{'notional'}));
      expect(find.text(r'$99,000.00'), findsWidgets);
      final impact = tester.widget<OrderTicketImpact>(
        find.byType(OrderTicketImpact),
      );
      expect(impact.changedFigures, contains('notional'));
    });

    testWidgets('surfaces a rejected edit over the ticket already shown', (
      tester,
    ) async {
      // AC-5: a notice, not a revert, and the ticket stays on screen.
      await pumpPage(tester);
      await tester.pumpAndSettle();

      stubFetch(repository, Err<RenderedViews>(rejection()));
      edit(tester, option: 'size', value: 'x');
      await tester.pumpAndSettle();

      expect(find.byType(OrderTicketNotice), findsOneWidget);
      expect(find.text('size must match the pattern'), findsOneWidget);
      expect(find.byType(OrderTicketCard), findsOneWidget);
    });

    testWidgets('marks nothing when the superseded payload cannot be read', (
      tester,
    ) async {
      // The previous payload is bookkeeping for the mark. A contract
      // violation in it must not take down a ticket that is rendering the
      // current payload perfectly well — it degrades to "mark nothing".
      stubFetch(
        repository,
        Ok<RenderedViews>(
          RenderedViews.fromJson(<String, dynamic>{
            'as_of': '2026-09-21T00:00:00Z',
            'portfolio_id': 'current',
            'views': <String, dynamic>{
              orderTicketViewId(): orderTicketExampleWithout('notional'),
            },
          }),
        ),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();

      stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
      edit(tester, option: 'size');
      // The first render showed the violation rather than a card, so there
      // is no animation for `pumpAndSettle` to wait on — the debounce has to
      // be advanced explicitly.
      await tester.pump();
      await tester.pump(OrderTicketBloc.defaultDebounce * 2);
      await tester.pumpAndSettle();

      final card = tester.widget<OrderTicketCard>(find.byType(OrderTicketCard));
      expect(card.changedFigures, isEmpty);
    });
  });
}
