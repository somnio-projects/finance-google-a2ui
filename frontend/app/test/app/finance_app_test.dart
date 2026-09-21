import 'package:finance_app/app/finance_app.dart';
import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

class _MockAgentRepository extends Mock implements AgentRepository;

void main() {
  group(FinanceApp, () {
    late _MockViewsRepository repository;

    setUp(() {
      repository = _MockViewsRepository();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Ok<RenderedViews>(renderedViews(extraViews: homeViews())),
      );
    });

    Future<void> pumpTree(WidgetTester tester) => tester.pumpWidget(
      buildApp(
        viewsRepository: repository,
        agentRepository: _MockAgentRepository(),
      ),
    );

    testWidgets('applies the Material 3 theme', (tester) async {
      await pumpTree(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomePage));
      expect(Theme.of(context).useMaterial3, isTrue);
    });

    testWidgets('publishes the agent repository to the tree', (tester) async {
      // The conversation page resolves it with `context.read`, so a missing
      // provider would be a runtime failure on a screen nothing else covers.
      await pumpTree(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomePage));
      expect(RepositoryProvider.of<AgentRepository>(context), isNotNull);
    });
  });
}
