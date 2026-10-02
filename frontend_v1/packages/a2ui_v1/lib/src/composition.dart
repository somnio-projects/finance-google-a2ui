import 'package:a2ui_v1/src/catalog.dart';
import 'package:a2ui_v1/src/component_node.dart';
import 'package:a2ui_v1/src/protocol.dart';
import 'package:a2ui_v1/src/renderer_message.dart';
import 'package:a2ui_v1/src/surface.dart';
import 'package:equatable/equatable.dart';

/// One node of the tree a renderer draws, with its admitted children.
final class RenderNode extends Equatable {
  /// Creates the node.
  const RenderNode(this.node, [this.children = const <RenderNode>[]]);

  /// The component, as the agent sent it.
  final ComponentNode node;

  /// The children that passed the composition rules and have arrived.
  final List<RenderNode> children;

  @override
  List<Object?> get props => <Object?>[node, children];
}

/// The drawable part of a surface and what was refused on the way.
final class SurfaceTree extends Equatable {
  /// Creates the tree.
  const SurfaceTree({this.root, this.errors = const <RendererError>[]});

  /// `root` and everything admitted under it, or `null` while `root` is
  /// still buffered — or when `root` itself was refused.
  final RenderNode? root;

  /// One error per refused node: `UNALLOWED_PARENT`, `UNALLOWED_CHILD`, or
  /// `VALIDATION_FAILED` for a type the catalog does not declare or a cycle.
  final List<RendererError> errors;

  @override
  List<Object?> get props => <Object?>[root, errors];
}

/// Walks [surface] from the implicit `Surface` container down, admitting each
/// edge only when **both** sides allow it, and returns what may be drawn.
///
/// A refused node is dropped **with its subtree** and reported; its siblings
/// still render (spec `frontend_v1/0001` AC-3). A child id that has not
/// arrived yet is skipped silently — that is progressive rendering, not an
/// error, and the next `updateComponents` fills it in.
SurfaceTree composeTree(Surface surface, Catalog catalog) {
  final root = surface.components[A2uiProtocol.rootId];
  if (root == null) return const SurfaceTree();
  final errors = <RendererError>[];
  final tree = _admit(
    surface,
    catalog,
    A2uiProtocol.surfaceComponent,
    root,
    <String>{},
    errors,
  );
  return SurfaceTree(root: tree, errors: errors);
}

RenderNode? _admit(
  Surface surface,
  Catalog catalog,
  String parentType,
  ComponentNode node,
  Set<String> ancestors,
  List<RendererError> errors,
) {
  RendererError refuse(String code, String message) => RendererError(
    code: code,
    message: message,
    surfaceId: surface.id,
    path: '/components/${node.id}/component',
  );
  final rules = catalog.components[node.component];
  if (rules == null) {
    errors.add(
      refuse(
        'VALIDATION_FAILED',
        '"${node.component}" is not in catalog ${catalog.catalogId}',
      ),
    );
    return null;
  }
  if (ancestors.contains(node.id)) {
    errors.add(refuse('VALIDATION_FAILED', '"${node.id}" contains itself'));
    return null;
  }
  if (!rules.acceptsParent(parentType)) {
    errors.add(
      refuse(
        'UNALLOWED_PARENT',
        '${node.component} may not be placed under $parentType',
      ),
    );
    return null;
  }
  final parentRules = catalog.components[parentType];
  if (parentRules != null && !parentRules.acceptsChild(node.component)) {
    errors.add(
      refuse(
        'UNALLOWED_CHILD',
        '$parentType may not contain ${node.component}',
      ),
    );
    return null;
  }
  final lineage = <String>{...ancestors, node.id};
  return RenderNode(node, <RenderNode>[
    for (final id in node.children)
      if (surface.components[id] case final child?)
        ?_admit(surface, catalog, node.component, child, lineage, errors),
  ]);
}
