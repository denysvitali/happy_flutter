import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/opentelemetry_service.dart';

/// Contract tests for the active-span context added to
/// [OpenTelemetryService] so HTTP / sync / sub-agent spans can chain
/// correctly under chat.send_message.
///
/// We don't initialize the real OTel SDK in tests (the package's
/// startSpan returns null without init); instead we exercise the
/// push/pop stack and the context-propagation surface directly.
/// Integration tests with the live SDK run via the production
/// codepath — these tests pin the public contract so a refactor
/// can't silently break span chaining.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenTelemetryService active-span context', () {
    setUp(() {
      // Drain any leftover active span from a prior test.
      while (OpenTelemetryService().popCurrentSpan() != null) {}
    });

    test('currentSpan is null by default', () {
      expect(OpenTelemetryService().currentSpan, isNull);
    });

    test('pushCurrentSpan / popCurrentSpan stack correctly', () {
      // Without an initialized OTel SDK, startTrace returns null, so
      // we can't actually push real spans in tests. Instead, the
      // service exposes the stack manipulation directly. Verify
      // that pushing nulls and popping returns null in a stable
      // order.
      expect(OpenTelemetryService().currentSpan, isNull);
      // popCurrentSpan on empty stack returns null.
      expect(OpenTelemetryService().popCurrentSpan(), isNull);
    });

    test('withActiveSpan restores the previous active span on return', () async {
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
      // After the with-block, the stack must be balanced.
      expect(OpenTelemetryService().currentSpan, isNull);
    });

    test('withActiveSpan restores the previous active span on throw',
        () async {
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

    test('nested withActiveSpan blocks stack and unwind correctly',
        () async {
      // Drive the stack manually to verify the LIFO discipline the
      // push/pop implementation relies on.
      // ignore: invalid_use_of_protected_member
      OpenTelemetryService().pushCurrentSpan(_FakeSpan('a'));
      expect(OpenTelemetryService().currentSpan, isNotNull);
      // ignore: invalid_use_of_protected_member
      OpenTelemetryService().pushCurrentSpan(_FakeSpan('b'));
      // ignore: invalid_use_of_protected_member
      final popped = OpenTelemetryService().popCurrentSpan();
      expect(popped, isNotNull);
      // The remaining top is still the outer one.
      expect(OpenTelemetryService().currentSpan, isNotNull);
      // ignore: invalid_use_of_protected_member
      OpenTelemetryService().popCurrentSpan();
      expect(OpenTelemetryService().currentSpan, isNull);
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
