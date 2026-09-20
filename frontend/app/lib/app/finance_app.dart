import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The widget tree's root.
///
/// It publishes the dependencies the tree reads and nothing else: it builds
/// none of them. Construction happens once, in `bootstrap.dart`, so this
/// widget can be pumped in a test with fakes and no network.
class FinanceApp extends StatelessWidget {
  /// Creates the app root over already-constructed dependencies.
  const FinanceApp({
    required this.router,
    required this.viewsRepository,
    required this.componentRegistry,
    super.key,
  });

  /// The route table.
  final GoRouter router;

  /// The repository blocs below this point resolve with `context.read`.
  final ViewsRepository viewsRepository;

  /// The component registry `ComponentHost` resolves with `context.read`.
  final ComponentRegistry componentRegistry;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<ViewsRepository>.value(value: viewsRepository),
        RepositoryProvider<ComponentRegistry>.value(value: componentRegistry),
      ],
      child: MaterialApp.router(
        title: 'Finance A2UI',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
