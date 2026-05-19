import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
