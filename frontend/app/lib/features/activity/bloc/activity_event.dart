part of 'activity_bloc.dart';

/// What the Activity tab can be asked to do.
sealed class ActivityEvent extends Equatable {
  const ActivityEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Load the timeline with the current filter.
final class ActivityRequested extends ActivityEvent {
  /// Creates the event.
  const ActivityRequested();
}

/// A filter chip was tapped.
final class ActivityKindChanged extends ActivityEvent {
  /// Creates the event.
  const ActivityKindChanged(this.kind);

  /// The chip's declared `kind` value.
  final String kind;

  @override
  List<Object?> get props => <Object?>[kind];
}

/// The search box was edited — or closed, which sends an empty string.
final class ActivityQueryChanged extends ActivityEvent {
  /// Creates the event.
  const ActivityQueryChanged(this.query);

  /// The declared `query` option's value; empty means no search.
  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// The debounce elapsed: fetch with whatever is now in state.
final class ActivityReloaded extends ActivityEvent {
  /// Creates the event.
  const ActivityReloaded();
}
