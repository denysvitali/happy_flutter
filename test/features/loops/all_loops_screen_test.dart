import 'dart:async';

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
  Future<void> Function()? refreshOverride,
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
      GoRoute(
        path: '/goal-loops',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Goal loops screen'))),
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
          refreshOverride: refreshOverride,
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

    testWidgets('scheduled and goal modes provide an explicit path', (
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

      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Goal loops'), findsOneWidget);

      await tester.tap(find.text('Goal loops'));
      await tester.pumpAndSettle();
      expect(find.text('Goal loops screen'), findsOneWidget);
    });

    testWidgets('filters all, active, and paused loops without losing groups', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: const AllLoopsScreen(),
          loops: {
            's1': [
              testLoop(
                id: 'aaa00001',
                sessionId: 's1',
                prompt: 'active deployment check',
              ),
              testLoop(
                id: 'aaa00002',
                sessionId: 's1',
                prompt: 'paused deployment check',
                paused: true,
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('active deployment check'), findsOneWidget);
      expect(find.text('paused deployment check'), findsOneWidget);
      expect(find.text('1 active loop'), findsOneWidget);
      expect(find.text('1 paused loop'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('loops-filter-active')));
      await tester.pumpAndSettle();
      expect(find.text('Session s1'), findsOneWidget);
      expect(find.text('active deployment check'), findsOneWidget);
      expect(find.text('paused deployment check'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('loops-filter-paused')));
      await tester.pumpAndSettle();
      expect(find.text('Session s1'), findsOneWidget);
      expect(find.text('active deployment check'), findsNothing);
      expect(find.text('paused deployment check'), findsOneWidget);
    });

    testWidgets('filtered empty state explains the state and resets to all', (
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

      await tester.tap(find.byKey(const ValueKey('loops-filter-paused')));
      await tester.pumpAndSettle();
      expect(find.text('0 paused'), findsOneWidget);
      expect(find.text('No paused loops'), findsOneWidget);
      expect(
        find.text('Pause an active loop to keep it here without deleting it.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Show all loops'));
      await tester.pumpAndSettle();
      expect(find.text('check the deploy'), findsOneWidget);
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

    testWidgets('does not keep initial spinner up for a hanging refresh', (
      tester,
    ) async {
      final refreshStarted = Completer<void>();
      await tester.pumpWidget(
        _wrap(
          child: const AllLoopsScreen(),
          refreshOverride: () async {
            refreshStarted.complete();
            await Completer<void>().future;
          },
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(refreshStarted.isCompleted, isTrue);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.text('No loops scheduled'), findsOneWidget);
    });

    testWidgets('group disclosure exposes expanded button semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          child: const AllLoopsScreen(),
          loops: {
            's1': [testLoop(id: 'aaa00001', sessionId: 's1')],
          },
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('loops-group-toggle-s1'));
      var toggle = tester.widget<Semantics>(toggleFinder);
      expect(toggle.properties.button, isTrue);
      expect(toggle.properties.expanded, isTrue);
      expect(toggle.properties.label, 'Session s1, 1 loop');
      expect(find.byType(Card), findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      toggle = tester.widget<Semantics>(toggleFinder);
      expect(toggle.properties.expanded, isFalse);
      expect(find.byType(Card), findsNothing);
      semantics.dispose();
    });

    testWidgets('filters and secondary session action meet touch targets', (
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

      for (final name in ['all', 'active', 'paused']) {
        final size = tester.getSize(find.byKey(ValueKey('loops-filter-$name')));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      final sessionAction = tester.getSize(
        find.byKey(const ValueKey('view-session-loops-s1')),
      );
      expect(sessionAction.width, greaterThanOrEqualTo(44));
      expect(sessionAction.height, greaterThanOrEqualTo(44));
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
      await tester.tap(find.byKey(const ValueKey('view-session-loops-s1')));
      await tester.pumpAndSettle();
      expect(find.text('Per-session loops screen'), findsOneWidget);
    });
  });
}
