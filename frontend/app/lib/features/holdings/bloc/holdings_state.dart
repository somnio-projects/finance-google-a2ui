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

  /// Whether a new [groupBy]'s card is on the way.
  ///
  /// Distinct from [status], which is the whole tab: a regrouping reloads the
  /// ring and the class rows while the position list is untouched, and the
  /// view has to be able to grey exactly the half the option governs
  /// (spec frontend/0020 OD-3). Until it lands, [allocation] still holds the
  /// *previous* grouping's figures, which is why they must not be shown.
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
    HoldingsList? list,
    bool? allocationLoading,
    ViewPayload? Function()? positions,
    ViewPayload? Function()? allocation,
    AppFailure? Function()? failure,
  }) => HoldingsState(
    status: status ?? this.status,
    groupBy: groupBy ?? this.groupBy,
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
    list,
    allocationLoading,
    positions,
    allocation,
    failure,
  ];
}
