import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:flutter/material.dart';

/// The avatar's sheet: who is signed in, and the one way out (G-3).
///
/// Not an artboard of its own — the design's header has the avatar and no
/// menu — so it borrows the Home card's chrome and says the minimum.
Future<void> showSessionSheet(
  BuildContext context, {
  required VoidCallback onSignOut,
}) {
  final tokens = HomeTokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: tokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Signed in to the preview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: tokens.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Signing out clears everything this browser cached.',
            style: TextStyle(fontSize: 12.5, color: tokens.muted),
          ),
          const SizedBox(height: 18),
          const _AppearanceRow(),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(sheet).pop();
                onSignOut();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.loss,
                side: BorderSide(color: tokens.segmentBorder),
                shape: const StadiumBorder(),
              ),
              child: const Text('Sign out'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// `Appearance · System | Light | Dark` — the design's two themes, chosen
/// from inside the app (spec frontend/0010). Hidden when no controller is
/// in scope.
class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow();

  @override
  Widget build(BuildContext context) {
    final controller = ThemeModeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final tokens = HomeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: <Widget>[
          Text(
            'Appearance',
            style: TextStyle(fontSize: 13, color: tokens.muted),
          ),
          const Spacer(),
          for (final mode in ThemeModeController.choices)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _Pill(
                label: ThemeModeController.label(mode),
                selected: controller.value == mode,
                onTap: () => controller.value = mode,
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? tokens.segmentSelected : null,
            border: Border.all(color: tokens.segmentBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? tokens.segmentSelectedText : tokens.segmentText,
            ),
          ),
        ),
      ),
    );
  }
}
