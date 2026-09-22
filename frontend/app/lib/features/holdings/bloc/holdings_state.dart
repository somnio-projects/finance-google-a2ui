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
    this.allocationLoading = false,
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

  /// Whether a new [groupBy]'s card is on the way.
  ///
  /// Distinct from [status], which is the whole tab: a regrouping reloads the
  /// ring and the class rows while the position list is untouched, and the
  /// view has to be able to grey exactly the half the option governs
  /// (spec frontend/0020 OD-3). Until it lands, [allocation] still holds the
  /// *previous* grouping's figures, which is why they must not be shown.
  ///
  /// [assetClass] and [query] are the mirror image — they govern the list and
  /// not the card — so they set [status] to `loading` and leave this alone
  /// (spec frontend/0018 OD-3).
  final bool allocationLoading;

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
    bool? allocationLoading,
    ViewPayload? Function()? positions,
    ViewPayload? Function()? allocation,
    AppFailure? Function()? failure,
  }) => HoldingsState(
    status: status ?? this.status,
    groupBy: groupBy ?? this.groupBy,
    assetClass: assetClass ?? this.assetClass,
    query: query ?? this.query,
    list: list ?? this.list,
    allocationLoading: allocationLoading ?? this.allocationLoading,
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
    allocationLoading,
    positions,
    allocation,
    failure,
  ];
}
