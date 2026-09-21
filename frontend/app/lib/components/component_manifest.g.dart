// GENERATED FILE — do not edit by hand.
// Regenerate with: cd frontend && dart run tool/generate_component_manifest.dart
//
// One entry per directory under app/lib/components. Adding a component means
// adding its directory and running the command above; no hand-written file
// changes (ADR-L D-3). `make manifest-check` fails the gate when this file
// and the directories disagree.

import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart'
    as holdings_allocation;

/// Registers every catalog component this build ships.
void registerCatalogComponents(ComponentRegistry registry) {
  holdings_allocation.register(registry);
}
