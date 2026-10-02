import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/surface_edit_state.dart';
import 'package:finance_app/a2ui/surface_host.dart';
import 'package:finance_app/bootstrap.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// The surfaces [events] leave behind, applied by the real processor.
SurfaceSet surfacesOf(List<AgentSurfaceMessages> events) {
  var set = const SurfaceSet();
  for (final event in events) {
    set = const SurfaceProcessor().process(set, event.messages).surfaces;
  }
  return set;
}

/// The one surface [event] creates.
Surface surfaceOf(AgentSurfaceMessages event) =>
    surfacesOf(<AgentSurfaceMessages>[event]).surfaces.values.single;

/// Pumps [surface] in a scrollable column, as the transcript holds it,
/// with the real registry and the bundled catalog.
Future<void> pumpSurface(
  WidgetTester tester,
  Surface surface, {
  Catalog? catalog,
  Map<String, SurfaceEditState> edits = const <String, SurfaceEditState>{},
  SurfaceOptionEdit? onOptionChanged,
  SurfaceActionRaised? onAction,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpApp(
    Scaffold(
      body: SingleChildScrollView(
        child: SurfaceHost(
          surface: surface,
          catalog: catalog ?? bundledCatalog(),
          registry: buildComponentRegistry(),
          edits: edits,
          onOptionChanged: onOptionChanged,
          onAction: onAction,
        ),
      ),
    ),
    reducedMotion: true,
  );
}
