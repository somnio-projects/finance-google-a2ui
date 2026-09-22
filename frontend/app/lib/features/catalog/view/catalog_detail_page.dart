import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/design_preview_states.dart';
import 'package:finance_app/features/catalog/view/catalog_detail_view.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One component's detail page at `/catalog/<view-id>` (spec frontend/0013).
///
/// The view id arrives from the route and is handed to the backend as-is:
/// the catalog decides whether it names a view, and the page shows the
/// answer either way (N-6 — an id is never assembled here).
class CatalogDetailPage extends StatelessWidget {
  /// Creates the page for [viewId].
  const CatalogDetailPage({required this.viewId, super.key});

  /// The view the route named.
  final String viewId;

  @override
  Widget build(BuildContext context) => BlocProvider<CatalogDetailBloc>(
    create: (context) => CatalogDetailBloc(
      viewsRepository: context.read<ViewsRepository>(),
      viewId: viewId,
      states: previewStatesFor(viewId),
    )..add(const CatalogDetailRequested()),
    child: const CatalogDetailView(),
  );
}
