import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/catalog/bloc/catalog_bloc.dart';
import 'package:finance_app/features/catalog/view/catalog_board.dart';
import 'package:finance_app/features/catalog/view/catalog_grid.dart';
import 'package:finance_app/features/catalog/view/catalog_header.dart';
import 'package:finance_app/features/catalog/view/catalog_legend.dart';
import 'package:finance_app/features/catalog/view/catalog_top_bar.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The gallery index as `Catalog_Index.dc.html` stacks it: top bar, header,
/// token legend, then one card per view the backend serves **and** this
/// build renders. Views the backend serves without a registered component
/// are named under the grid rather than drawn as broken thumbnails.
class CatalogView extends StatelessWidget {
  /// Creates the view.
  const CatalogView({super.key});

  /// The sentence before the ids of the unrendered views.
  static const String unrendered =
      'Also served by the backend, without a component in this build:';

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.board,
      body: BlocBuilder<CatalogBloc, CatalogState>(
        builder: (context, state) => switch (state.status) {
          CatalogStatus.initial || CatalogStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          CatalogStatus.failure => CatalogFailure(
            message: state.failure?.message ?? 'The request failed.',
          ),
          CatalogStatus.success => _Index(catalog: state.catalog!),
        },
      ),
    );
  }
}

class _Index extends StatelessWidget {
  const _Index({required this.catalog});

  final ViewCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final registry = context.read<ComponentRegistry>();
    final tokens = CatalogTokens.of(context);
    final rendered = <CatalogEntry>[
      for (final entry in catalog.entries)
        if (registry.lookup(entry.id) != null) entry,
    ];
    final missing = <String>[
      for (final entry in catalog.entries)
        if (registry.lookup(entry.id) == null) entry.id,
    ];
    return CatalogBoard(
      children: <Widget>[
        const CatalogTopBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const CatalogHeader(),
              const SizedBox(height: 26),
              const CatalogLegend(),
              const SizedBox(height: 18),
              CatalogGrid(entries: rendered),
              if (missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    '${CatalogView.unrendered} ${missing.join(' · ')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: tokens.quiet,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
