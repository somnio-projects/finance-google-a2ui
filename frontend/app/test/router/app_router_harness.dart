/// The tree `app_router_test.dart` pumps a router into.
///
/// Extracted so that suite stays inside the 150-line budget — the remedy
/// `.claude/rules/frontend/testing.md` §3 prescribes when a test file grows,
/// rather than trimming the comments that explain why its assertions exist.
library;

import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

/// A stand-in for the views repository the portfolio page reads.
class MockViewsRepository extends Mock implements ViewsRepository;

/// A stand-in for the agent repository the conversation page reads.
class MockAgentRepository extends Mock implements AgentRepository;

/// Pumps [router] inside the providers and the **real theme**.
///
/// The theme matters: `FinanceApp` passes `AppTheme.light`, so a router test
/// without it is testing a different app. That went unnoticed while every
/// rendered component read `AppSpacing`, which falls back to `standard`.
/// `ChartPalette.of` deliberately does not fall back — a chart drawn in
/// colours nobody chose looks plausible and is wrong — so the first component
/// to read it turned this red.
Future<void> pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  required ViewsRepository repository,
  ComponentRegistry? registry,
  AuthRepository? auth,
  AgentRepository? agent,
}) => tester.pumpWidget(
  MultiRepositoryProvider(
    providers: <RepositoryProvider<dynamic>>[
      RepositoryProvider<ViewsRepository>.value(value: repository),
      RepositoryProvider<AgentRepository>.value(
        value: agent ?? MockAgentRepository(),
      ),
      if (auth != null) RepositoryProvider<AuthRepository>.value(value: auth),
      RepositoryProvider<ComponentRegistry>.value(
        value: registry ?? ComponentRegistry(),
      ),
      // The Assistant's mic resolves this on every route that reaches it.
      // Unconditional and unsupported: a router test is not about voice, and
      // the VM really has no engine (spec frontend/0023 OD-2).
      RepositoryProvider<SpeechRecognizer>.value(
        value: const UnsupportedSpeechRecognizer(),
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ),
);
