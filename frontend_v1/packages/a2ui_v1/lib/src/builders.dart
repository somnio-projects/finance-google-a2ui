import 'package:a2ui_v1/src/renderer_message.dart';

/// The one agent function this catalog declares (ADR-M D-6).
const String renderViewFunction = 'renderView';

/// The one surface action this catalog sends (ADR-M D-7).
const String drillAttributionAction = 'drill_attribution';

/// `callAgentFunction("renderView")` for an edit of [componentId]'s options.
///
/// [options] is the **whole** option set the component should be rendered
/// with — the ones it had plus the edit — because the agent renders it
/// afresh and validates it against the projection's own options model
/// (ADR-K D-3). Nothing here interprets an option; values travel verbatim.
CallAgentFunction renderViewCall({
  required String surfaceId,
  required String functionCallId,
  required String catalogId,
  required String componentId,
  required String view,
  required Map<String, Object?> options,
}) => CallAgentFunction(
  surfaceId: surfaceId,
  functionCallId: functionCallId,
  call: renderViewFunction,
  catalogId: catalogId,
  args: <String, Object?>{
    'componentId': componentId,
    'view': view,
    'options': options,
  },
);

/// `action("drill_attribution")` for a tap on [driver]'s waterfall bar.
///
/// [timestamp] is passed in rather than read: this package is pure and has
/// no clock, and the caller's clock is a seam a test can fix.
ActionMessage drillAttribution({
  required String surfaceId,
  required String sourceComponentId,
  required String timestamp,
  required String driver,
}) => ActionMessage(
  name: drillAttributionAction,
  surfaceId: surfaceId,
  sourceComponentId: sourceComponentId,
  timestamp: timestamp,
  context: <String, Object?>{'driver': driver},
);
