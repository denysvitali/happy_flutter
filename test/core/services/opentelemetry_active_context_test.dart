import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/opentelemetry_service.dart';

/// Contract tests for the active-span context added to
/// [OpenTelemetryService] so HTTP / sync / sub-agent spans can chain
/// correctly under chat.send_message.
///
/// We don't initialize the real OTel SDK in tests (the package's
/// startSpan returns null without init); instead we exercise the
/// asynchronous context-propagation surface directly.
/// Integration tests with the live SDK run via the production
/// codepath — these tests pin the public contract so a refactor
/// can't silently break span chaining.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenTelemetryService active-span context', () {
    test('currentSpan is null by default', () {
      expect(OpenTelemetryService().currentSpan, isNull);
    });

    test(
      'withActiveSpan restores the previous active span on return',
      () async {
        // The helper is used to bracket a region where the new span
        // should be the active one. Since startTrace returns null
        // without init, we exercise the body invocation directly.
        // A no-op body is sufficient — the contract is that the
        // stack stays balanced.
        var bodyRan = false;
        await OpenTelemetryService().withActiveSpan(
          // Fake the span by pushing and popping manually since the
          // real startTrace returns null.
          // ignore: invalid_use_of_protected_member
          _FakeSpan('outer'),
          () async {
            bodyRan = true;
          },
        );
        expect(bodyRan, isTrue);
        // After the with-block, the parent Zone is unchanged.
        expect(OpenTelemetryService().currentSpan, isNull);
      },
    );

    test('withActiveSpan restores the previous active span on throw', () async {
      // Same contract: stack must be balanced even when the body
      // throws, so the next operation does not see a leaked span.
      Object? caught;
      try {
        await OpenTelemetryService().withActiveSpan(
          // ignore: invalid_use_of_protected_member
          _FakeSpan('outer'),
          () async {
            throw StateError('boom');
          },
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<StateError>());
      expect(OpenTelemetryService().currentSpan, isNull);
    });

    test('concurrent contexts do not leak spans across futures', () async {
      final service = OpenTelemetryService();
      final first = _FakeSpan('first');
      final second = _FakeSpan('second');
      final firstReady = Completer<void>();
      final secondReady = Completer<void>();

      final firstFuture = service.withActiveSpan(first, () async {
        expect(service.currentSpan, same(first));
        firstReady.complete();
        await secondReady.future;
        expect(service.currentSpan, same(first));
      });
      final secondFuture = service.withActiveSpan(second, () async {
        await firstReady.future;
        expect(service.currentSpan, same(second));
        secondReady.complete();
        await Future<void>.delayed(Duration.zero);
        expect(service.currentSpan, same(second));
      });

      await Future.wait([firstFuture, secondFuture]);
      expect(service.currentSpan, isNull);
    });
  });
}

/// Minimal stand-in for [OTelSpan] used by the context-stack tests.
/// The real span is constructed by the OTel SDK and is not exposed
/// for direct construction in tests; the stack API only needs a
/// non-null [Object] reference to keep the LIFO discipline.
class _FakeSpan implements OTelSpan {
  _FakeSpan(this.label);
  final String label;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
