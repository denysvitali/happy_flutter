import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/widgets/error_boundary.dart';

void main() {
  testWidgets('fallback remains inside the root ProviderScope', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        child: ErrorBoundary(
          errorBuilder: (error, stack) => Consumer(
            builder: (context, ref, child) => const Text('scoped fallback'),
          ),
          child: const SizedBox.shrink(),
        ),
      ),
    );
    FlutterError.onError?.call(
      FlutterErrorDetails(exception: StateError('boom')),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('scoped fallback'), findsOneWidget);
  });

  testWidgets('custom errorBuilder receives an empty stack when absent', (
    tester,
  ) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    Object? builtError;
    StackTrace? builtStack;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ErrorBoundary(
            errorBuilder: (error, stack) {
              builtError = error;
              builtStack = stack;
              return const Text('fallback');
            },
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    FlutterError.onError?.call(
      FlutterErrorDetails(exception: StateError('boom')),
    );
    await tester.pump();

    expect(find.text('fallback'), findsOneWidget);
    expect(builtError, isA<StateError>());
    expect(builtStack, StackTrace.empty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Production shipped 82 widget crashes in 16 minutes whose only log body was
  // the constant 'ErrorBoundary caught error'. The OTel sink reduces the error
  // argument to `error.type`, so Loki showed 82 identical `_TypeError` lines
  // with nothing to triage on. The body must name the failure — and must stay
  // bounded, because exception descriptions can embed a whole widget tree.
  group('ErrorBoundary.debugDescribeError', () {
    test('names the exception', () {
      final described = ErrorBoundary.debugDescribeError(
        StateError('permissionMode was null'),
      );

      expect(described, contains('permissionMode was null'));
    });

    test('appends the library when Flutter reports one', () {
      final described = ErrorBoundary.debugDescribeError(
        StateError('boom'),
        library: 'widgets library',
      );

      expect(described, endsWith('[widgets library]'));
    });

    test('omits the library suffix when absent or empty', () {
      expect(
        ErrorBoundary.debugDescribeError(StateError('boom')),
        isNot(contains('[')),
      );
      expect(
        ErrorBoundary.debugDescribeError(StateError('boom'), library: ''),
        isNot(contains('[')),
      );
    });

    test('collapses newlines so one crash stays one log line', () {
      final described = ErrorBoundary.debugDescribeError(
        const FormatException('line one\nline two'),
      );

      expect(described, isNot(contains('\n')));
      expect(described, contains('line one line two'));
    });

    test('bounds a huge description', () {
      final described = ErrorBoundary.debugDescribeError(
        StateError('x' * 4000),
      );

      expect(described.length, 200);
      expect(described, endsWith('...'));
    });

    test('leaves a description at the limit untouched', () {
      // 'Bad state: ' (11) + 189 chars == exactly 200.
      final described = ErrorBoundary.debugDescribeError(StateError('y' * 189));

      expect(described.length, 200);
      expect(described, isNot(endsWith('...')));
    });
  });

  // Production ANR (GlitchTip 3659, build 271500): ErrorBoundary sits
  // above MaterialApp. The takeover called Theme.of / AppLocalizations.of
  // (both bang), Flutter built ErrorWidget, and ErrorWidget.builder
  // itself called Theme.of — unbounded recursion on the UI isolate.
  group('ErrorBoundary ANR guards', () {
    testWidgets('takeover without MaterialApp does not throw', (tester) async {
      final originalOnError = FlutterError.onError;
      final originalBuilder = ErrorWidget.builder;
      addTearDown(() {
        FlutterError.onError = originalOnError;
        ErrorWidget.builder = originalBuilder;
      });

      await tester.pumpWidget(
        ProviderScope(child: ErrorBoundary(child: const SizedBox.shrink())),
      );

      FlutterError.onError?.call(
        FlutterErrorDetails(exception: StateError('boom')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Go Home'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('ErrorWidget.builder without Theme ancestor does not recurse', (
      tester,
    ) async {
      final originalOnError = FlutterError.onError;
      final originalBuilder = ErrorWidget.builder;
      addTearDown(() {
        FlutterError.onError = originalOnError;
        ErrorWidget.builder = originalBuilder;
      });

      await tester.pumpWidget(
        ProviderScope(
          child: ErrorBoundary(
            child: Builder(
              builder: (context) {
                return ErrorWidget.builder(
                  FlutterErrorDetails(exception: StateError('no theme')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('no theme'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
