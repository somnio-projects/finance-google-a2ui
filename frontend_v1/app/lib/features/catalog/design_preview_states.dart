import 'package:finance_app/features/catalog/preview_states.dart';

/// The states each design page lists beyond the default, in its order.
///
/// A view without an entry here has the example alone: adding a component
/// edits nothing (ADR-L D-3), and a state nobody has designed is not drawn.
const Map<String, List<PreviewState>> designPreviewStates =
    <String, List<PreviewState>>{
      'attribution.waterfall.v1': <PreviewState>[
        PreviewState(
          label: 'Selected · onSegmentTap',
          kind: PreviewKind.selected,
        ),
        PreviewState.loading,
      ],
      'holdings.allocation.v1': <PreviewState>[
        PreviewState(
          label: 'By asset class · group_by: asset_class',
          kind: PreviewKind.options,
          options: <String, String>{'group_by': 'asset_class'},
        ),
        PreviewState(
          label: 'By sector · group_by: sector',
          kind: PreviewKind.options,
          options: <String, String>{'group_by': 'sector'},
        ),
        PreviewState.loading,
      ],
      'order.ticket.v1': <PreviewState>[
        PreviewState(
          label: 'Recomputed · size: 2 · changed figures marked',
          kind: PreviewKind.recomputed,
          options: <String, String>{'size': '2'},
        ),
        PreviewState(
          label: 'Validation · over available cash',
          kind: PreviewKind.absent,
          note:
              'Not drawn: the contract has no cash constraint. '
              '`order.ticket.v1` places nothing and declares no `maxCash`; '
              "the ticket shows the backend's own refusal when an edit is "
              'rejected (GGU-102).',
        ),
      ],
      'payoff.curve.v1': <PreviewState>[
        PreviewState(
          label: 'Comparison · hold vs after proposed sell',
          kind: PreviewKind.absent,
          note:
              'Not drawn: `payoff.curve.v1` serves one series per render, '
              'and `side: sell` plots its mirror, not a second scenario '
              '(GGU-103).',
        ),
        PreviewState.loading,
      ],
      'scenario.comparison.v1': <PreviewState>[
        PreviewState(
          label: '2-scenario variant',
          kind: PreviewKind.absent,
          note:
              'Not drawn: `methods` is a repeated query parameter and this '
              "client sends one value per option, so the example's columns "
              'are the state it can render.',
        ),
        PreviewState(
          label: 'Loading · skeleton columns',
          kind: PreviewKind.loading,
          note: PreviewState.loadingNote,
        ),
      ],
      'taxlots.table.v1': <PreviewState>[
        PreviewState(
          label: 'Lot method · HIFO · footer recomputed by the backend',
          kind: PreviewKind.options,
          options: <String, String>{'lot_method': 'HIFO'},
        ),
        PreviewState(
          label: 'Empty',
          kind: PreviewKind.absent,
          note:
              'Not drawn: a sale of any quantity consumes a lot, so no option '
              'produces an empty `lots`. The card draws its empty state when '
              'the backend sends none; the inventory marks `lots` '
              '`state: empty` (GGU-104).',
        ),
      ],
    };

/// The states of [viewId]'s page: the example first, then the design's.
List<PreviewState> previewStatesFor(String viewId) => <PreviewState>[
  PreviewState.example,
  ...designPreviewStates[viewId] ?? const <PreviewState>[],
];
