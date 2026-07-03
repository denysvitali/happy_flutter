import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_loading_indicator.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/providers/loops_notifier.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/loops/create_loop_sheet.dart';
import 'package:happy_flutter/features/loops/loops_screen.dart';

import 'loop_notifier_test_helpers.dart';

Widget _wrap({
  required Widget child,
  Map<String, List<Loop>>? loops,
  Map<String, List<Loop>>? cachedLoops,
  Object? deleteError,
  Object? refreshError,
  List<String>? refreshCalls,
  Future<void> Function()? refreshOverride,
}) {
  return ProviderScope(
    overrides: [
      loopsNotifierProvider.overrideWith(
        () => StubLoopsNotifier(
          initial: loops ?? {},
          cached: cachedLoops,
          deleteError: deleteError,
          refreshError: refreshError,
          refreshCalls: refreshCalls,
          refreshOverride: refreshOverride,
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoopsScreen', () {
    setUp(() {
      sync.testIsInitialized = false;
      sync.testClearAllLoops();
    });

    tearDown(() {
      sync.testIsInitialized = false;
      sync.testClearAllLoops();
    });

    testWidgets('renders empty state when no loops', (tester) async {
      await tester.pumpWidget(_wrap(child: const LoopsScreen(sessionId: 's1')));
      // Pump until the Future.microtask-driven _refresh completes and
      // the loading state is gone.
      await tester.pumpAndSettle();
      expect(find.text('No loops scheduled'), findsOneWidget);
      expect(
        find.text('Type /loop in chat to schedule a recurring prompt.'),
        findsOneWidget,
      );
    });

    testWidgets('renders one card per loop', (tester) async {
      final loops = {
        's1': [
          testLoop(
            id: 'aabbccdd',
            sessionId: 's1',
            expiresAt:
                DateTime.now().millisecondsSinceEpoch + 6 * 24 * 60 * 60 * 1000,
          ),
          testLoop(
            id: 'eeff0011',
            sessionId: 's1',
            expression: '0 9 * * *',
            prompt: 'daily standup',
            createdAt: DateTime.now().millisecondsSinceEpoch - 100000,
            expiresAt:
                DateTime.now().millisecondsSinceEpoch + 5 * 24 * 60 * 60 * 1000,
            paused: true,
          ),
        ],
      };
      await tester.pumpWidget(
        _wrap(
          child: const LoopsScreen(sessionId: 's1'),
          loops: loops,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('check the deploy'), findsOneWidget);
      expect(find.text('daily standup'), findsOneWidget);
      expect(find.text('Every 5 minutes'), findsOneWidget);
      expect(find.text('Daily at 9:00 AM'), findsOneWidget);
    });

    testWidgets('hydrates cached loops before background refresh', (
      tester,
    ) async {
      final refreshCalls = <String>[];
      await tester.pumpWidget(
        _wrap(
          child: const LoopsScreen(sessionId: 's1'),
          cachedLoops: {
            's1': [
              testLoop(
                id: 'aabbccdd',
                sessionId: 's1',
                expiresAt:
                    DateTime.now().millisecondsSinceEpoch +
                    6 * 24 * 60 * 60 * 1000,
              ),
            ],
          },
          refreshCalls: refreshCalls,
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.text('check the deploy'), findsOneWidget);
      expect(refreshCalls, ['refresh']);
    });

    testWidgets('does not keep initial spinner up for a hanging refresh', (
      tester,
    ) async {
      final refreshStarted = Completer<void>();
      await tester.pumpWidget(
        _wrap(
          child: const LoopsScreen(sessionId: 's1'),
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

    testWidgets('shows FAB when not loading and not in error state', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(child: const LoopsScreen(sessionId: 's1')));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('opens CreateLoopSheet when FAB tapped', (tester) async {
      await tester.pumpWidget(_wrap(child: const LoopsScreen(sessionId: 's1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(CreateLoopSheet), findsOneWidget);
    });

    testWidgets('shows error state on refresh failure', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const LoopsScreen(sessionId: 's1'),
          refreshError: StateError('boom'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load loops"), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows snackbar when delete fails', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const LoopsScreen(sessionId: 's1'),
          loops: {
            's1': [
              testLoop(
                id: 'aabbccdd',
                sessionId: 's1',
                expiresAt:
                    DateTime.now().millisecondsSinceEpoch +
                    6 * 24 * 60 * 60 * 1000,
              ),
            ],
          },
          deleteError: StateError('delete failed'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Failed to cancel loop: Bad state: delete failed'),
        findsOneWidget,
      );
    });
  });
}
