import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// One destination of the shell's tab bar.
class ShellTab {
  /// Creates the destination.
  const ShellTab({required this.label, required this.icon});

  /// The word under the icon.
  final String label;

  /// The glyph.
  final IconData icon;
}

/// The four tabs the design draws, in its order.
const List<ShellTab> shellTabs = <ShellTab>[
  ShellTab(label: 'Home', icon: Icons.web_asset_outlined),
  ShellTab(label: 'Holdings', icon: Icons.bar_chart_rounded),
  ShellTab(label: 'Activity', icon: Icons.schedule_outlined),
  ShellTab(label: 'Assistant', icon: Icons.chat_bubble_outline_rounded),
];

/// The bottom tab bar, measured from `Home.dc.html` (spec 0026 §2).
///
/// Material's `NavigationBar` draws its indicator and label at sizes the
/// design does not use, so this is the design's own shape: a 72px strip with
/// a hairline on top, and behind the selected icon a 60×30 pill at radius 16.
class ShellTabBar extends StatelessWidget {
  /// Creates the bar.
  const ShellTabBar({
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  /// Which tab is showing.
  final int currentIndex;

  /// Called with the index of the tab tapped.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.nav,
        border: Border(top: BorderSide(color: tokens.navBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 14),
          child: Row(
            children: <Widget>[
              for (var index = 0; index < shellTabs.length; index++)
                Expanded(
                  child: _TabItem(
                    tab: shellTabs[index],
                    selected: index == currentIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final color = selected ? tokens.navSelectedText : tokens.navText;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 60,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? tokens.navPill : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(tab.icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
