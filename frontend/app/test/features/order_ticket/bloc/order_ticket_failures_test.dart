import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'order_ticket_bloc_harness.dart';

/// The paths that matter: a refused option, an unreachable backend, and a
/// response that does not carry the view it was asked for.
void main() {
  group('$OrderTicketBloc failures', () {
    late MockViewsRepository repository;

    setUp(() => repository = MockViewsRepository());

    blocTest<OrderTicketBloc, OrderTicketState>(
      'surfaces a rejected option and keeps the edited value',
      // AC-5 / ticket AC-4: a 422 is a message, never a silent revert. The
      // option stays in `options`, so the control still shows what the
      // reader typed and they can see what was refused.
      build: () {
        stubFetch(repository, Err<RenderedViews>(rejection()));
        return buildBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const OrderTicketOptionChanged(option: 'size', value: 'x'));
        await Future<void>.delayed(testDebounce * 3);
      },
      skip: 1,
      expect: () => <Matcher>[
        isA<OrderTicketState>()
            .having((s) => s.status, 'status', OrderTicketStatus.rejected)
            .having(
              (s) => s.rejection,
              'rejection',
              'size must match the pattern',
            )
            .having((s) => s.pendingOption, 'pendingOption', isNull)
            .having(
              (s) => s.options,
              'options keeps the edited value',
              <String, String>{'size': 'x'},
            ),
      ],
    );

    test(
      'a rejection carries the backend problem code, not just a message',
      () {
        // §4 of the testing rule: asserting only "it failed" passes when the
        // wrong thing failed.
        expect(rejection().code, equals('validation-error'));
        expect(rejection().problem.status, equals(422));
      },
    );

    blocTest<OrderTicketBloc, OrderTicketState>(
      'surfaces an unreachable backend',
      // AC-7.
      build: () {
        stubFetch(
          repository,
          const Err<RenderedViews>(
            TransportFailure('the server could not be reached'),
          ),
        );
        return buildBloc(repository);
      },
      act: (bloc) => bloc.add(const OrderTicketRequested()),
      skip: 1,
      expect: () => <Matcher>[
        isA<OrderTicketState>()
            .having((s) => s.status, 'status', OrderTicketStatus.rejected)
            .having(
              (s) => s.rejection,
              'rejection',
              'the server could not be reached',
            ),
      ],
    );

    blocTest<OrderTicketBloc, OrderTicketState>(
      'reports an envelope that does not carry the view it asked for',
      build: () {
        stubFetch(repository, Ok<RenderedViews>(emptyEnvelope()));
        return buildBloc(repository);
      },
      act: (bloc) => bloc.add(const OrderTicketRequested()),
      skip: 1,
      expect: () => <Matcher>[
        isA<OrderTicketState>()
            .having((s) => s.status, 'status', OrderTicketStatus.rejected)
            .having((s) => s.rejection, 'rejection', isNotNull)
            .having((s) => s.payload, 'payload', isNull),
      ],
    );

    blocTest<OrderTicketBloc, OrderTicketState>(
      'keeps the previous payload when a later edit is refused',
      // AC-7 again: the ticket already on screen stays there.
      build: () {
        stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
        return buildBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const OrderTicketRequested());
        await Future<void>.delayed(testDebounce);
        stubFetch(repository, Err<RenderedViews>(rejection()));
        bloc.add(const OrderTicketOptionChanged(option: 'size', value: 'x'));
        await Future<void>.delayed(testDebounce * 3);
      },
      verify: (bloc) {
        expect(bloc.state.status, OrderTicketStatus.rejected);
        expect(bloc.state.payload, isNotNull);
      },
    );

    blocTest<OrderTicketBloc, OrderTicketState>(
      'carries the superseded payload so the view can mark what changed',
      // AC-9's input: `previous` is bookkeeping for the mark and is never
      // rendered.
      build: () {
        stubFetch(repository, Ok<RenderedViews>(ticketEnvelope()));
        return buildBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const OrderTicketRequested());
        await Future<void>.delayed(testDebounce);
        stubFetch(
          repository,
          Ok<RenderedViews>(ticketEnvelope(notionalDisplay: r'$99,000.00')),
        );
        bloc.add(const OrderTicketOptionChanged(option: 'size', value: '2'));
        await Future<void>.delayed(testDebounce * 3);
      },
      verify: (bloc) {
        expect(bloc.state.previous, isNotNull);
        expect(bloc.state.payload, isNot(equals(bloc.state.previous)));
      },
    );
  });
}
