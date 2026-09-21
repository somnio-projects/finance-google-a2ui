part of 'home_bloc.dart';

/// Where the Home tab is in its load.
enum HomeStatus {
  /// Nothing requested yet.
  initial,

  /// Both requests in flight.
  loading,

  /// Both payloads on hand.
  success,

  /// Something failed; [HomeState.failure] says what.
  failure,
}

/// The Home tab's state: two payloads and the selected range.
final class HomeState extends Equatable {
  /// Creates the state.
  const HomeState({
    this.status = HomeStatus.initial,
    this.range = '1d',
    this.summary,
    this.allocation,
    this.failure,
  });

  /// Where the load is.
  final HomeStatus status;

  /// The selected range code; the backend's default to start.
  final String range;

  /// `portfolio.summary.v1`, once it arrived.
  final ViewPayload? summary;

  /// `holdings.allocation.v1` by class, once it arrived.
  final ViewPayload? allocation;

  /// Why the load failed, when it did.
  final AppFailure? failure;

  /// Returns a copy with the given fields replaced.
  HomeState copyWith({
    HomeStatus Function()? status,
    String Function()? range,
    ViewPayload? Function()? summary,
    ViewPayload? Function()? allocation,
    AppFailure? Function()? failure,
  }) => HomeState(
    status: status != null ? status() : this.status,
    range: range != null ? range() : this.range,
    summary: summary != null ? summary() : this.summary,
    allocation: allocation != null ? allocation() : this.allocation,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    range,
    summary,
    allocation,
    failure,
  ];
}
