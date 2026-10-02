import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/surface_edit_state.dart';
import 'package:finance_app/components/section/section_component.dart';
import 'package:finance_app/components/surface_actions.dart';
import 'package:finance_app/components/surface_edits.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/a2ui_fixtures.dart';
import '../helpers/fixtures.dart';
import 'surface_harness.dart';

/// Edits and taps are scoped to the component that raised them, and a host
/// with no callbacks renders every component read-only.
void main() {
  final surface = surfaceOf(
    surfaceEvent(
      surfaceId: 's-0',
      component: 'HoldingsSummary',
      payload: holdingsAllocationExample,
      options: const <String, Object?>{'top_n': 5},
    ),
  );

  testWidgets('no callbacks, no scopes: the surface is read-only', (
    tester,
  ) async {
    await pumpSurface(tester, surface);
    expect(find.byType(SurfaceEdits), findsNothing);
    expect(find.byType(SurfaceActions), findsNothing);
  });

  testWidgets('the edit scope carries the options and the edit state', (
    tester,
  ) async {
    final edits = <(String, String, String)>[];
    final actions = <(String, SurfaceActionRequest)>[];
    await pumpSurface(
      tester,
      surface,
      edits: <String, SurfaceEditState>{
        editKey('s-0', 'root'): const SurfaceEditState(
          pendingOption: 'group_by',
          rejection: 'no',
        ),
      },
      onOptionChanged: (id, option, value) => edits.add((id, option, value)),
      onAction: (id, request) => actions.add((id, request)),
    );
    final scope = tester.widget<SurfaceEdits>(find.byType(SurfaceEdits));
    expect(scope.options, <String, Object?>{'top_n': 5});
    expect(scope.pendingOption, 'group_by');
    expect(scope.rejection, 'no');
    scope.onOptionChanged('group_by', 'class');
    expect(edits.single, ('root', 'group_by', 'class'));
    tester
        .widget<SurfaceActions>(find.byType(SurfaceActions))
        .onAction(const SurfaceActionRequest(action: 'drill_attribution'));
    expect(actions.single.$1, 'root');
  });

  testWidgets('a Section lays its children out in order, spaced', (
    tester,
  ) async {
    final summary = v1Example('surface.portfolio_summary.json');
    final create =
        (decodeAgentMessage(
              (summary['data']! as List<Object?>).single,
            ) as DecodedMessage).message
            as CreateSurface;
    final rootData = create.dataModel['root'];
    final sectioned = const Surface(id: 's')
        .withComponents(<ComponentNode>[
          const ComponentNode(
            id: 'root',
            component: 'Section',
            children: <String>['a', 'b'],
          ),
          const ComponentNode(
            id: 'a',
            component: 'PortfolioSummary',
            dataPath: '/a',
          ),
          const ComponentNode(
            id: 'b',
            component: 'PortfolioSummary',
            dataPath: '/b',
          ),
        ])
        .withData('/a', rootData)
        .withData('/b', rootData);
    await pumpSurface(tester, sectioned);
    expect(find.text(r'$482,915.20'), findsNWidgets(2));
    final gaps = tester.widgetList<SizedBox>(
      find.descendant(
        of: find.byType(Column).first,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.height == SectionComponent.gap,
        ),
      ),
    );
    expect(gaps, isNotEmpty);
  });
}
