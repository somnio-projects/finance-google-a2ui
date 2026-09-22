import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/preview_states.dart';

import '../catalog_fixtures.dart';

/// The view both detail-bloc suites document.
const String detailViewId = 'holdings.allocation.v1';

/// A state whose option the view declares.
const PreviewState sectorState = PreviewState(
  label: 'By sector',
  kind: PreviewKind.options,
  options: <String, String>{'group_by': 'sector'},
);

/// A state whose option the view does **not** declare (N-7).
const PreviewState undeclaredState = PreviewState(
  label: 'Nope',
  kind: PreviewKind.options,
  options: <String, String>{'side': 'sell'},
);

/// Builds the bloc under test over [repository].
CatalogDetailBloc buildDetailBloc(
  MockCatalogRepository repository, {
  List<PreviewState> states = const <PreviewState>[
    PreviewState.example,
    sectorState,
    undeclaredState,
  ],
  String view = detailViewId,
}) => CatalogDetailBloc(
  viewsRepository: repository,
  viewId: view,
  states: states,
);
