/// A2UI v1.0, the renderer half, in pure Dart (ADR-M D-1).
///
/// No Flutter and no A2UI package: `genui` speaks v0.9 and `a2ui_core`'s
/// processor does not accept v1.0 yet (a2ui-project/a2ui#2899), so this is
/// the subset of the protocol this catalog uses, proven against the vendored
/// official schemas' canonical examples. Moving to `a2ui_flutter` later is a
/// change behind this API, not through it.
library;

export 'src/agent_message.dart';
export 'src/agent_message_codec.dart';
export 'src/builders.dart';
export 'src/catalog.dart';
export 'src/component_node.dart';
export 'src/composition.dart';
export 'src/data_part.dart';
export 'src/json_pointer.dart' show pointerTokens, readPointer, writePointer;
export 'src/protocol.dart';
export 'src/renderer_message.dart';
export 'src/renderer_message_codec.dart';
export 'src/surface.dart';
export 'src/surface_processor.dart';
export 'src/wire_reader.dart' show A2uiFormatException;
