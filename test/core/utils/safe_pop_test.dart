import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/routing/safe_pop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('safePop', () {
    testWidgets(
      'pops when the navigator stack has a previous route',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/first',
          routes: [
            GoRoute(
              path: '/first',
              name: 'first',
              builder: (context, state) => Scaffold(
                appBar: AppBar(title: const Text('First')),
                body: Center(
                  child: TextButton(
                    onPressed: () => context.push('/second'),
                    child: const Text('go second'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/second',
              name: 'second',
              builder: (context, state) => Scaffold(
                appBar: AppBar(
                  title: const Text('Second'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => safePop<void>(context),
                  ),
                ),
                body: const Text('second body'),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('go second'));
        await tester.pumpAndSettle();

        expect(find.text('Second'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('First'), findsOneWidget);
      },
    );

    testWidgets(
      'navigates to fallback route when nothing to pop (deep-linked)',
      (tester) async {
        // Simulate a deep-link cold start where the user lands directly
        // on a detail screen with no underlying history. Bare context.pop()
        // would throw here.
        final router = GoRouter(
          initialLocation: '/settings/account',
          routes: [
            GoRoute(
              path: '/sessions',
              name: 'sessions',
              builder: (context, state) => const Scaffold(
                body: Text('Sessions Screen'),
              ),
            ),
            GoRoute(
              path: '/settings/account',
              name: 'account',
              builder: (context, state) => Scaffold(
                appBar: AppBar(
                  title: const Text('Account'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => safePop<void>(context),
                  ),
                ),
                body: const Text('account body'),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Account'), findsOneWidget);

        // Tapping the back button MUST NOT throw and MUST move us to the
        // fallback route since canPop() is false on a cold-started deep link.
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // No uncaught exceptions from the navigator.
        expect(tester.takeException(), isNull);
        expect(find.text('Sessions Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'custom fallback route is honoured when canPop is false',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/artifacts/abc',
          routes: [
            GoRoute(
              path: '/artifacts',
              name: 'artifacts',
              builder: (context, state) => const Scaffold(
                body: Text('Artifacts List'),
              ),
            ),
            GoRoute(
              path: '/sessions',
              name: 'sessions',
              builder: (context, state) => const Scaffold(
                body: Text('Sessions Screen'),
              ),
            ),
            GoRoute(
              path: '/artifacts/:id',
              name: 'artifact-detail',
              builder: (context, state) => Scaffold(
                appBar: AppBar(
                  title: const Text('Artifact'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => safePop<void>(
                      context,
                      fallbackRouteName: 'artifacts',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Artifacts List'), findsOneWidget);
        expect(find.text('Sessions Screen'), findsNothing);
      },
    );

    testWidgets(
      'is a no-op (returns false) when context is unmounted',
      (tester) async {
        late BuildContext capturedContext;
        final router = GoRouter(
          initialLocation: '/screen',
          routes: [
            GoRoute(
              path: '/sessions',
              name: 'sessions',
              builder: (context, state) => const Scaffold(),
            ),
            GoRoute(
              path: '/screen',
              name: 'screen',
              builder: (context, state) {
                capturedContext = context;
                return const Scaffold();
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Tear down the widget tree so the captured context is unmounted.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        final popped = safePop<void>(capturedContext);
        expect(popped, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
