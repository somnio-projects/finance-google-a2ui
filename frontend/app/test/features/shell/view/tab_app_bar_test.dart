import 'package:finance_app/features/shell/view/tab_app_bar.dart';
import 'package:finance_app/features/shell/view/tab_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group(TabAppBar, () {
    testWidgets('carries only the controls the tab was given', (tester) async {
      await tester.pumpApp(const Scaffold(body: TabAppBar(title: 'Activity')));

      expect(find.text('Activity'), findsOneWidget);
      expect(find.byTooltip('Search Activity'), findsNothing);
      expect(find.byTooltip('Filter Activity'), findsNothing);
    });

    testWidgets('names the tab in each control, for a screen reader', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          body: TabAppBar(
            title: 'Holdings',
            search: TabSearch(query: '', onChanged: (_) {}),
            onFilter: () {},
          ),
        ),
      );

      expect(find.byTooltip('Search Holdings'), findsOneWidget);
      expect(find.byTooltip('Filter Holdings'), findsOneWidget);
    });

    testWidgets('the filter icon calls what it was handed', (tester) async {
      var opened = 0;
      await tester.pumpApp(
        Scaffold(
          body: TabAppBar(title: 'Holdings', onFilter: () => opened++),
        ),
      );

      await tester.tap(find.byTooltip('Filter Holdings'));

      expect(opened, 1);
    });

    testWidgets('the search icon opens a field over the title', (tester) async {
      final typed = <String>[];
      await tester.pumpApp(
        Scaffold(
          body: TabAppBar(
            title: 'Holdings',
            search: TabSearch(query: '', onChanged: typed.add),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Search Holdings'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nvda');

      expect(find.text('Holdings'), findsOneWidget); // now the placeholder
      expect(typed, <String>['nvda']);
    });

    testWidgets('closing the field clears the query (OD-5)', (tester) async {
      final typed = <String>[];
      await tester.pumpApp(
        Scaffold(
          body: TabAppBar(
            title: 'Holdings',
            search: TabSearch(query: 'bond', onChanged: typed.add),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Search Holdings'));
      await tester.pumpAndSettle();
      expect(find.text('bond'), findsOneWidget); // seeded from the option

      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();

      expect(typed, <String>['']);
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Search Holdings'), findsOneWidget);
    });
  });

  group(TabEmpty, () {
    testWidgets('prints the payload sentence and composes none', (
      tester,
    ) async {
      await tester.pumpApp(
        const Scaffold(body: TabEmpty(message: 'No holdings match this.')),
      );

      expect(find.text('No holdings match this.'), findsOneWidget);
    });
  });

  group(TabFailure, () {
    testWidgets('prints the backend sentence', (tester) async {
      await tester.pumpApp(const Scaffold(body: TabFailure(message: 'oh no')));

      expect(find.text('oh no'), findsOneWidget);
    });
  });
}
