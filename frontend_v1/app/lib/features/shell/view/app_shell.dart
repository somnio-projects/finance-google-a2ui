import 'package:finance_app/features/shell/view/shell_tab_bar.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The phone-shaped frame every tab sits in (spec 0026).
///
/// The design is a 390-point phone. On a phone this fills the screen; on a
/// wide viewport it stays a phone-width column on the design's page colour
/// rather than stretching a card to 1200 points — a stretched card is not
/// the same design at a different size, it is a different design.
class AppShell extends StatelessWidget {
  /// Creates the shell around go_router's branch stack.
  const AppShell({required this.navigationShell, super.key});

  /// The widest the column grows.
  static const double maxWidth = 430;

  /// The stack of tab branches go_router maintains.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return ColoredBox(
      color: tokens.page,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Scaffold(
            backgroundColor: tokens.page,
            body: navigationShell,
            bottomNavigationBar: ShellTabBar(
              currentIndex: navigationShell.currentIndex,
              onSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
