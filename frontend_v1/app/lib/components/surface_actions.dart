import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Where a surface's tap goes (spec frontend/0011 OD-4).
///
/// The conversation page puts one of these above its transcript; a component
/// that declares an action asks for it with [maybeOf] and sends the tap
/// through. A surface rendered anywhere else finds none and keeps its tap to
/// itself — the same widget, no second rendering path, and the `ViewComponent`
/// seam untouched.
class SurfaceActions extends InheritedWidget {
  /// Creates the scope.
  const SurfaceActions({
    required this.onAction,
    required super.child,
    super.key,
  });

  /// Sends a registered action with its published scalars.
  final ValueChanged<SurfaceActionRequest> onAction;

  /// The scope above [context], or null when there is none.
  static SurfaceActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SurfaceActions>();

  @override
  bool updateShouldNotify(SurfaceActions oldWidget) =>
      onAction != oldWidget.onAction;
}
