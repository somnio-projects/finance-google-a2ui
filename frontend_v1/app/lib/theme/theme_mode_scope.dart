import 'package:flutter/material.dart';

/// Which of the two measured themes the app shows (spec frontend/0010).
///
/// The design ships every screen twice, light and dark, and both must be
/// reachable from inside the app rather than only by changing the device.
/// This is the one place that choice lives; the tokens files stay untouched
/// because they already carry both palettes.
class ThemeModeController extends ValueNotifier<ThemeMode> {
  /// Starts on the device's setting unless a test says otherwise.
  ThemeModeController() : super(ThemeMode.system);

  /// The choices, in the order the sheet lists them.
  static const List<ThemeMode> choices = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  /// The word for [mode]. App chrome, not a payload: nothing here is a figure
  /// or a sentence the backend owns.
  static String label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

/// Hands the controller to the tree without a provider, so a widget outside
/// the app's providers — the sign-in screen, a sheet — can still reach it, and
/// a test that pumps one widget with no controller simply sees none.
class ThemeModeScope extends InheritedNotifier<ThemeModeController> {
  /// Creates the scope.
  const ThemeModeScope({
    required ThemeModeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// The controller above [context], or null when the tree has none.
  static ThemeModeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>()?.notifier;
}
