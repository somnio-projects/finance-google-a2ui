import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/portfolio_views/bloc/portfolio_views_bloc.dart';
import 'package:finance_app/theme/app_spacing.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Renders whatever [PortfolioViewsBloc] currently holds.
class PortfolioViewsView extends StatelessWidget {
  /// Creates the view.
  const PortfolioViewsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      body: BlocBuilder<PortfolioViewsBloc, PortfolioViewsState>(
        builder: (context, state) => switch (state.status) {
          PortfolioViewsStatus.initial || PortfolioViewsStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          PortfolioViewsStatus.failure => _FailureView(
            message: state.failure?.message ?? 'The request failed.',
            code: state.failure?.code ?? 'unknown',
          ),
          PortfolioViewsStatus.success => _SurfaceList(
            rendered: state.rendered,
          ),
        },
      ),
    );
  }
}

class _SurfaceList extends StatelessWidget {
  const _SurfaceList({required this.rendered});

  final RenderedViews? rendered;

  @override
  Widget build(BuildContext context) {
    final envelope = rendered;
    final spacing = AppSpacing.of(context);
    if (envelope == null || envelope.views.isEmpty) {
      return const Center(child: Text('No views were returned.'));
    }
    final registry = context.read<ComponentRegistry>();
    final payloads = envelope.views.values.toList();
    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: payloads.length,
      separatorBuilder: (_, _) => SizedBox(height: spacing.md),
      itemBuilder: (context, index) =>
          ComponentHost(registry: registry, payload: payloads[index]),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.code});

  final String message;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppSpacing.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
            SizedBox(height: spacing.sm),
            // Shown verbatim. For a `ProblemFailure` this is the backend's
            // own safe `detail`; for the others it is wording this app
            // owns. Never a stack trace, a library message or a
            // credential — `finance_api_client.dart` is where that is
            // kept true, and a test holds it.
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: spacing.xs),
            Text(code, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
