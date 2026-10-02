import 'package:flutter/widgets.dart';

/// A catalog component that binds **no payload** and only arranges the
/// children an A2UI surface gives it — `Section` today (ADR-M D-4).
///
/// The counterpart of `ViewComponent` for the other kind of node a v1.0
/// adjacency list carries. It is registered the same way, from its own
/// module, so adding a second layout edits no existing file (ADR-L D-3).
abstract class LayoutComponent {
  /// Allows subclasses to declare `const` constructors.
  const LayoutComponent();

  /// The catalog's component name, e.g. `Section`.
  String get a2uiComponent;

  /// Lays out [children], already built, in the order the agent listed them
  /// (N-10: nothing is re-ordered).
  Widget build(BuildContext context, List<Widget> children);
}
