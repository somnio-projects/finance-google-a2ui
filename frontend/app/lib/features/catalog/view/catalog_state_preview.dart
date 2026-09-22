import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/component_skeleton_host.dart';
import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/preview_states.dart';
import 'package:finance_app/features/catalog/view/catalog_state_special.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The body of one Zone 1 state card, by the kind of state it is.
///
/// A live kind renders the **real component** through the registry, bound to
/// a payload the backend rendered; a re-render the backend refused shows its
/// refusal verbatim (N-9); an absent kind shows the note that says why the
/// design's state is not drawn — never a payload this client made up (N-3).
class CatalogStatePreview extends StatelessWidget {
  /// Creates the body for [render] of [entry].
  const CatalogStatePreview({
    required this.render,
    required this.entry,
    super.key,
  });

  /// The state and what the backend answered for it.
  final PreviewRender render;

  /// The page's catalog entry, whose example is the default payload.
  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final registry = context.read<ComponentRegistry>();
    final tokens = CatalogTokens.of(context);
    final note = TextStyle(fontSize: 11.5, height: 1.5, color: tokens.quiet);
    return switch (render.state.kind) {
      PreviewKind.example => ComponentHost(
        registry: registry,
        payload: entry.example,
      ),
      PreviewKind.selected => SelectedWaterfallPreview(payload: entry.example),
      PreviewKind.loading => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ComponentSkeletonHost(registry: registry, view: entry.id),
          if (render.state.note case final String words) ...<Widget>[
            const SizedBox(height: 10),
            Text(words, style: note),
          ],
        ],
      ),
      PreviewKind.absent => Text(render.state.note ?? '', style: note),
      PreviewKind.options || PreviewKind.recomputed => switch (render) {
        PreviewRender(:final ViewPayload payload) =>
          render.state.kind == PreviewKind.recomputed
              ? RecomputedTicketPreview(before: entry.example, after: payload)
              : ComponentHost(registry: registry, payload: payload),
        PreviewRender(:final AppFailure failure) => Text(
          'The backend did not re-render this state: ${failure.message}',
          style: note,
        ),
        _ => Text('This state was not requested.', style: note),
      },
    };
  }
}
