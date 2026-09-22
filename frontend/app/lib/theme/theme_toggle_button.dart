import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:flutter/material.dart';

/// A quiet round button that flips between the two themes.
///
/// It reads the theme that is *showing* (`Theme.of`), not the controller's
/// value, so from `system` it offers the opposite of whatever the device
/// chose and the choice becomes explicit from then on. Draws nothing when no
/// [ThemeModeScope] is above it.
class ThemeToggleButton extends StatelessWidget {
  /// Creates the button.
  const ThemeToggleButton({super.key});

  /// Where the button lives, for tests.
  static const Key toggleKey = Key('theme-toggle');

  @override
  Widget build(BuildContext context) {
    final controller = ThemeModeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: toggleKey,
      color: scheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: dark
            ? 'Switch to light appearance'
            : 'Switch to dark appearance',
        onPressed: () =>
            controller.value = dark ? ThemeMode.light : ThemeMode.dark,
        icon: Icon(
          dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          size: 20,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
