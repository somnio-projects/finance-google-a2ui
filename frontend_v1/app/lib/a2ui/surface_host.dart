import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/surface_edit_state.dart';
import 'package:finance_app/a2ui/surface_node_view.dart';
import 'package:finance_app/a2ui/surface_notice.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/skeleton/surface_skeleton.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// Called when the component [componentId] edits a declared option.
typedef SurfaceOptionEdit = void Function(
  String componentId,
  String option,
  String value,
);

/// Called when the component [componentId] raises a surface action.
typedef SurfaceActionRaised = void Function(
  String componentId,
  SurfaceActionRequest request,
);

/// Draws one A2UI v1.0 surface (spec `frontend_v1/0001`, ADR-M D-3/D-4).
///
/// It walks the adjacency list from the implicit `Surface` down through
/// [composeTree], which admits each edge only when the catalog's
/// composition rules allow both sides of it, and hands every node to
/// [SurfaceNodeView]. What was refused is not drawn and is **reported** under
/// the part that was (AC-3) — the surface degrades, it does not disappear.
///
/// Until `root` arrives the surface is buffered and shows the generic
/// skeleton: the adjacency-list model's rule that nothing is visible before
/// the root, drawn as the design's wait rather than as nothing.
class SurfaceHost extends StatelessWidget {
  /// Draws [surface] against [catalog] with the components in [registry].
  const SurfaceHost({
    required this.surface,
    required this.catalog,
    required this.registry,
    this.edits = const <String, SurfaceEditState>{},
    this.onOptionChanged,
    this.onAction,
    super.key,
  });

  /// The surface, as the processor left it.
  final Surface surface;

  /// The composition rules to enforce.
  final Catalog catalog;

  /// Component name / view id → widget.
  final ComponentRegistry registry;

  /// Each component's last edit, by [editKey].
  final Map<String, SurfaceEditState> edits;

  /// Where an edit goes; null renders every input read-only.
  final SurfaceOptionEdit? onOptionChanged;

  /// Where a tap goes; null keeps every tap to its component.
  final SurfaceActionRaised? onAction;

  @override
  Widget build(BuildContext context) {
    if (!surface.hasRoot) return const SurfaceSkeleton();
    final tree = composeTree(surface, catalog);
    final root = tree.root;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (root != null) SurfaceNodeView(host: this, node: root),
        if (tree.errors.isNotEmpty) SurfaceNotice(errors: tree.errors),
      ],
    );
  }
}
