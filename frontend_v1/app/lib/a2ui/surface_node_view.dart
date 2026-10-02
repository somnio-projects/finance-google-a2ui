import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/surface_edit_state.dart';
import 'package:finance_app/a2ui/surface_host.dart';
import 'package:finance_app/a2ui/surface_notice.dart';
import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/surface_actions.dart';
import 'package:finance_app/components/surface_edits.dart';
import 'package:finance_app/skeleton/surface_skeleton.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// One admitted node of a surface, and its admitted children.
///
/// Every node is wrapped in [Semantics] from its `accessibility` (AC-7). A
/// layout node arranges its children; a bound node renders
/// `dataModel[<path>].payload` through the **same** `ComponentHost` a REST
/// read goes through — the payload is the one `GET /v1/portfolios/current/
/// views` serves, so nothing is transformed (ADR-M D-3, ADR-K) — and any
/// children it carries (a ticket's payoff, ADR-M D-4) follow it.
class SurfaceNodeView extends StatelessWidget {
  /// Draws [node] for [host].
  const SurfaceNodeView({required this.host, required this.node, super.key});

  /// The surface's host, for its registry, edits and callbacks.
  final SurfaceHost host;

  /// The node to draw.
  final RenderNode node;

  @override
  Widget build(BuildContext context) {
    final component = node.node;
    final children = <Widget>[
      for (final child in node.children)
        SurfaceNodeView(host: host, node: child),
    ];
    final layout = host.registry.layout(component.component);
    final body = layout != null
        ? layout.build(context, children)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _bound(context, component),
              for (final child in children) ...<Widget>[
                const SizedBox(height: 12),
                child,
              ],
            ],
          );
    return Semantics(
      container: true,
      label: component.accessibility.label,
      hint: component.accessibility.description,
      child: body,
    );
  }

  Widget _bound(BuildContext context, ComponentNode component) {
    final path = component.dataPath;
    final bound = path == null ? null : host.surface.read(path);
    // Progressive rendering: the node is here, its data is not yet.
    if (bound is! Map<String, Object?> || bound['view'] is! String) {
      return const SurfaceSkeleton();
    }
    final view = bound['view']! as String;
    final registered = host.registry.lookup(view);
    if (registered != null && registered.a2uiComponent != component.component) {
      return SurfaceNotice.single(
        '${component.component} does not render "$view"',
      );
    }
    final ViewPayload payload;
    try {
      payload = ViewPayload.fromJson(bound['payload']);
    } on PayloadContractException catch (error) {
      return SurfaceNotice.single(error.failure.message);
    }
    final options = bound['options'];
    final state = host.edits[editKey(host.surface.id, component.id)];
    Widget child = ComponentHost(registry: host.registry, payload: payload);
    final edit = host.onOptionChanged;
    if (edit != null) {
      child = SurfaceEdits(
        onOptionChanged: (option, value) => edit(component.id, option, value),
        pendingOption: state?.pendingOption,
        rejection: state?.rejection,
        options: options is Map<String, Object?>
            ? options
            : const <String, Object?>{},
        child: child,
      );
    }
    final act = host.onAction;
    if (act == null) return child;
    return SurfaceActions(
      onAction: (request) => act(component.id, request),
      child: child,
    );
  }
}
