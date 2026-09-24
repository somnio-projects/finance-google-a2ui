import 'package:finance_app/features/shell/view/pinned_header.dart';
import 'package:finance_app/features/shell/view/tab_search_field.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The tabs' app bar as the design draws it: the title at 22/500 with the
/// quiet trailing icons the tab actually has.
///
/// It used to hard-code two icons that raised *"… is not part of this
/// preview yet."* (spec frontend/0009 OD-7, superseded by 0018). The
/// controls are now parameters, which is what lets the Activity bar carry
/// search alone — its `kind` chips already are its filter, and a second
/// control setting the same option would be two sources of truth for one
/// piece of state (0018 OD-2).
class TabAppBar extends StatefulWidget {
  /// Creates the bar.
  const TabAppBar({required this.title, this.search, this.onFilter, super.key});

  /// The tab's title — the payload's, verbatim.
  final String title;

  /// The search this tab offers, or null when it offers none.
  final TabSearch? search;

  /// What the filter icon opens, or null when the tab has no filter icon.
  final VoidCallback? onFilter;

  @override
  State<TabAppBar> createState() => _TabAppBarState();
}

class _TabAppBarState extends State<TabAppBar> {
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return PinnedHeader(
      color: tokens.header,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 12, 4),
        child: Row(children: _children(tokens)),
      ),
    );
  }

  List<Widget> _children(HomeTokens tokens) {
    final search = widget.search;
    if (_searching && search != null) {
      return <Widget>[
        Expanded(
          child: TabSearchField(
            hint: widget.title,
            search: search,
            onClose: () => _close(search),
          ),
        ),
      ];
    }
    return <Widget>[
      Expanded(
        child: Text(
          widget.title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: tokens.text,
          ),
        ),
      ),
      if (search != null)
        TabBarIcon(
          icon: Icons.search_rounded,
          label: 'Search ${widget.title}',
          onPressed: () => setState(() => _searching = true),
        ),
      if (widget.onFilter case final onFilter?)
        TabBarIcon(
          icon: Icons.tune_rounded,
          label: 'Filter ${widget.title}',
          onPressed: onFilter,
        ),
    ];
  }

  /// Closing clears the query: a hidden filter that is still applied is the
  /// oldest defect in this kind of control (spec frontend/0018 OD-5).
  void _close(TabSearch search) {
    setState(() => _searching = false);
    search.onChanged('');
  }
}

/// The tab's failure state: the backend's sentence, centred.
class TabFailure extends StatelessWidget {
  /// Creates the state.
  const TabFailure({required this.message, super.key});

  /// The failure's words, verbatim.
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

/// What a tab shows instead of its list when a filter kept nothing.
///
/// The sentence is the **payload's** (`empty`), never one composed here:
/// "No results for …" is a server-written string under N-9, which is why
/// the field exists (spec frontend/0018 OD-6).
class TabEmpty extends StatelessWidget {
  /// Creates the state.
  const TabEmpty({required this.message, super.key});

  /// The payload's `empty`, verbatim.
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, color: tokens.segmentText),
      ),
    );
  }
}
