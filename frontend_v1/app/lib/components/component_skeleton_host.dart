import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/skeleton/surface_skeleton.dart';
import 'package:flutter/widgets.dart';

/// Draws the skeleton of whichever component claims [view], while its payload
/// is still on the way.
///
/// The counterpart of `ComponentHost` for the moment before there is a
/// payload: the same registry, the same lookup, so the placeholder a surface
/// shows is the one its component drew for itself. A view this build does
/// not render yet gets the Assistant's generic surface — the host does not
/// guess a shape for a component it has never seen.
class ComponentSkeletonHost extends StatelessWidget {
  /// Draws the skeleton for [view], looked up in [registry].
  const ComponentSkeletonHost({
    required this.registry,
    required this.view,
    super.key,
  });

  /// Where the component for [view] is looked up.
  final ComponentRegistry registry;

  /// The view id the surface will bind once it lands.
  final String view;

  @override
  Widget build(BuildContext context) {
    final component = registry.lookup(view);
    if (component == null) return const SurfaceSkeleton();
    return component.skeleton(context);
  }
}
