import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/action_clock.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a2ui_fixtures.dart';

export 'a2ui_fixtures.dart';
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
  /// [speechRecognizer] is the dictation engine the Assistant's mic drives.
  /// Left out, it is `UnsupportedSpeechRecognizer` — the state a test that is
  /// not about voice should see, because that is what the VM really is.
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
    Catalog? catalog,
    ActionClock actionClock = const FixedActionClock(),
    SpeechRecognizer? speechRecognizer,
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
          // The A2UI v1.0 catalog and the action clock the Assistant's
          // surfaces resolve: the bundled catalog unless a test brings its
          // own, and a clock a test can predict.
          RepositoryProvider<Catalog>.value(value: catalog ?? bundledCatalog()),
          RepositoryProvider<ActionClock>.value(value: actionClock),
          // Always provided, never optional: the composer's mic resolves it
          // on every Assistant pump, and the default is the honest no-op
          // rather than an engine no test could drive (spec 0022 OD-2).
          RepositoryProvider<SpeechRecognizer>.value(
            value: speechRecognizer ?? const UnsupportedSpeechRecognizer(),
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
