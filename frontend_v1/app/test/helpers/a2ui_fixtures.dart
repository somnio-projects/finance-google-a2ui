import 'dart:convert';
import 'dart:io';

import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/action_clock.dart';
import 'package:finance_app/a2ui/finance_catalog.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

/// The v1.0 wire contract, read in place from the repository
/// (`docs/a2ui/v1.0/examples/`), never copied.
const String v1ExamplesDir = '../../docs/a2ui/v1.0/examples';

/// The catalog the bundle ships — the asset `make catalog` writes — so a
/// widget test enforces exactly the composition rules the app does.
Catalog bundledCatalog() => readFinanceCatalog(
  File('assets/a2ui/finance.catalog.json').readAsStringSync(),
);

/// The decoded DataPart in the example file [name].
Map<String, Object?> v1Example(String name) =>
    jsonDecode(File('$v1ExamplesDir/$name').readAsStringSync())
        as Map<String, Object?>;

/// The example [name] as the agent event a turn would carry it in.
AgentSurfaceMessages v1ExampleEvent(String name) =>
    AgentSurfaceMessages(decodeAgentDataPart(v1Example(name)));

/// A one-component surface, the shape ADR-M D-3 gives every render intent:
/// `root` is [component], bound to `/root`, whose data model entry is
/// `{view, options, payload}` with [payload] verbatim.
AgentSurfaceMessages surfaceEvent({
  required String surfaceId,
  required String component,
  required Map<String, Object?> payload,
  Map<String, Object?> options = const <String, Object?>{},
  String label = 'Surface',
}) => AgentSurfaceMessages(<Decoded>[
  decodeAgentMessage(<String, Object?>{
    'version': 'v1.0',
    'createSurface': <String, Object?>{
      'surfaceId': surfaceId,
      'catalogId': financeCatalogId,
      'components': <Object?>[
        <String, Object?>{
          'id': 'root',
          'component': component,
          'data': <String, Object?>{'path': '/root'},
          'accessibility': <String, Object?>{'label': label},
        },
      ],
      'dataModel': <String, Object?>{
        'root': <String, Object?>{
          'view': payload['view'],
          'options': options,
          'payload': payload,
        },
      },
    },
  }),
]);

/// A two-node surface — [parent] at `root` holding [child] — the shape of
/// a ticket with its payoff (ADR-M D-4, `surface.order_ticket_with_payoff`).
AgentSurfaceMessages nestedSurfaceEvent({
  required String parent,
  required Map<String, Object?> parentPayload,
  required String child,
  required Map<String, Object?> childPayload,
}) => AgentSurfaceMessages(<Decoded>[
  decodeAgentMessage(<String, Object?>{
    'version': 'v1.0',
    'createSurface': <String, Object?>{
      'surfaceId': 's-nested',
      'catalogId': financeCatalogId,
      'components': <Object?>[
        <String, Object?>{
          'id': 'root',
          'component': parent,
          'data': <String, Object?>{'path': '/root'},
          'children': <Object?>['child'],
        },
        <String, Object?>{
          'id': 'child',
          'component': child,
          'data': <String, Object?>{'path': '/child'},
        },
      ],
      'dataModel': <String, Object?>{
        'root': <String, Object?>{
          'view': parentPayload['view'],
          'payload': parentPayload,
        },
        'child': <String, Object?>{
          'view': childPayload['view'],
          'payload': childPayload,
        },
      },
    },
  }),
]);

/// The agent's answer to a `renderView` call [callId] on [surfaceId]: the
/// function response and the data model update that follows it.
AgentSurfaceMessages renderViewAnswer({
  required String surfaceId,
  required String callId,
  required Map<String, Object?> payload,
  Map<String, Object?> options = const <String, Object?>{},
}) => AgentSurfaceMessages(<Decoded>[
  DecodedMessage(
    AgentFunctionResponse(
      functionCallId: callId,
      value: <String, Object?>{'componentId': 'root', 'view': payload['view']},
    ),
  ),
  DecodedMessage(
    UpdateDataModel(
      surfaceId: surfaceId,
      path: '/root',
      value: <String, Object?>{
        'view': payload['view'],
        'options': options,
        'payload': payload,
      },
    ),
  ),
]);

/// A clock that always answers the example's timestamp.
class FixedActionClock extends ActionClock {
  /// Creates the clock.
  const FixedActionClock();

  /// The timestamp `action.drill_attribution.json` carries.
  static const String instant = '2026-10-01T22:00:00Z';

  @override
  String now() => instant;
}
