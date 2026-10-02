import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Where a location this app has no screen for lands (GGU-112).
///
/// It used to land on go_router's own error widget: black text on white, no
/// theme, no chrome — a page that looked like the site was down rather than
/// like a wrong turn inside it. This is the same wrong turn, drawn in the
/// app's own colours, with the one control that helps: the way Home.
///
/// It says nothing about *why*. The location is echoed so a reader who typed
/// it can see the typo; no exception text reaches the screen (§4 of the
/// architecture rules — a library message is never shown to a user).
class NotFoundPage extends StatelessWidget {
  /// Creates the page for [location], the path that matched nothing.
  const NotFoundPage({required this.location, super.key});

  /// The title.
  static const String title = 'There is no such page';

  /// The control's words.
  static const String goHome = 'Go to Home';

  /// The path that matched nothing, shown back verbatim.
  final String location;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.page,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: tokens.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  location,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Roboto Mono',
                    color: tokens.muted,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => context.go(AppRoutes.home),
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accent,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(goHome),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
