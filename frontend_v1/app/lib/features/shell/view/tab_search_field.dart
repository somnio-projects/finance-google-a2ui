import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// What a tab hands the app bar so its search icon can do something.
///
/// The field **sends a declared option**; it never filters a list the client
/// already holds (spec frontend/0018 OD-1, N-10). [onChanged] raises the
/// bloc event, the bloc debounces it, and the rows that come back are the
/// server's, in the order the server sent them.
class TabSearch {
  /// Creates the configuration.
  const TabSearch({required this.query, required this.onChanged});

  /// The `query` option in force, so the field survives a rebuild.
  final String query;

  /// Called with each edit, and with `''` when the field is closed.
  final ValueChanged<String> onChanged;
}

/// The expanded search field: a text box where the title was.
class TabSearchField extends StatefulWidget {
  /// Creates the field.
  const TabSearchField({
    required this.hint,
    required this.search,
    required this.onClose,
    super.key,
  });

  /// Placeholder — the tab's own title, so a reader knows what is searched.
  final String hint;

  /// The query in force and where an edit goes.
  final TabSearch search;

  /// Called when the field is dismissed; the query is cleared with it.
  final VoidCallback onClose;

  @override
  State<TabSearchField> createState() => _TabSearchFieldState();
}

class _TabSearchFieldState extends State<TabSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.search.query,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    // Transparent Material, not decoration: a `TextField` asserts on a
    // missing Material ancestor, and the bar must work wherever it is
    // mounted rather than only inside the shell's `Scaffold`.
    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(fontSize: 16, color: tokens.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: TextStyle(fontSize: 16, color: tokens.segmentText),
              ),
              onChanged: widget.search.onChanged,
            ),
          ),
          IconButton(
            tooltip: 'Close search',
            onPressed: widget.onClose,
            icon: Icon(
              Icons.close_rounded,
              size: 22,
              color: tokens.segmentText,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the app bar's quiet trailing icons.
class TabBarIcon extends StatelessWidget {
  /// Creates the icon button.
  const TabBarIcon({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// The glyph the design draws.
  final IconData icon;

  /// Its tooltip and its semantics label.
  final String label;

  /// What it does — never a snackbar saying it does nothing.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, size: 22, color: tokens.segmentText),
    );
  }
}
