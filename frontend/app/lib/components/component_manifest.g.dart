// GENERATED FILE — do not edit by hand.
// Regenerate with: cd frontend && dart run tool/generate_component_manifest.dart
//
// One entry per directory under app/lib/components. Adding a component means
// adding its directory and running the command above; no hand-written file
// changes (ADR-L D-3). `make manifest-check` fails the gate when this file
// and the directories disagree.

import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart'
    as attribution_waterfall;
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart'
    as holdings_allocation;
import 'package:finance_app/components/payoff_chart/payoff_chart_component.dart'
    as payoff_chart;
import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart'
    as scenario_comparison;

/// Registers every catalog component this build ships.
void registerCatalogComponents(ComponentRegistry registry) {
  attribution_waterfall.register(registry);
  holdings_allocation.register(registry);
  payoff_chart.register(registry);
  scenario_comparison.register(registry);
}
