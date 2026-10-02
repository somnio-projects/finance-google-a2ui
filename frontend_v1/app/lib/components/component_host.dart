import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/theme/app_spacing.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// Renders one payload with whichever component claims its view id.
///
/// This widget is the *only* place that decides what to do when a payload has
/// no component or breaks its contract, which is why neither case needs a
/// branch anywhere else.
class ComponentHost extends StatelessWidget {
  /// Renders [payload] using [registry].
  const ComponentHost({
    required this.registry,
    required this.payload,
    super.key,
  });

  /// Where the component for [payload] is looked up.
  final ComponentRegistry registry;

  /// The rendered projection to bind.
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final component = registry.lookup(payload.view);
    if (component == null) {
      return _NoticeTile(
        icon: Icons.extension_outlined,
        title: 'No component for "${payload.view}"',
        detail:
            'The backend served a view this build does not render yet. '
            'Adding one edits no existing file — see frontend/CLAUDE.md.',
      );
    }
    try {
      return component.build(context, payload);
    } on PayloadContractException catch (error) {
      // N-3: a field the component binds and the payload does not carry is a
      // backend defect to raise, not a value to reconstruct. Showing it beats
      // logging it, because the person looking at the screen is the person who
      // can raise it.
      return _NoticeTile(
        icon: Icons.report_problem_outlined,
        title: 'Contract violation in "${payload.view}"',
        detail: error.failure.message,
      );
    }
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = AppSpacing.of(context);
    return Card(
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colors.onSurfaceVariant),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: spacing.xs),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
