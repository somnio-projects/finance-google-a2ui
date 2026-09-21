import 'package:finance_app/features/portfolio_views/bloc/portfolio_views_bloc.dart';
import 'package:finance_app/features/portfolio_views/view/portfolio_views_view.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The screen that shows a portfolio's rendered views.
///
/// Split in two the way `.claude/rules/flutter/architecture.md` prescribes:
/// the *page* owns the bloc's lifetime, the *view* owns the widgets and reads
/// state. That split is what lets the view be pumped in a test with a seeded
/// bloc and no repository at all — and it is why this is the only file in the
/// feature allowed to read a `ViewsRepository` from the tree
/// (`layering_test.dart::only a page resolves a repository from the widget
/// tree`).
class PortfolioViewsPage extends StatelessWidget {
  /// Creates the page.
  const PortfolioViewsPage({required this.views, super.key});

  /// The view ids to request, sourced from the backend's catalog (N-6).
  final List<String> views;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PortfolioViewsBloc>(
      create: (context) =>
          PortfolioViewsBloc(viewsRepository: context.read<ViewsRepository>())
            ..add(PortfolioViewsRequested(views: views)),
      child: const PortfolioViewsView(),
    );
  }
}
