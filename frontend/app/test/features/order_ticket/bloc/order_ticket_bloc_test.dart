import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../components/order_ticket/order_ticket_harness.dart';
import 'order_ticket_bloc_harness.dart';

void main() {
  group(OrderTicketBloc, () {
    late MockViewsRepository repository;

    setUp(() {
      repository = MockViewsRepository();
      stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
    });

    blocTest<OrderTicketBloc, OrderTicketState>(
      'asks for exactly one view id, so its options travel alone',
      // AC-1 and OD-5. The read endpoint applies one flat option set to
      // every view in a request, so `side` beside another view would 422 the
      // whole thing.
      build: () => buildBloc(repository),
      act: (bloc) => bloc.add(const OrderTicketRequested()),
      verify: (_) {
        final captured = verify(
          () => repository.fetchPortfolioViews(
            portfolioId: 'current',
            views: captureAny(named: 'views'),
            options: any(named: 'options'),
          ),
        ).captured;
        // The id asked for is the one the catalog publishes, not a constant
        // this test and the bloc happen to share.
        expect(captured.single, equals(<String>[orderTicketViewId()]));
      },
      expect: () => <Matcher>[
        isA<OrderTicketState>().having(
          (s) => s.status,
          'status',
          OrderTicketStatus.loading,
        ),
        isA<OrderTicketState>()
            .having((s) => s.status, 'status', OrderTicketStatus.ready)
            .having((s) => s.payload, 'payload', isNotNull),
      ],
    );

    blocTest<OrderTicketBloc, OrderTicketState>(
      'sends the changed option with the ones already in effect',
      // AC-1: nothing else is sent, and the key is the payload's own.
      build: () => buildBloc(repository),
      act: (bloc) async {
        bloc.add(const OrderTicketRequested());
        await Future<void>.delayed(testDebounce);
        bloc.add(const OrderTicketOptionChanged(option: 'side', value: 'sell'));
        await Future<void>.delayed(testDebounce * 3);
        bloc.add(const OrderTicketOptionChanged(option: 'size', value: '2'));
        await Future<void>.delayed(testDebounce * 3);
      },
      verify: (_) {
        final captured = verify(
          () => repository.fetchPortfolioViews(
            portfolioId: any(named: 'portfolioId'),
            views: any(named: 'views'),
            options: captureAny(named: 'options'),
          ),
        ).captured.cast<Map<String, String>>();
        expect(captured.first, isEmpty);
        expect(captured[1], equals(<String, String>{'side': 'sell'}));
        expect(
          captured.last,
          equals(<String, String>{'side': 'sell', 'size': '2'}),
        );
      },
    );

    blocTest<OrderTicketBloc, OrderTicketState>(
      'debounces a burst of edits into one request',
      // AC-4 / ticket AC-3: a slider must not issue a request per frame.
      build: () => buildBloc(repository),
      act: (bloc) async {
        for (final value in <String>['1', '2', '3', '4']) {
          bloc.add(OrderTicketOptionChanged(option: 'size', value: value));
        }
        await Future<void>.delayed(testDebounce * 4);
      },
      verify: (_) {
        final captured = verify(
          () => repository.fetchPortfolioViews(
            portfolioId: any(named: 'portfolioId'),
            views: any(named: 'views'),
            options: captureAny(named: 'options'),
          ),
        ).captured.cast<Map<String, String>>();
        expect(captured, hasLength(1));
        expect(captured.single, equals(<String, String>{'size': '4'}));
      },
    );

    blocTest<OrderTicketBloc, OrderTicketState>(
      'marks the edited option pending while its request is in flight',
      // AC-8.
      build: () => buildBloc(repository),
      act: (bloc) => bloc.add(
        const OrderTicketOptionChanged(option: 'side', value: 'sell'),
      ),
      expect: () => <Matcher>[
        isA<OrderTicketState>()
            .having((s) => s.status, 'status', OrderTicketStatus.updating)
            .having((s) => s.pendingOption, 'pendingOption', 'side')
            .having((s) => s.rejection, 'rejection', isNull),
      ],
    );
  });
}
