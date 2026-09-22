part of 'holdings_bloc.dart';

/// What the Holdings tab can be asked to do.
sealed class HoldingsEvent extends Equatable {
  const HoldingsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Load the list and the card.
final class HoldingsRequested extends HoldingsEvent {
  /// Creates the event.
  const HoldingsRequested();
}

/// The `By asset class | By sector` toggle moved.
final class HoldingsGroupByChanged extends HoldingsEvent {
  /// Creates the event.
  const HoldingsGroupByChanged(this.groupBy);

  /// The declared `group_by` value.
  final String groupBy;

  @override
  List<Object?> get props => <Object?>[groupBy];
}

/// The `By position | By asset class` segment moved.
final class HoldingsListChanged extends HoldingsEvent {
  /// Creates the event.
  const HoldingsListChanged(this.list);

  /// Which list the tab shows.
  final HoldingsList list;

  @override
  List<Object?> get props => <Object?>[list];
}
