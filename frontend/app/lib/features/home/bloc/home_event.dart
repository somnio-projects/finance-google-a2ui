part of 'home_bloc.dart';

/// What the Home tab can be asked to do.
sealed class HomeEvent extends Equatable {
  const HomeEvent();
}

/// Load both views.
final class HomeRequested extends HomeEvent {
  /// Creates the event.
  const HomeRequested();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The reader picked another period on the range selector.
final class HomeRangeChanged extends HomeEvent {
  /// Creates the event with the declared range code (`1d`, `1w`, …).
  const HomeRangeChanged(this.range);

  /// The range, exactly as the backend declares it.
  final String range;

  @override
  List<Object?> get props => <Object?>[range];
}
