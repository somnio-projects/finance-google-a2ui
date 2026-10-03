import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_card.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_component.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_notice.dart';
import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:finance_app/features/order_ticket_v2/view/order_ticket_v2_page.dart';
import 'package:finance_app/features/order_ticket_v2/view/order_ticket_v2_view.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../components/order_ticket_v2/order_ticket_v2_harness.dart';
import '../../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

/// The stepper round trip, end to end through the real page.
void main() {
  group('stepping a leg', () {
    late MockViewsRepository repository;

    setUp(() {
      repository = MockViewsRepository();
      stubFetch(repository, Ok<RenderedViews>(ticketV2Envelope()));
    });

    Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
      const OrderTicketV2Page(),
      viewsRepository: repository,
      surfaceSize: const Size(800, 1600),
    );

    Future<void> settleDebounce(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(OrderTicketBloc.defaultDebounce * 2);
      await tester.pumpAndSettle();
    }

    testWidgets('a real + tap sends the backend-written legs, unchanged', (
      tester,
    ) async {
      // AC-2 through the actual seam: no event is added by hand. The reader
      // taps `+`, the card hands over `increment`, the bloc debounces and the
      // repository is asked for the same view with `legs` set to that string.
      await pumpPage(tester);
      await tester.pumpAndSettle();
      final line = readTicketV2(ticketV2Example()).lines.first;

      await tester.tap(plus(line));
      await settleDebounce(tester);

      final captured = verify(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(
        captured.last,
        equals(<String, String>{
          OrderTicketV2Component.legsOption: line.increment!,
        }),
      );
    });

    testWidgets('marks the figures the backend changed after a step', (
      tester,
    ) async {
      // AC-5 end to end: the mark follows the strings the backend sent.
      await pumpPage(tester);
      await tester.pumpAndSettle();
      final line = readTicketV2(ticketV2Example()).lines.first;

      stubFetch(
        repository,
        Ok<RenderedViews>(ticketV2Envelope(example: ticketV2ExampleStepped())),
      );
      await tester.tap(plus(line));
      await settleDebounce(tester);

      final card = tester.widget<OrderTicketV2Card>(
        find.byType(OrderTicketV2Card),
      );
      expect(card.changed, contains('${line.key}.quantity'));
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('holds the steppers while the re-request is in flight', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();
      final line = readTicketV2(ticketV2Example()).lines.first;

      await tester.tap(plus(line));
      await tester.pump();
      await tester.pump();

      final card = tester.widget<OrderTicketV2Card>(
        find.byType(OrderTicketV2Card),
      );
      expect(card.isBusy, isTrue);
      expect(find.text(line.notionalDisplay), findsOneWidget);
      await settleDebounce(tester);
    });

    testWidgets('surfaces a refused step over the ticket already shown', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();
      final line = readTicketV2(ticketV2Example()).lines.first;

      stubFetch(repository, Err<RenderedViews>(rejection(detail: 'no')));
      await tester.tap(plus(line));
      await settleDebounce(tester);

      expect(find.byType(OrderTicketV2Notice), findsOneWidget);
      expect(find.text('no'), findsOneWidget);
      expect(find.byType(OrderTicketV2Card), findsOneWidget);
    });

    testWidgets('marks nothing when the superseded payload cannot be read', (
      tester,
    ) async {
      stubFetch(
        repository,
        Ok<RenderedViews>(
          ticketV2Envelope(example: ticketV2ExampleWithout('impact')),
        ),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();

      stubFetch(repository, Ok<RenderedViews>(ticketV2Envelope()));
      tester
          .element(find.byType(OrderTicketV2View))
          .read<OrderTicketBloc>()
          .add(const OrderTicketOptionChanged(option: 'legs', value: 'BTC:1'));
      await settleDebounce(tester);

      final card = tester.widget<OrderTicketV2Card>(
        find.byType(OrderTicketV2Card),
      );
      expect(card.changed, isEmpty);
    });
  });
}
