/// The header surfaces driven from a stubbed bloc rather than a stubbed
/// repository: the Assistant and the catalog's two pages.
///
/// The claim under test is where a header sits, so the state under it is
/// stated outright. A scripted agent turn would make the transcript's length
/// a function of stream timing, and the catalog's two blocs fetch from two
/// different endpoints — neither belongs in a geometry test.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/catalog/bloc/catalog_bloc.dart';
import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/view/catalog_detail_view.dart';
import 'package:finance_app/features/catalog/view/catalog_view.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_app/features/conversation/bloc/voice_input_bloc.dart';
import 'package:finance_app/features/conversation/view/conversation_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';
import '../catalog/catalog_fixtures.dart';
import 'header_scroll_harness.dart';

class _MockCatalogBloc extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc;

class _MockDetailBloc extends MockBloc<CatalogDetailEvent, CatalogDetailState>
    implements CatalogDetailBloc;

class _MockConversationBloc
    extends MockBloc<ConversationEvent, ConversationState>
    implements ConversationBloc;

class _MockVoiceBloc extends MockBloc<VoiceInputEvent, VoiceInputState>
    implements VoiceInputBloc;

/// How many bubbles make the transcript taller than a phone.
const int assistantEntries = 24;

/// Pumps the Assistant over a transcript long enough to scroll.
Future<void> pumpAssistant(WidgetTester tester) async {
  final conversation = _MockConversationBloc();
  final voice = _MockVoiceBloc();
  when(() => conversation.state).thenReturn(
    ConversationState(
      entries: <ConversationEntry>[
        for (var index = 0; index < assistantEntries; index++)
          UserSaid('message $index'),
      ],
    ),
  );
  when(() => voice.state).thenReturn(const VoiceInputState());
  await tester.pumpApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<ConversationBloc>.value(value: conversation),
        BlocProvider<VoiceInputBloc>.value(value: voice),
      ],
      child: const ConversationView(),
    ),
    surfaceSize: phone,
  );
  await tester.pumpAndSettle();
}

/// Pumps the catalog index over the generated snapshot.
Future<void> pumpCatalogIndex(WidgetTester tester) async {
  final bloc = _MockCatalogBloc();
  when(() => bloc.state).thenReturn(
    CatalogState(status: CatalogStatus.success, catalog: snapshotCatalog()),
  );
  await tester.pumpApp(
    BlocProvider<CatalogBloc>.value(value: bloc, child: const CatalogView()),
    componentRegistry: buildRegistry(),
    surfaceSize: phone,
  );
  await tester.pumpAndSettle();
}

/// Pumps one component's detail page over the generated snapshot.
Future<void> pumpCatalogDetail(WidgetTester tester) async {
  final bloc = _MockDetailBloc();
  when(() => bloc.state).thenReturn(
    CatalogDetailState(
      status: CatalogDetailStatus.success,
      entry: snapshotEntry('TaxLotTable'),
    ),
  );
  await tester.pumpApp(
    BlocProvider<CatalogDetailBloc>.value(
      value: bloc,
      child: const CatalogDetailView(),
    ),
    componentRegistry: buildRegistry(),
    surfaceSize: phone,
  );
  await tester.pumpAndSettle();
}
