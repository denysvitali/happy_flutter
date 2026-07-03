import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/components/app_loading_indicator.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/loops/all_loops_screen.dart';

import 'loop_notifier_test_helpers.dart';

Widget _wrap({
  required Widget child,
  Map<String, List<Loop>>? loops,
  Map<String, List<Loop>>? cachedLoops,
  List<String>? refreshCalls,
  List<String>? actionCalls,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/chat/:sessionId/loops',
        name: 'chat-loops',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Per-session loops screen')),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      loopsNotifierProvider.overrideWith(
        () => StubLoopsNotifier(
          initial: loops ?? {},
          cached: cachedLoops,
          refreshCalls: refreshCalls,
          actionCalls: actionCalls,
        ),
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

  group('AllLoopsScreen', () {
    setUp(() {
      sync.testIsInitialized = false;
      sync.testClearAllLoops();
    });

    tearDown(() {
      sync.testIsInitialized = false;
      sync.testClearAllLoops();
    });

    testWidgets('shows empty state when there are no loops', (tester) async {
      await tester.pumpWidget(_wrap(child: const AllLoopsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No loops scheduled'), findsOneWidget);
      expect(
        find.text('Type /loop in any session to schedule a recurring prompt.'),
        findsOneWidget,
      );
    });

    testWidgets('groups loops by session and renders a section per session', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: const AllLoopsScreen(),
          loops: {
            's1': [testLoop(id: 'aaa00001', sessionId: 's1')],
            's2': [
              testLoop(id: 'bbb00001', sessionId: 's2'),
              testLoop(id: 'bbb00002', sessionId: 's2'),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();
      // No metadata on the stub sessions → fall back to the
      // "Session <id>" prefix used elsewhere in the app.
      expect(find.text('Session s1'), findsOneWidget);
      expect(find.text('Session s2'), findsOneWidget);
      // Both loop prompts are rendered.
      expect(find.text('check the deploy'), findsNWidgets(3));
    });

    testWidgets('header shows total active count and session count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: const AllLoopsScreen(),
          loops: {
            's1': [testLoop(id: 'aaa00001', sessionId: 's1')],
            's2': [
              testLoop(id: 'bbb00001', sessionId: 's2'),
              testLoop(id: 'bbb00002', sessionId: 's2'),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 active loops'), findsOneWidget);
      expect(find.text('across 2 sessions'), findsOneWidget);
    });

    testWidgets('hydrates cached groups before background refresh', (
      tester,
    ) async {
      final refreshCalls = <String>[];
      await tester.pumpWidget(
        _wrap(
          child: const AllLoopsScreen(),
          cachedLoops: {
            's1': [testLoop(id: 'aaa00001', sessionId: 's1')],
            's2': [testLoop(id: 'bbb00001', sessionId: 's2')],
          },
          refreshCalls: refreshCalls,
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.text('2 active loops'), findsOneWidget);
      expect(find.text('across 2 sessions'), findsOneWidget);
      expect(refreshCalls, ['refresh']);
    });

    testWidgets('tapping the section header collapses the group', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: const AllLoopsScreen(),
          loops: {
            's1': [testLoop(id: 'aaa00001', sessionId: 's1')],
          },
        ),
      );
      await tester.pumpAndSettle();
      // The loop card is initially visible.
      expect(find.byType(Card), findsOneWidget);
      // Tap the header row — first InkWell inside the AllLoopsScreen
      // is the section collapse toggle.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      // After collapse the card is no longer in the tree.
      expect(find.byType(Card), findsNothing);
    });

    testWidgets(
      'delete and pause handlers are wired through to LoopsNotifier',
      (tester) async {
        final calls = <String>[];
        await tester.pumpWidget(
          _wrap(
            child: const AllLoopsScreen(),
            loops: {
              's1': [testLoop(id: 'aaa00001', sessionId: 's1')],
            },
            actionCalls: calls,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pause'));
        await tester.pumpAndSettle();
        expect(calls, ['pause:s1:aaa00001:true']);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        expect(calls, ['pause:s1:aaa00001:true', 'delete:s1:aaa00001']);
        expect(find.text('Pause'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      },
    );

    testWidgets('"View per session" navigates to /chat/:sessionId/loops', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: const AllLoopsScreen(),
          loops: {
            's1': [testLoop(id: 'aaa00001', sessionId: 's1')],
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View per session'));
      await tester.pumpAndSettle();
      expect(find.text('Per-session loops screen'), findsOneWidget);
    });
  });
}
