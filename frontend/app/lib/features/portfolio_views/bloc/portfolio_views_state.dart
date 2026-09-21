part of 'portfolio_views_bloc.dart';

/// Where [PortfolioViewsBloc] is in its fetch.
///
/// Loading and failure live here, in *transport* state, and never in a
/// payload: no projection carries an `isLoading` flag, because a surface is
/// either rendered or not yet rendered (ADR-K D-19).
enum PortfolioViewsStatus {
  /// Nothing has been asked for yet.
  initial,

  /// A request is in flight.
  loading,

  /// Views were rendered and are in [PortfolioViewsState.rendered].
  success,

  /// The request failed; see [PortfolioViewsState.failure].
  failure,
}

/// What the portfolio-views screen renders.
final class PortfolioViewsState extends Equatable {
  /// Creates a state.
  const PortfolioViewsState({
    this.status = PortfolioViewsStatus.initial,
    this.rendered,
    this.failure,
  });

  /// Where the fetch is.
  final PortfolioViewsStatus status;

  /// The envelope the backend returned, once there is one.
  final RenderedViews? rendered;

  /// Why the fetch failed, when it did.
  final AppFailure? failure;

  /// Copies this state, replacing only the fields whose getter is supplied.
  ///
  /// Each parameter is a getter rather than a value so that passing `null`
  /// *retains* the old value while `() => null` *clears* it — the distinction
  /// a plain `T?` parameter cannot express.
  PortfolioViewsState copyWith({
    PortfolioViewsStatus Function()? status,
    RenderedViews? Function()? rendered,
    AppFailure? Function()? failure,
  }) => PortfolioViewsState(
    status: status != null ? status() : this.status,
    rendered: rendered != null ? rendered() : this.rendered,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => <Object?>[status, rendered, failure];
}
