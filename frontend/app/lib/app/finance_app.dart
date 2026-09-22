import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/theme_mode_scope.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The widget tree's root.
///
/// It publishes the dependencies the tree reads and nothing else: it builds
/// none of them. Construction happens once, in `bootstrap.dart`, so this
/// widget can be pumped in a test with fakes and no network.
class FinanceApp extends StatelessWidget {
  /// Creates the app root over already-constructed dependencies.
  const FinanceApp({
    required this.router,
    required this.viewsRepository,
    required this.agentRepository,
    required this.authRepository,
    required this.componentRegistry,
    required this.themeMode,
    required this.speechRecognizer,
    super.key,
  });

  /// The route table.
  final GoRouter router;

  /// The repository blocs below this point resolve with `context.read`.
  final ViewsRepository viewsRepository;

  /// The agent-turn repository the conversation page's bloc resolves.
  final AgentRepository agentRepository;

  /// Who is signed in; the sign-in page and the header read it.
  final AuthRepository authRepository;

  /// The component registry `ComponentHost` resolves with `context.read`.
  final ComponentRegistry componentRegistry;

  /// Which theme shows; the sign-in toggle and the session sheet set it.
  final ThemeModeController themeMode;

  /// The dictation engine `ConversationPage` builds its voice bloc over.
  final SpeechRecognizer speechRecognizer;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<ViewsRepository>.value(value: viewsRepository),
        RepositoryProvider<AgentRepository>.value(value: agentRepository),
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<ComponentRegistry>.value(value: componentRegistry),
        RepositoryProvider<SpeechRecognizer>.value(value: speechRecognizer),
      ],
      child: ThemeModeScope(
        controller: themeMode,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeMode,
          builder: (context, mode, _) => MaterialApp.router(
            title: 'Finance A2UI',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}
