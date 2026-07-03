import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/loops/loop_actions.dart';

import 'loop_notifier_test_helpers.dart';

Widget _wrap({
  required GlobalKey<ScaffoldMessengerState> messengerKey,
  required void Function(WidgetRef ref) onRef,
  Object? deleteError,
  Object? pauseError,
  List<String>? calls,
  List<String>? actionCalls,
}) {
  return ProviderScope(
    overrides: [
      loopsNotifierProvider.overrideWith(
        () => StubLoopsNotifier(
          deleteError: deleteError,
          deleteCalls: calls,
          pauseError: pauseError,
          actionCalls: actionCalls,
        ),
      ),
    ],
    child: MaterialApp(
      scaffoldMessengerKey: messengerKey,
      home: Consumer(
        builder: (context, ref, _) {
          onRef(ref);
          return const Scaffold(body: SizedBox());
        },
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('deleteLoopWithFeedback', () {
    testWidgets('shows success snackbar after delete succeeds', (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final calls = <String>[];
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        _wrap(
          messengerKey: messengerKey,
          calls: calls,
          onRef: (ref) => widgetRef = ref,
        ),
      );

      await deleteLoopWithFeedback(
        ref: widgetRef,
        messenger: messengerKey.currentState!,
        isMounted: () => true,
        failureLogMessage: 'test delete failed',
        failureLabel: 'Failed to cancel loop',
        successLabel: 'Loop abc12345 cancelled',
        sessionId: 's1',
        loopId: 'abc12345',
      );
      await tester.pump();

      expect(calls, ['s1:abc12345']);
      expect(find.text('Loop abc12345 cancelled'), findsOneWidget);
    });

    testWidgets('shows failure snackbar for handled errors', (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        _wrap(
          messengerKey: messengerKey,
          deleteError: StateError('missing loop'),
          onRef: (ref) => widgetRef = ref,
        ),
      );

      await deleteLoopWithFeedback(
        ref: widgetRef,
        messenger: messengerKey.currentState!,
        isMounted: () => true,
        failureLogMessage: 'test delete failed',
        failureLabel: 'Failed to cancel loop',
        shouldHandleError: (error) => error is StateError,
        sessionId: 's1',
        loopId: 'abc12345',
      );
      await tester.pump();

      expect(
        find.text('Failed to cancel loop: Bad state: missing loop'),
        findsOneWidget,
      );
    });

    testWidgets('rethrows unhandled errors', (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        _wrap(
          messengerKey: messengerKey,
          deleteError: ArgumentError('not handled'),
          onRef: (ref) => widgetRef = ref,
        ),
      );

      await expectLater(
        deleteLoopWithFeedback(
          ref: widgetRef,
          messenger: messengerKey.currentState!,
          isMounted: () => true,
          failureLogMessage: 'test delete failed',
          failureLabel: 'Failed to cancel loop',
          shouldHandleError: (error) => error is StateError,
          sessionId: 's1',
          loopId: 'abc12345',
        ),
        throwsA(isA<ArgumentError>()),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('pauseLoopWithFeedback', () {
    testWidgets('calls pause without showing snackbar on success', (
      tester,
    ) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final calls = <String>[];
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        _wrap(
          messengerKey: messengerKey,
          actionCalls: calls,
          onRef: (ref) => widgetRef = ref,
        ),
      );

      await pauseLoopWithFeedback(
        ref: widgetRef,
        messenger: messengerKey.currentState!,
        isMounted: () => true,
        failureLogMessage: 'test pause failed',
        failureLabel: 'Failed to pause loop',
        sessionId: 's1',
        loopId: 'abc12345',
        paused: true,
      );
      await tester.pump();

      expect(calls, ['pause:s1:abc12345:true']);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('shows failure snackbar when pause fails', (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        _wrap(
          messengerKey: messengerKey,
          pauseError: StateError('daemon unavailable'),
          onRef: (ref) => widgetRef = ref,
        ),
      );

      await pauseLoopWithFeedback(
        ref: widgetRef,
        messenger: messengerKey.currentState!,
        isMounted: () => true,
        failureLogMessage: 'test pause failed',
        failureLabel: 'Failed to pause loop',
        sessionId: 's1',
        loopId: 'abc12345',
        paused: true,
      );
      await tester.pump();

      expect(
        find.text('Failed to pause loop: Bad state: daemon unavailable'),
        findsOneWidget,
      );
    });
  });
}
