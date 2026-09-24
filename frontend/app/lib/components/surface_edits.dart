import 'package:flutter/widgets.dart';

/// The scope a host puts around a surface whose options a person may edit
/// (GGU-113, spec frontend/0026).
///
/// The counterpart of `SurfaceActions` for the other half of ADR-K D-11: a
/// tap on a surface sends an **action** to the agent; an edit of a declared
/// option **re-requests the same view** with that option changed. A component
/// reads this scope and, finding one, renders its declared inputs as live
/// controls; finding none, it renders them read-only — which is what the
/// Assistant did for every ticket until this scope existed, because
/// `ComponentHost` gave the component nothing to honour an edit with.
///
/// [pendingOption] and [rejection] are the host's answer to the last edit:
/// which option is being re-rendered, and the backend's sentence when it
/// refused one (a 422 for a size that is not a number, say). Both are drawn
/// by the component, never composed by it.
class SurfaceEdits extends InheritedWidget {
  /// Creates the scope.
  const SurfaceEdits({
    required this.onOptionChanged,
    required super.child,
    this.pendingOption,
    this.rejection,
    super.key,
  });

  /// Called with the declared option's name and its new value, verbatim.
  final void Function(String option, String value) onOptionChanged;

  /// The option whose re-render is in flight, or null when none is.
  final String? pendingOption;

  /// The backend's own sentence for the last refused edit, or null.
  final String? rejection;

  /// The nearest scope, or null where no host can honour an edit.
  static SurfaceEdits? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SurfaceEdits>();

  @override
  bool updateShouldNotify(SurfaceEdits oldWidget) =>
      onOptionChanged != oldWidget.onOptionChanged ||
      pendingOption != oldWidget.pendingOption ||
      rejection != oldWidget.rejection;
}
