import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/loops/loop_count_badge.dart';

import 'loop_notifier_test_helpers.dart';

Widget _wrap({required Widget child, required Map<String, List<Loop>> loops}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/chat/:sessionId/loops',
        name: 'chat-loops',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Loops screen'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      loopsNotifierProvider.overrideWith(
        () => StubLoopsNotifier(initial: loops),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoopCountBadge', () {
    testWidgets('hides itself when count is 0', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const LoopCountBadge(sessionId: 's1'),
          loops: {},
        ),
      );
      expect(find.byType(LoopCountBadge), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.text('1 loop'), findsNothing);
    });

    testWidgets('shows "1 loop" when one loop is present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const LoopCountBadge(sessionId: 's1'),
          loops: {
            's1': [
              testLoop(
                id: 'aabbccdd',
                sessionId: 's1',
                prompt: 'p',
                createdAt: 1,
                expiresAt: 2,
              ),
            ],
          },
        ),
      );
      expect(find.text('1 loop'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('shows "{count} loops" when multiple are present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: const LoopCountBadge(sessionId: 's1'),
          loops: {
            's1': [
              testLoop(
                id: 'aaaa0001',
                sessionId: 's1',
                prompt: 'a',
                createdAt: 1,
                expiresAt: 2,
              ),
              testLoop(
                id: 'bbbb0002',
                sessionId: 's1',
                expression: '0 9 * * *',
                prompt: 'b',
                createdAt: 1,
                expiresAt: 2,
              ),
              testLoop(
                id: 'cccc0003',
                sessionId: 's1',
                expression: '*/30 * * * *',
                prompt: 'c',
                createdAt: 1,
                expiresAt: 2,
              ),
            ],
          },
        ),
      );
      expect(find.text('3 loops'), findsOneWidget);
    });

    testWidgets('tap navigates to /chat/:sessionId/loops', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const LoopCountBadge(sessionId: 's1'),
          loops: {
            's1': [
              testLoop(
                id: 'aaaa0001',
                sessionId: 's1',
                prompt: 'a',
                createdAt: 1,
                expiresAt: 2,
              ),
            ],
          },
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.text('Loops screen'), findsOneWidget);
    });
  });
}
