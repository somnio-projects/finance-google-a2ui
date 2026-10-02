import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/portfolio_summary/portfolio_summary_card.dart';
import 'package:finance_app/components/surface_edits.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `portfolio.summary.v1` — the Home hero and its top movers, as a
/// surface the agent can put in the Assistant (ADR-M D-3, canonical example
/// `docs/a2ui/v1.0/examples/surface.portfolio_summary.json`).
///
/// The widgets are Home's own (`HomeHero`, `HomeMovers`), moved into this
/// directory so a component may use them — components never import a
/// feature — and Home now imports them from here. One rendering of one
/// payload, two screens.
class PortfolioSummaryComponent extends ViewComponent {
  /// Creates the component.
  const PortfolioSummaryComponent();

  /// The declared option the range selector edits.
  static const String rangeOption = 'range';

  /// The range the hero shows before an option says otherwise — Home's own
  /// starting range (`HomeState.range`).
  static const String defaultRange = '1d';

  @override
  String get viewId => 'portfolio.summary.v1';

  @override
  String get a2uiComponent => 'PortfolioSummary';

  @override
  Widget build(BuildContext context, ViewPayload payload) {
    // The selected range is an OPTION, not a payload field, so it is read
    // from the scope's options (the surface's data model); read-only, and
    // on the default, anywhere no host can re-render it.
    final edits = SurfaceEdits.maybeOf(context);
    final range = edits?.options[rangeOption];
    return PortfolioSummaryCard(
      payload: payload,
      range: range is String ? range : defaultRange,
      loading: edits?.pendingOption == rangeOption,
      rejection: edits?.rejection,
      onRangeSelected: edits == null
          ? null
          : (code) => edits.onOptionChanged(rangeOption, code),
    );
  }
}

/// Registers this component; called from the generated manifest.
void register(ComponentRegistry registry) =>
    registry.register(const PortfolioSummaryComponent());
