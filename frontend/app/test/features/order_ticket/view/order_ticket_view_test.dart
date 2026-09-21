import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_app/features/order_ticket/view/order_ticket_page.dart';
import 'package:finance_app/features/order_ticket/view/order_ticket_view.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../components/order_ticket/order_ticket_harness.dart';
import '../../../helpers/pump_app.dart';
import '../bloc/order_ticket_bloc_harness.dart';

/// What the surface renders in each state. The edit round trip is in
/// `order_ticket_edit_test.dart`.
void main() {
  group(OrderTicketView, () {
    late MockViewsRepository repository;

    setUp(() => repository = MockViewsRepository());

    Future<void> pumpPage(WidgetTester tester) =>
        tester.pumpApp(const OrderTicketPage(), viewsRepository: repository);

    testWidgets('renders the ticket once the first payload arrives', (
      tester,
    ) async {
      stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.byType(OrderTicketCard), findsOneWidget);
      expect(
        find.text(orderTicketExample()['disclosure']! as String),
        findsOneWidget,
      );
    });

    testWidgets('shows a spinner before anything has arrived', (tester) async {
      stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
      await pumpPage(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shows the failure when the first request never lands', (
      tester,
    ) async {
      // AC-7: there is nothing to keep on screen, so the message is all
      // there is — and it is the backend's own, never a stack trace.
      stubFetch(
        repository,
        const Err<RenderedViews>(TransportFailure('the server is down')),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.text('the server is down'), findsOneWidget);
      expect(find.byType(OrderTicketCard), findsNothing);
    });

    testWidgets('requests the ticket as soon as the page is built', (
      tester,
    ) async {
      stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(find.byType(OrderTicketView), findsOneWidget);
      expect(find.byType(OrderTicketCard), findsOneWidget);
    });

    testWidgets('a real edit on the real control reaches the repository', (
      tester,
    ) async {
      // AC-1 and AC-3 through the actual seam: no event is added by hand
      // here. The reader picks a value, the card's callback fires, the bloc
      // debounces and the repository is asked for the same view with that
      // option — which is the whole claim of this ticket.
      stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      // The option and the value both come from the contract, so a rename
      // on the backend moves this test with it.
      final field = readOrderTicket(orderTicketExample()).fields.first;
      final other = field.choices.firstWhere((c) => c != field.value);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(other).last);
      await tester.pumpAndSettle();

      final captured = verify(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: captureAny(named: 'options'),
        ),
      ).captured.cast<Map<String, String>>();
      expect(captured.last, equals(<String, String>{field.option: other}));
    });

    testWidgets('shows a contract violation instead of throwing', (
      tester,
    ) async {
      // This view builds the card itself rather than through
      // `ComponentHost`, so it owes the reader what the host provides: the
      // violation is shown and names the path (N-3). Without this it was a
      // red screen — found by a test, not by review.
      stubFetch(
        repository,
        Ok<RenderedViews>(
          RenderedViews.fromJson(<String, dynamic>{
            'as_of': '2026-09-21T00:00:00Z',
            'portfolio_id': 'current',
            'views': <String, dynamic>{
              'order.ticket.v1': orderTicketExampleWithout('notional'),
            },
          }),
        ),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('notional.label'), findsOneWidget);
      expect(find.byType(OrderTicketCard), findsNothing);
    });
  });
}
