part of 'holdings_bloc.dart';

/// Where the tab stands.
enum HoldingsStatus {
  /// Nothing asked yet.
  initial,

  /// Both views in flight.
  loading,

  /// Both views arrived.
  success,

  /// One of them failed.
  failure,
}

/// Which list the segmented control shows.
enum HoldingsList {
  /// One row per position.
  positions,

  /// One row per asset class, from the allocation card's rows.
  classes,
}

/// The Holdings tab's state.
class HoldingsState extends Equatable {
  /// Creates the state.
  const HoldingsState({
    this.status = HoldingsStatus.initial,
    this.groupBy = 'asset_class',
    this.assetClass = everyAssetClass,
    this.query = '',
    this.list = HoldingsList.positions,
    this.positions,
    this.allocation,
    this.failure,
  });

  /// Where the tab stands.
  final HoldingsStatus status;

  /// The card's grouping — a declared option value.
  final String groupBy;

  /// The class filter in force — a declared option value.
  final String assetClass;

  /// The search in force — the declared `query` option; empty means none.
  final String query;

  /// Which list is shown.
  final HoldingsList list;

  /// `holdings.positions.v1`, once loaded.
  final ViewPayload? positions;

  /// `holdings.allocation.v1`, grouped by [groupBy].
  final ViewPayload? allocation;

  /// What failed, when something did.
  final AppFailure? failure;

  /// A copy with the given fields replaced; nullable ones are thunks.
  HoldingsState copyWith({
    HoldingsStatus? status,
    String? groupBy,
    String? assetClass,
    String? query,
    HoldingsList? list,
    ViewPayload? Function()? positions,
    ViewPayload? Function()? allocation,
    AppFailure? Function()? failure,
  }) => HoldingsState(
    status: status ?? this.status,
    groupBy: groupBy ?? this.groupBy,
    assetClass: assetClass ?? this.assetClass,
    query: query ?? this.query,
    list: list ?? this.list,
    positions: positions == null ? this.positions : positions(),
    allocation: allocation == null ? this.allocation : allocation(),
    failure: failure == null ? this.failure : failure(),
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    groupBy,
    assetClass,
    query,
    list,
    positions,
    allocation,
    failure,
  ];
}
