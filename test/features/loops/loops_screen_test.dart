import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/providers/loops_notifier.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/loops/create_loop_sheet.dart';
import 'package:happy_flutter/features/loops/loops_screen.dart';

class _StubLoopsNotifier extends LoopsNotifier {
  _StubLoopsNotifier(this._initial, {this.deleteError});
  final Map<String, List<Loop>> _initial;
  final Object? deleteError;

  @override
  Map<String, List<Loop>> build() => _initial;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}

  @override
  Future<Loop> createLoop({
    required String sessionId,
    required String expression,
    required String prompt,
    required bool recurring,
  }) async {
    return Loop(
      id: 'newloop1',
      sessionId: sessionId,
      expression: expression,
      prompt: prompt,
      recurring: recurring,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      expiresAt:
          DateTime.now().millisecondsSinceEpoch + 7 * 24 * 60 * 60 * 1000,
    );
  }

  @override
  Future<void> deleteLoop({
    required String sessionId,
    required String loopId,
  }) async {
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Future<void> pauseLoop({
    required String sessionId,
    required String loopId,
    required bool paused,
  }) async {}
}

Widget _wrap({
  required Widget child,
  Map<String, List<Loop>>? loops,
  Object? deleteError,
}) {
  return ProviderScope(
    overrides: [
      loopsNotifierProvider.overrideWith(
        () => _StubLoopsNotifier(loops ?? {}, deleteError: deleteError),
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
      await tester.pumpWidget(
        _wrap(child: const LoopsScreen(sessionId: 's1')),
      );
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
          Loop(
            id: 'aabbccdd',
            sessionId: 's1',
            expression: '*/5 * * * *',
            prompt: 'check the deploy',
            recurring: true,
            createdAt: DateTime.now().millisecondsSinceEpoch - 60000,
            expiresAt:
                DateTime.now().millisecondsSinceEpoch + 6 * 24 * 60 * 60 * 1000,
          ),
          Loop(
            id: 'eeff0011',
            sessionId: 's1',
            expression: '0 9 * * *',
            prompt: 'daily standup',
            recurring: true,
            createdAt: DateTime.now().millisecondsSinceEpoch - 100000,
            expiresAt:
                DateTime.now().millisecondsSinceEpoch + 5 * 24 * 60 * 60 * 1000,
            paused: true,
          ),
        ],
      };
      await tester.pumpWidget(
        _wrap(child: const LoopsScreen(sessionId: 's1'), loops: loops),
      );
      await tester.pumpAndSettle();
      expect(find.text('check the deploy'), findsOneWidget);
      expect(find.text('daily standup'), findsOneWidget);
      expect(find.text('Every 5 minutes'), findsOneWidget);
      expect(find.text('Daily at 9:00 AM'), findsOneWidget);
    });

    testWidgets('shows FAB when not loading and not in error state',
        (tester) async {
      await tester.pumpWidget(
        _wrap(child: const LoopsScreen(sessionId: 's1')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('opens CreateLoopSheet when FAB tapped', (tester) async {
      await tester.pumpWidget(
        _wrap(child: const LoopsScreen(sessionId: 's1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(CreateLoopSheet), findsOneWidget);
    });

    testWidgets('shows error state on refresh failure', (tester) async {
      final failingNotifier = _FailingRefreshLoopsNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsNotifierProvider.overrideWith(() => failingNotifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoopsScreen(sessionId: 's1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Couldn\'t load loops'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows snackbar when delete fails', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const LoopsScreen(sessionId: 's1'),
          loops: {
            's1': [
              Loop(
                id: 'aabbccdd',
                sessionId: 's1',
                expression: '*/5 * * * *',
                prompt: 'check the deploy',
                recurring: true,
                createdAt: DateTime.now().millisecondsSinceEpoch - 60000,
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

class _FailingRefreshLoopsNotifier extends LoopsNotifier {
  @override
  Map<String, List<Loop>> build() => {};

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {
    throw StateError('boom');
  }
}
