import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'order_ticket_event.dart';
part 'order_ticket_state.dart';

/// Owns the order ticket's options and the round trip that re-renders it.
///
/// **This bloc is why the ticket has a page of its own.** The read endpoint
/// applies one flat option set to every view in a request (N-7), and `side`
/// is not an option `holdings.allocation.v1` declares — so asking for the
/// ticket's options alongside the other surfaces would 422 all of them. The
/// request here carries exactly one view id, which makes that structural
/// rather than a comment (spec 0006 OD-5).
///
/// It computes nothing. An edit changes an **option**; every figure that
/// comes back was formatted by the backend.
class OrderTicketBloc extends Bloc<OrderTicketEvent, OrderTicketState> {
  /// Creates the bloc over [viewsRepository].
  ///
  /// [debounce] is injected so a test drives it explicitly instead of
  /// sleeping for a constant someone has to keep in step.
  OrderTicketBloc({
    required ViewsRepository viewsRepository,
    required this.viewId,
    this.portfolioId = 'current',
    this.debounce = defaultDebounce,
  }) : _viewsRepository = viewsRepository,
       super(const OrderTicketState()) {
    on<OrderTicketRequested>(_onRequested);
    on<OrderTicketOptionChanged>(_onOptionChanged);
    on<OrderTicketReloaded>(_onReloaded);
  }

  /// The frozen view id to render, injected rather than declared here: the
  /// **component** owns that literal (N-6), and the page hands it over. A
  /// copy would be the second declaration that goes stale — the defect
  /// GGU-79 closed one layer up in the router.
  final String viewId;

  /// The portfolio the ticket is written against.
  final String portfolioId;

  /// How long a burst of edits coalesces before one request goes out: long
  /// enough that a menu change and a keystroke burst become one request,
  /// short enough to stay inside the p95 budget (spec 0006 OD-6, AC-3).
  static const Duration defaultDebounce = Duration(milliseconds: 300);

  /// The debounce in effect.
  final Duration debounce;

  final ViewsRepository _viewsRepository;
  Timer? _timer;

  /// The exact options map of the request in flight, compared by identity
  /// when a response lands so a superseded one cannot overwrite a newer
  /// ticket. The instance is a generation marker needing no counter.
  Map<String, String>? _inFlight;

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    OrderTicketRequested event,
    Emitter<OrderTicketState> emit,
  ) async {
    emit(state.copyWith(status: () => OrderTicketStatus.loading));
    await _fetch(emit, options: state.options);
  }

  void _onOptionChanged(
    OrderTicketOptionChanged event,
    Emitter<OrderTicketState> emit,
  ) {
    // The changed option joins the ones already in effect; nothing else is
    // sent, and every key is an option the payload itself declared (AC-1).
    final options = <String, String>{
      ...state.options,
      event.option: event.value,
    };
    emit(
      state.copyWith(
        status: () => OrderTicketStatus.updating,
        options: () => options,
        pendingOption: () => event.option,
        rejection: () => null,
      ),
    );
    _timer?.cancel();
    _timer = Timer(debounce, () {
      if (!isClosed) add(const OrderTicketReloaded());
    });
  }

  Future<void> _onReloaded(
    OrderTicketReloaded event,
    Emitter<OrderTicketState> emit,
  ) => _fetch(emit, options: state.options);

  Future<void> _fetch(
    Emitter<OrderTicketState> emit, {
    required Map<String, String> options,
  }) async {
    _inFlight = options;
    final result = await _viewsRepository.fetchPortfolioViews(
      portfolioId: portfolioId,
      views: <String>[viewId],
      options: options,
    );
    if (!identical(_inFlight, options)) return;
    emit(switch (result) {
      Ok<RenderedViews>(:final value) => _rendered(value),
      // The edited value stays in `options` on purpose: a rejection is shown,
      // not silently reverted, so the reader can see what was refused (AC-5).
      Err<RenderedViews>(:final failure) => state.copyWith(
        status: () => OrderTicketStatus.rejected,
        pendingOption: () => null,
        rejection: () => failure.message,
      ),
    });
  }

  OrderTicketState _rendered(RenderedViews envelope) {
    final payload = envelope.views[viewId];
    if (payload == null) {
      return state.copyWith(
        status: () => OrderTicketStatus.rejected,
        pendingOption: () => null,
        rejection: () =>
            const ContractFailure('views', 'the requested view').message,
      );
    }
    return state.copyWith(
      status: () => OrderTicketStatus.ready,
      payload: () => payload,
      // Kept so the view can mark what changed. It is never rendered.
      previous: () => state.payload,
      pendingOption: () => null,
      rejection: () => null,
    );
  }
}
