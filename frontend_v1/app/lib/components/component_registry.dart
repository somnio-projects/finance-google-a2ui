import 'package:finance_app/components/view_component.dart';

/// Maps a frozen view id to the component that renders it.
///
/// The registry is a `Map`, not a `switch`: a component is *added* to it at
/// composition time from its own module, so adding one edits nothing. The
/// wiring itself lives in the generated `component_manifest.g.dart`, which the
/// gate re-renders and diffs — the same "a generated artefact is gated by
/// regeneration, never by trust" rule the backend's frozen catalog follows
/// (`.claude/rules/ci-conventions.md` §4).
class ComponentRegistry {
  /// Creates an empty registry.
  ComponentRegistry();

  final Map<String, ViewComponent> _components = <String, ViewComponent>{};

  /// Adds [component] under its own [ViewComponent.viewId].
  ///
  /// Throws [StateError] on a duplicate id: two components claiming one view
  /// is a wiring mistake, and silently letting the last one win would make it
  /// invisible until someone noticed the wrong widget on screen.
  void register(ViewComponent component) {
    final existing = _components[component.viewId];
    if (existing != null) {
      throw StateError(
        'view "${component.viewId}" is already served by '
        '${existing.runtimeType}; ${component.runtimeType} cannot also claim '
        'it',
      );
    }
    _components[component.viewId] = component;
  }

  /// The component for [viewId], or `null` when none is registered.
  ///
  /// `null` is an expected answer, not a failure: the backend's catalog grows
  /// on its own schedule, so a client will meet view ids it does not render
  /// yet. The host shows a placeholder rather than crashing.
  ViewComponent? lookup(String viewId) => _components[viewId];

  /// Every registered view id, in registration order.
  Iterable<String> get viewIds => _components.keys;
}
