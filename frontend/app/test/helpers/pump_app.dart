import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

export 'fixtures.dart';

/// Pumps [widget] inside the app's theme and providers.
///
/// Every widget test goes through this, so a test exercises the real theme and
/// the real provider wiring rather than a bare `MaterialApp` that would hide a
/// missing `ThemeExtension` or an unprovided repository.
extension PumpApp on WidgetTester {
  /// Pumps [widget] with optional dependencies injected above it.
  /// [brightness] picks which of the two real themes wraps the subject. A
  /// chart's palette differs between them, so a golden or a colour assertion
  /// that can only reach one of the two is only half a check.
  Future<void> pumpApp(
    Widget widget, {
    ViewsRepository? viewsRepository,
    AgentRepository? agentRepository,
    ComponentRegistry? componentRegistry,
    Brightness brightness = Brightness.light,
  }) {
    return pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<dynamic>>[
          if (viewsRepository != null)
            RepositoryProvider<ViewsRepository>.value(value: viewsRepository),
          if (agentRepository != null)
            RepositoryProvider<AgentRepository>.value(value: agentRepository),
          RepositoryProvider<ComponentRegistry>.value(
            value: componentRegistry ?? ComponentRegistry(),
          ),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
          home: widget,
        ),
      ),
    );
  }
}
