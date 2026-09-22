import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:finance_auth/finance_auth.dart';
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
  ///
  /// [surfaceSize] sets the test surface, which is how a responsive component
  /// is pumped at phone and at desktop width. The default 800×600 is small
  /// enough that a tall card overflows, and an overflow is a red test rather
  /// than a layout anybody wanted.
  ///
  /// [reducedMotion] sets `MediaQuery.disableAnimations` over the subject.
  /// Two things need it: asserting the accessibility behaviour itself
  /// (spec frontend/0015 OD-5, 0020 OD-7), and pumping a screen that has a
  /// skeleton on it — a shimmer repeats for ever, so `pumpAndSettle` never
  /// returns while one is animating.
  Future<void> pumpApp(
    Widget widget, {
    ViewsRepository? viewsRepository,
    AgentRepository? agentRepository,
    AuthRepository? authRepository,
    ComponentRegistry? componentRegistry,
    Brightness brightness = Brightness.light,
    Size? surfaceSize,
    ThemeModeController? themeMode,
    bool reducedMotion = false,
  }) async {
    if (surfaceSize != null) {
      await binding.setSurfaceSize(surfaceSize);
      addTearDown(() => binding.setSurfaceSize(null));
    }
    final subject = reducedMotion ? _StillMotion(child: widget) : widget;
    return await pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<dynamic>>[
          if (viewsRepository != null)
            RepositoryProvider<ViewsRepository>.value(value: viewsRepository),
          if (agentRepository != null)
            RepositoryProvider<AgentRepository>.value(value: agentRepository),
          if (authRepository != null)
            RepositoryProvider<AuthRepository>.value(value: authRepository),
          RepositoryProvider<ComponentRegistry>.value(
            value: componentRegistry ?? ComponentRegistry(),
          ),
        ],
        child: themeMode == null
            ? MaterialApp(
                theme: brightness == Brightness.dark
                    ? AppTheme.dark
                    : AppTheme.light,
                home: subject,
              )
            : ThemeModeScope(
                controller: themeMode,
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeMode,
                  builder: (context, mode, _) => MaterialApp(
                    theme: AppTheme.light,
                    darkTheme: AppTheme.dark,
                    themeMode: mode,
                    home: subject,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Turns every animation off over [child], the way the platform setting does.
class _StillMotion extends StatelessWidget {
  const _StillMotion({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  );
}
