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
