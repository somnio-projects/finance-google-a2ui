import 'package:finance_app/features/catalog/bloc/catalog_bloc.dart';
import 'package:finance_app/features/catalog/view/catalog_view.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The developer catalog's index at `/catalog` (spec frontend/0013).
///
/// A page, so the only file of this feature allowed to read the repository
/// from the tree: it builds the bloc that needs one
/// (`layering_test.dart::only a page resolves a repository`).
class CatalogPage extends StatelessWidget {
  /// Creates the page.
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<CatalogBloc>(
    create: (context) =>
        CatalogBloc(viewsRepository: context.read<ViewsRepository>())
          ..add(const CatalogRequested()),
    child: const CatalogView(),
  );
}
