/// The constants of the A2UI v1.0 wire this package speaks.
///
/// They live in one place so a version bump is one edit, and so no other file
/// spells the protocol's strings from memory.
abstract final class A2uiProtocol {
  /// The `version` every v1.0 message carries.
  static const String version = 'v1.0';

  /// The `metadata.mimeType` that marks an A2A `DataPart` as A2UI.
  static const String mimeType = 'application/a2ui+json';

  /// The A2A extension URI a v1.0 renderer activates.
  static const String extensionUri = 'https://a2ui.org/a2a-extension/a2ui/v1.0';

  /// The reserved container `createSurface` instantiates implicitly.
  static const String surfaceComponent = 'Surface';

  /// The id of the component that mounts under [surfaceComponent].
  static const String rootId = 'root';
}

/// The `a2uiRendererCapabilities` object a renderer attaches to every A2A
/// message (`renderer_capabilities.json`), for [catalogIds].
Map<String, Object?> rendererCapabilities(List<String> catalogIds) =>
    <String, Object?>{
      'v1.0': <String, Object?>{'supportedCatalogIds': catalogIds},
    };
