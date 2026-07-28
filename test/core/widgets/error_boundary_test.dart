import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/widgets/error_boundary.dart';

void main() {
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
  // with nothing to triage on. The body must name the failure.
  testWidgets('logged body names the exception and library', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    final forwarded = <LogEntry>[];
    logger.installOtelSink(forwarded.add);
    addTearDown(() {
      FlutterError.onError = originalOnError;
      logger
        ..removeOtelSink()
        ..clear();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ErrorBoundary(
            errorBuilder: (_, _) => const Text('fallback'),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    FlutterError.onError?.call(
      FlutterErrorDetails(
        exception: StateError('permissionMode was null'),
        library: 'widgets library',
      ),
    );
    await tester.pump();

    final body = forwarded
        .map((entry) => entry.message)
        .firstWhere((message) => message.startsWith('ErrorBoundary caught'));
    expect(body, contains('permissionMode was null'));
    expect(body, contains('[widgets library]'));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a huge exception description is bounded', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    final forwarded = <LogEntry>[];
    logger.installOtelSink(forwarded.add);
    addTearDown(() {
      FlutterError.onError = originalOnError;
      logger
        ..removeOtelSink()
        ..clear();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ErrorBoundary(
            errorBuilder: (_, _) => const Text('fallback'),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    FlutterError.onError?.call(
      FlutterErrorDetails(exception: StateError('x' * 4000)),
    );
    await tester.pump();

    final body = forwarded
        .map((entry) => entry.message)
        .firstWhere((message) => message.startsWith('ErrorBoundary caught'));
    expect(body.length, lessThan(300));
    expect(body, endsWith('...'));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
