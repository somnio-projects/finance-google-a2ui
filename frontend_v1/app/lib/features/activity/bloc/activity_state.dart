part of 'activity_bloc.dart';

/// Where the tab stands.
enum ActivityStatus {
  /// Nothing asked yet.
  initial,

  /// The timeline is in flight.
  loading,

  /// The timeline arrived.
  success,

  /// The request failed.
  failure,
}

/// The Activity tab's state.
class ActivityState extends Equatable {
  /// Creates the state.
  const ActivityState({
    this.status = ActivityStatus.initial,
    this.kind = 'all',
    this.query = '',
    this.timeline,
    this.failure,
  });

  /// Where the tab stands.
  final ActivityStatus status;

  /// The filter in force — a declared option value.
  final String kind;

  /// The search in force — the declared `query` option; empty means none.
  final String query;

  /// `activity.timeline.v1`, once loaded.
  final ViewPayload? timeline;

  /// What failed, when something did.
  final AppFailure? failure;

  /// A copy with the given fields replaced; nullable ones are thunks.
  ActivityState copyWith({
    ActivityStatus? status,
    String? kind,
    String? query,
    ViewPayload? Function()? timeline,
    AppFailure? Function()? failure,
  }) => ActivityState(
    status: status ?? this.status,
    kind: kind ?? this.kind,
    query: query ?? this.query,
    timeline: timeline == null ? this.timeline : timeline(),
    failure: failure == null ? this.failure : failure(),
  );

  @override
  List<Object?> get props => <Object?>[status, kind, query, timeline, failure];
}
