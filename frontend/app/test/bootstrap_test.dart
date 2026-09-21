import 'package:finance_app/app/app_config.dart';
import 'package:finance_app/app/finance_app.dart';
import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/fixtures.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

class _MockAgentRepository extends Mock implements AgentRepository;

void main() {
  group('bootstrap', () {
    test('builds the whole tree from configuration alone', () {
      final widget = bootstrap(
        config: AppConfig(
          backendBaseUrl: Uri.parse('http://localhost:8000'),
          devBearerToken: null,
        ),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(widget, isA<FinanceApp>());
    });

    test('reads the environment when no configuration is supplied', () {
      final widget = bootstrap(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(widget, isA<FinanceApp>());
    });

    test('builds its own http client when none is supplied', () {
      // Constructing the tree opens no socket; the first request would,
      // and this test never lets one happen.
      expect(bootstrap(), isA<FinanceApp>());
    });
  });

  group('devTokenProvider', () {
    test('supplies the configured development credential', () async {
      final provider = devTokenProvider(
        AppConfig(
          backendBaseUrl: Uri.parse('http://localhost:8000'),
          devBearerToken: 'dev-token',
        ),
      );
      expect(await provider(), equals('dev-token'));
    });

    test('reports an anonymous caller when none is configured', () async {
      final provider = devTokenProvider(
        AppConfig(
          backendBaseUrl: Uri.parse('http://localhost:8000'),
          devBearerToken: null,
        ),
      );
      expect(await provider(), isNull);
    });
  });

  group('buildComponentRegistry', () {
    test('wires every component the generated manifest lists', () {
      final registry = buildComponentRegistry();
      expect(registry.viewIds, contains('holdings.allocation.v1'));
    });
  });

  group('buildApp', () {
    testWidgets('renders the home surface at the initial route', (
      tester,
    ) async {
      final repository = _MockViewsRepository();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Ok<RenderedViews>(renderedViews(extraViews: homeViews())),
      );

      await tester.pumpWidget(
        buildApp(
          viewsRepository: repository,
          agentRepository: _MockAgentRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      // The end of the vertical slice: a figure the backend formatted, on
      // screen, byte for byte.
      expect(find.text(r'$482,915.20'), findsWidgets);
      expect(find.text('Alex Chen'), findsOneWidget);
    });

    testWidgets('accepts an injected registry', (tester) async {
      final repository = _MockViewsRepository();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Ok<RenderedViews>(renderedViews(extraViews: homeViews())),
      );

      await tester.pumpWidget(
        buildApp(
          viewsRepository: repository,
          agentRepository: _MockAgentRepository(),
          componentRegistry: ComponentRegistry(),
        ),
      );
      await tester.pumpAndSettle();

      // An empty registry means no component claims the view, so the host
      // shows its placeholder instead of crashing.
      expect(find.textContaining('No component for'), findsOneWidget);
    });
  });
}
