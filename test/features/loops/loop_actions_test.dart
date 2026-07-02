import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/loops_notifier.dart';
import 'package:happy_flutter/features/loops/loop_actions.dart';

class _StubLoopsNotifier extends LoopsNotifier {
  _StubLoopsNotifier({this.deleteError, this.calls});

  final Object? deleteError;
  final List<String>? calls;

  @override
  Map<String, List<Loop>> build() => const {};

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
    throw UnimplementedError();
  }

  @override
  Future<void> deleteLoop({
    required String sessionId,
    required String loopId,
  }) async {
    calls?.add('$sessionId:$loopId');
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
  required GlobalKey<ScaffoldMessengerState> messengerKey,
  required void Function(WidgetRef ref) onRef,
  Object? deleteError,
  List<String>? calls,
}) {
  return ProviderScope(
    overrides: [
      loopsNotifierProvider.overrideWith(
        () => _StubLoopsNotifier(deleteError: deleteError, calls: calls),
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
}
