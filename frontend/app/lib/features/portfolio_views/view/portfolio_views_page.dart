import 'package:finance_app/components/component_registry.dart';
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
  const PortfolioViewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // **The requested ids come from the registry, not from a literal here or
    // in the router.** Every id is one a component declared for itself, so
    // they are still catalog ids the client never invents (N-6) — and a
    // component that registers is now reachable by construction instead of
    // after somebody remembers to edit a second list.
    // MUTATION A: the defect this PR fixed — a hardcoded list that does not
    // agree with the registry. `app_router_test.dart::every registered
    // component is reachable from the route` must go red.
    final views = <String>['not.registered.v1'];
    return BlocProvider<PortfolioViewsBloc>(
      create: (context) =>
          PortfolioViewsBloc(viewsRepository: context.read<ViewsRepository>())
            ..add(PortfolioViewsRequested(views: views)),
      child: const PortfolioViewsView(),
    );
  }
}
