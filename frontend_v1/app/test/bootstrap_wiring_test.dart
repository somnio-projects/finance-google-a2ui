import 'dart:convert';

import 'package:finance_app/app/app_config.dart';
import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_app/features/sign_in/view/sign_in_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/catalog_snapshot.dart';

class _MockAuth extends Mock implements FirebaseAuth;

class _MockUser extends Mock implements User;

void main() {
  group('bootstrap wiring', () {
    testWidgets(
      'a restored Firebase session is admitted, and a 401 signs it out',
      (tester) async {
        // The whole seam, wired by the real composition root: the SDK's
        // token reaches the header, the registry admits it, the Home tab
        // loads, the backend then answers 401 and the gate closes the shell.
        final auth = _MockAuth();
        final user = _MockUser();
        when(user.getIdToken).thenAnswer((_) async => 'id-token');
        when(() => auth.currentUser).thenReturn(user);
        when(auth.signOut).thenAnswer((_) async {});
        when(() => auth.isSignInWithEmailLink(any())).thenReturn(false);
        final snapshot = CatalogSnapshot.load();
        final seen = <String>[];
        var admitted = true;
        final client = MockClient((request) async {
          seen.add('${request.url.path} ${request.headers['authorization']}');
          if (request.url.path == '/v1/me/access') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'email': 'a@b.test',
                'provisioned': admitted,
                'status': 'active',
                'role': 'member',
                'display_name': null,
                'message': 'Welcome back.',
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/views')) {
            final views = request.url.queryParametersAll['view']!;
            if (views.contains('holdings.allocation.v1')) {
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'type': 'https://errors.finance-a2ui/auth/expired-token',
                  'title': 'Unauthorized',
                  'status': 401,
                  'detail': 'expired',
                  'instance': request.url.path,
                  'request_id': 'r',
                }),
                401,
                headers: <String, String>{
                  'content-type': 'application/problem+json',
                },
              );
            }
            return http.Response(
              jsonEncode(<String, dynamic>{
                'as_of': '2026-01-15T12:00:00Z',
                'portfolio_id': 'current',
                'views': <String, dynamic>{
                  'portfolio.summary.v1': snapshot.exampleFor(
                    'PortfolioSummary',
                  ),
                },
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        });
        await tester.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          bootstrap(
            config: AppConfig(
              backendBaseUrl: Uri.parse('http://localhost:8000'),
            ),
            httpClient: client,
            firebaseAuth: auth,
          ),
        );
        await tester.pumpAndSettle();
        // Admitted, the Home tab asked for its views with the SDK's token…
        expect(seen.first, '/v1/me/access Bearer id-token');
        expect(seen.any((s) => s.contains('/views Bearer id-token')), isTrue);
        // …and the 401 on the allocation closed the shell: back to sign-in.
        expect(find.byType(SignInPage), findsOneWidget);
        expect(find.byType(HomePage), findsNothing);
        verify(auth.signOut).called(1);
        admitted = false;
      },
    );

    testWidgets('a build without Firebase starts signed out', (tester) async {
      await tester.pumpWidget(
        bootstrap(
          config: AppConfig(backendBaseUrl: Uri.parse('http://localhost:8000')),
          httpClient: MockClient((_) async => http.Response('', 404)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
    });
  });
}
