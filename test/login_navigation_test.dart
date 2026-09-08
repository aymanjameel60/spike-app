import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spike_flutter_app/app/providers.dart';
import 'package:spike_flutter_app/features/auth/presentation/auth_screen.dart';
import 'package:spike_flutter_app/features/checkout/presentation/addresses_screen.dart';
import 'package:spike_flutter_app/features/shell/presentation/main_shell.dart';

/// Regression test for the post-login navigation on the addresses flow.
/// Auth routes live outside the shell, so pushing login over the pushed
/// addresses page and popping back must stay on one navigator and never
/// trigger Navigator's duplicated-page-key assertion.
void main() {
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          ShellRoute(
            builder: (context, state, child) => MainShell(child: child, location: state.uri.path),
            routes: [
              GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home')),
              ),
            ],
          ),
          GoRoute(path: '/addresses', builder: (_, __) => const AddressesScreen()),
          GoRoute(path: '/login', builder: (_, __) => const AuthScreen(mode: 'login', afterLoginRoute: '/addresses')),
        ],
      );

  Future<void> pumpApp(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasSessionProvider.overrideWith((ref) async => true),
          addressesProvider.overrideWith((ref) async => const []),
          cartCountProvider.overrideWith((ref) async => 0),
          notificationsDataProvider.overrideWith((ref) async => const {}),
          currentUserProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('push addresses, push login, pop back — no duplicated page keys', (tester) async {
    final router = buildRouter();
    await pumpApp(tester, router);

    router.push('/addresses');
    await tester.pumpAndSettle();
    expect(find.text('اختيار العنوان'), findsOneWidget);

    router.push('/login?next=/addresses');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'pushing login over pushed addresses must not assert duplicated keys');
    expect(find.text('تسجيل الدخول'), findsWidgets);

    router.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('اختيار العنوان'), findsOneWidget, reason: 'pop() must return to the addresses page');
  });
}
