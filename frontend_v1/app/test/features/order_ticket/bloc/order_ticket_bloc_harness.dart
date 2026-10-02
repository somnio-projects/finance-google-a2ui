import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../components/order_ticket/order_ticket_harness.dart';

/// A stand-in for the repository the bloc calls.
class MockViewsRepository extends Mock implements ViewsRepository;

/// The debounce a test drives, short enough to keep the suite fast and long
/// enough that a burst genuinely coalesces inside it.
const Duration testDebounce = Duration(milliseconds: 20);

/// An envelope carrying the order ticket, optionally with a changed notional.
RenderedViews ticketEnvelope({String? notionalDisplay}) =>
    RenderedViews.fromJson(<String, dynamic>{
      'as_of': '2026-09-21T00:00:00Z',
      'portfolio_id': 'current',
      'views': <String, dynamic>{
        orderTicketViewId(): notionalDisplay == null
            ? orderTicketExample()
            : orderTicketExampleWithNotional(notionalDisplay),
      },
    });

/// An envelope that answers with a different view than the one asked for.
RenderedViews emptyEnvelope() => RenderedViews.fromJson(const <String, dynamic>{
  'as_of': '2026-09-21T00:00:00Z',
  'portfolio_id': 'current',
  'views': <String, dynamic>{},
});

/// The backend's own 422 for an option it refuses.
///
/// Built as a real `ProblemFailure` so the test asserts the failure **kind**
/// and its `code`, not merely that something failed
/// (`.claude/rules/frontend/testing.md` §4).
ProblemFailure rejection({String detail = 'size must match the pattern'}) =>
    ProblemFailure(
      ProblemDetails(
        type: 'https://errors.finance-a2ui/validation-error',
        title: 'Validation error',
        status: 422,
        detail: detail,
      ),
    );

/// Stubs [repository] to answer [result] for any single-view read.
void stubFetch(MockViewsRepository repository, Result<RenderedViews> result) {
  when(
    () => repository.fetchPortfolioViews(
      portfolioId: any(named: 'portfolioId'),
      views: any(named: 'views'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => result);
}

/// Builds the bloc under test over [repository].
///
/// The view id comes from the **component**, exactly as `OrderTicketPage`
/// supplies it, while the envelopes above are keyed from the **catalog**. If
/// those two ever disagree the suite goes red instead of agreeing with
/// itself.
OrderTicketBloc buildBloc(MockViewsRepository repository) => OrderTicketBloc(
  viewsRepository: repository,
  viewId: const OrderTicketComponent().viewId,
  debounce: testDebounce,
);
