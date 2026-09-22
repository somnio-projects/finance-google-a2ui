import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/view/catalog_board.dart';
import 'package:finance_app/features/catalog/view/catalog_detail_header.dart';
import 'package:finance_app/features/catalog/view/catalog_guidance_cards.dart';
import 'package:finance_app/features/catalog/view/catalog_loading.dart';
import 'package:finance_app/features/catalog/view/catalog_preview_zone.dart';
import 'package:finance_app/features/catalog/view/catalog_prompt_zone.dart';
import 'package:finance_app/features/catalog/view/catalog_schema_zone.dart';
import 'package:finance_app/features/catalog/view/catalog_top_bar.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A detail page as the six `Catalog_<Component>` artboards stack it: top
/// bar with the crumb, header, Zone 1 beside Zones 2 and 3 at the design's
/// width (1.55fr / 1fr, 20 apart), stacked on a narrow viewport, and the
/// Do / Don't pair under them.
class CatalogDetailView extends StatelessWidget {
  /// Creates the view.
  const CatalogDetailView({super.key});

  /// Below this width the zones stack.
  static const double twoColumnsFrom = 860;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.board,
      body: BlocBuilder<CatalogDetailBloc, CatalogDetailState>(
        builder: (context, state) => switch (state.status) {
          // The page in its own shape, not a spinner (spec 0020 AC-6).
          CatalogDetailStatus.initial ||
          CatalogDetailStatus.loading => const CatalogDetailLoading(),
          CatalogDetailStatus.failure => CatalogFailure(
            message: state.failure?.message ?? 'The request failed.',
          ),
          CatalogDetailStatus.success => _Detail(state: state),
        },
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.state});

  final CatalogDetailState state;

  @override
  Widget build(BuildContext context) {
    final entry = state.entry!;
    final preview = CatalogPreviewZone(entry: entry, renders: state.renders);
    final schema = CatalogSchemaZone(entry: entry);
    final prompt = CatalogPromptZone(entry: entry);
    return CatalogBoard(
      children: <Widget>[
        CatalogTopBar(component: entry.component),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 30, 32, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CatalogDetailHeader(entry: entry),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= CatalogDetailView.twoColumnsFrom
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(flex: 155, child: preview),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 100,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                schema,
                                const SizedBox(height: 16),
                                prompt,
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          preview,
                          const SizedBox(height: 20),
                          schema,
                          const SizedBox(height: 16),
                          prompt,
                        ],
                      ),
              ),
              const SizedBox(height: 22),
              CatalogGuidanceCards(guidance: entry.guidance),
            ],
          ),
        ),
      ],
    );
  }
}
