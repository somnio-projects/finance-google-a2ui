import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/layout_component.dart';
import 'package:flutter/widgets.dart';

/// `Section` — the catalog's one layout component (ADR-M D-4): a vertical
/// group of components, allowed only directly under the surface, holding
/// every component whose `allowedParents` names it.
///
/// It binds no payload and draws no chrome of its own; the children are
/// cards already, so the section is their order and their spacing.
class SectionComponent extends LayoutComponent {
  /// Creates the layout.
  const SectionComponent();

  /// The gap between two children — the transcript's own entry gap.
  static const double gap = 12;

  @override
  String get a2uiComponent => 'Section';

  @override
  Widget build(BuildContext context, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (var index = 0; index < children.length; index++) ...<Widget>[
        if (index > 0) const SizedBox(height: gap),
        children[index],
      ],
    ],
  );
}

/// Registers this layout; called from the generated manifest.
void register(ComponentRegistry registry) =>
    registry.registerLayout(const SectionComponent());
