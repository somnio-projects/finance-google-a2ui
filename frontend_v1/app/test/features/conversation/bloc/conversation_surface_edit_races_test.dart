import 'dart:async';

import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'conversation_harness.dart';
import 'surface_edit_harness.dart';

/// Two edits of one component in flight at once (spec 0026 OD-3): the
/// second merges onto the first's intent, and only the newest call's answer
/// may settle the component's edit state.
void main() {
  late MockAgentRepository agent;
  late ConversationBloc bloc;
  late List<StreamController<AgentEvent>> answers;

  setUp(() async {
    agent = MockAgentRepository();
    bloc = await editableBloc(agent);
    answers = <StreamController<AgentEvent>>[];
    when(
      () => agent.startTurn(
        text: any(named: 'text'),
        messages: any(named: 'messages'),
        messageId: any(named: 'messageId'),
        contextId: any(named: 'contextId'),
      ),
    ).thenAnswer((_) {
      final answer = StreamController<AgentEvent>();
      answers.add(answer);
      return answer.stream;
    });
  });

  tearDown(() => bloc.close());

  Future<void> twoEdits() async {
    bloc
      ..add(topNEdit)
      ..add(
        const ConversationSurfaceEdited(
          surfaceId: exampleSurfaceId,
          componentId: 'root',
          option: 'group_by',
          value: 'class',
        ),
      );
    await pumpEventQueue();
  }

  test('the second edit carries the first one with it', () async {
    await twoEdits();
    final calls = sentMessages(agent).cast<CallAgentFunction>();
    expect(calls.last.args['options'], <String, Object?>{
      'top_n': '3',
      'group_by': 'class',
    });
    expect(bloc.state.edits[exampleEditKey]?.pendingOption, 'group_by');
  });

  test('a stale answer cannot settle the newer edit', () async {
    await twoEdits();
    answers.first
      ..add(refusal('call-0'))
      ..add(success('call-0', const <String, Object?>{'top_n': '3'}));
    await answers.first.close();
    await pumpEventQueue();
    expect(bloc.state.edits[exampleEditKey]?.pendingOption, 'group_by');

    answers.last.add(
      success('call-1', const <String, Object?>{
        'top_n': '3',
        'group_by': 'class',
      }),
    );
    await answers.last.close();
    await pumpEventQueue();
    expect(bloc.state.edits, isEmpty);
    expect(
      bloc.state.surfaces[exampleSurfaceId]!.read('/root/options/group_by'),
      'class',
    );
  });
}
