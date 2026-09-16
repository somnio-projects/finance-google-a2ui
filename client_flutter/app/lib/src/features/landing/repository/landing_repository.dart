import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' hide Catalog;
import 'package:genui/genui.dart';
import 'package:genui_a2a/genui_a2a.dart';
import 'package:logging/logging.dart';

const String defaultServerUrl = 'http://localhost:10002';

// https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json
// https://a2ui.org/specification/v0_9/standard_catalog.json

/// Talks to the restaurant finder agent over A2A and holds the rendered
/// A2UI surfaces.
class LandingRepository {
  LandingRepository({String serverUrl = defaultServerUrl})
    : _connector = A2uiAgentConnector(url: Uri.parse(serverUrl)),
      _surfaceController = SurfaceController(
        catalogs: [
          BasicCatalogItems.asCatalog().copyWith(catalogId: _agentCatalogId),
        ],
      ) {
    _a2uiSub = _connector.stream.listen(_surfaceController.handleMessage);
    _textSub = _connector.textStream.listen(
      (text) => _logger.info('Text from agent: $text'),
    );
  }

  // The agent advertises its catalog under this id (see the Python
  // BasicCatalog provider). The Dart `BasicCatalogItems.asCatalog()` defaults
  // to `.../standard_catalog.json`, so we override the id to match.
  //
  // Catalog id is already fixed in genui at main branch, so, as soon
  // as this fix gets released, the override will no longer be needed.
  static const String _agentCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

  final A2uiAgentConnector _connector;
  final SurfaceController _surfaceController;
  final _logger = Logger('LandingRepository');

  late final StreamSubscription<A2uiMessage> _a2uiSub;
  late final StreamSubscription<String> _textSub;

  SurfaceHost get surfaceHost => _surfaceController;

  Iterable<String> get activeSurfaceIds => _surfaceController.activeSurfaceIds;

  Stream<SurfaceUpdate> get surfaceUpdates => _surfaceController.surfaceUpdates;

  /// Messages submitted from inside rendered surfaces (e.g. "Book Now").
  Stream<ChatMessage> get surfaceSubmits => _surfaceController.onSubmit;

  Stream<Object> get errors => _connector.errorStream;

  /// Clears existing surfaces and sends [message] to the agent.
  ///
  /// Completes once the agent has finished responding.
  Future<void> sendMessage(ChatMessage message) async {
    for (final String id in [..._surfaceController.activeSurfaceIds]) {
      _surfaceController.handleMessage(DeleteSurfaceMessage(surfaceId: id));
    }
    await _connector.connectAndSend(
      message,
      clientCapabilities: _surfaceController.clientCapabilities,
    );
  }

  void dispose() {
    _a2uiSub.cancel();
    _textSub.cancel();
    _surfaceController.dispose();
    _connector.dispose();
  }
}
