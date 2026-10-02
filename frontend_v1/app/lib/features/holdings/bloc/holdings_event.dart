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

/// A chip in the filter sheet was picked.
final class HoldingsAssetClassChanged extends HoldingsEvent {
  /// Creates the event.
  const HoldingsAssetClassChanged(this.assetClass);

  /// The declared `asset_class` value; `all` is no filter.
  final String assetClass;

  @override
  List<Object?> get props => <Object?>[assetClass];
}

/// The search box was edited — or closed, which sends an empty string.
final class HoldingsQueryChanged extends HoldingsEvent {
  /// Creates the event.
  const HoldingsQueryChanged(this.query);

  /// The declared `query` option's value; empty means no search.
  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// The debounce elapsed: fetch the list with whatever is now in state.
final class HoldingsReloaded extends HoldingsEvent {
  /// Creates the event.
  const HoldingsReloaded();
}
