part of 'catalog_detail_bloc.dart';

/// Where a detail page is in its load.
enum CatalogDetailStatus {
  /// Nothing requested yet.
  initial,

  /// The catalog and the renders are in flight.
  loading,

  /// The entry and every render answered (some may have failed).
  success,

  /// The catalog itself failed, or serves no such view.
  failure,
}

/// One Zone 1 state and what the backend answered for it.
///
/// [payload] is set for a state the backend re-rendered; [failure] for one it
/// refused or could not answer, shown verbatim on the card (N-9); both null
/// for a state drawn from the example alone or not drawn at all.
final class PreviewRender extends Equatable {
  /// Creates a render.
  const PreviewRender({required this.state, this.payload, this.failure});

  /// The state this render is for.
  final PreviewState state;

  /// The re-rendered view, when the state asked for one and it answered.
  final ViewPayload? payload;

  /// Why the re-render did not answer, when it did not.
  final AppFailure? failure;

  @override
  List<Object?> get props => <Object?>[state, payload, failure];
}

/// A detail page's state.
final class CatalogDetailState extends Equatable {
  /// Creates the state.
  const CatalogDetailState({
    this.status = CatalogDetailStatus.initial,
    this.entry,
    this.renders = const <PreviewRender>[],
    this.failure,
  });

  /// Where the load is.
  final CatalogDetailStatus status;

  /// The view's catalog entry, once it arrived.
  final CatalogEntry? entry;

  /// One render per Zone 1 state, in the page's order.
  final List<PreviewRender> renders;

  /// Why the page failed, when it did.
  final AppFailure? failure;

  @override
  List<Object?> get props => <Object?>[status, entry, renders, failure];
}
