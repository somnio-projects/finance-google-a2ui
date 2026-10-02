import 'package:finance_app/a2ui/surface_host.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_app/features/conversation/view/agent_surface_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../bloc/conversation_harness.dart';

void main() {
  testWidgets('an entry whose surface is gone draws nothing', (tester) async {
    // A deleteSurface removes the entry and the surface in one state, so
    // this is a frame that should never be seen — drawn as nothing rather
    // than as a crash if it ever is.
    final bloc = buildBloc(events: const []);
    addTearDown(bloc.close);
    await tester.pumpApp(
      BlocProvider<ConversationBloc>.value(
        value: bloc,
        child: const AgentSurfaceTile(surfaceId: 'gone'),
      ),
    );
    expect(find.byType(SurfaceHost), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });
}
