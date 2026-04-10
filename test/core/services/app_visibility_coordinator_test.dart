import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/app_visibility_coordinator.dart';

void main() {
  group('AppVisibilityCoordinator', () {
    test('hidden triggers suspend once until resumed', () {
      final coordinator = AppVisibilityCoordinator();
      var suspendCalls = 0;
      var resumeCalls = 0;

      coordinator.handleLifecycleState(
        AppLifecycleState.hidden,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );
      coordinator.handleLifecycleState(
        AppLifecycleState.paused,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );

      expect(suspendCalls, 1);
      expect(resumeCalls, 0);
      expect(coordinator.isSuspended, isTrue);
    });

    test('inactive does not suspend or resume', () {
      final coordinator = AppVisibilityCoordinator();
      var suspendCalls = 0;
      var resumeCalls = 0;

      coordinator.handleLifecycleState(
        AppLifecycleState.inactive,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );

      expect(suspendCalls, 0);
      expect(resumeCalls, 0);
      expect(coordinator.isSuspended, isFalse);
    });

    test('resumed only fires after a prior suspend edge', () {
      final coordinator = AppVisibilityCoordinator();
      var suspendCalls = 0;
      var resumeCalls = 0;

      coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );
      coordinator.handleLifecycleState(
        AppLifecycleState.hidden,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );
      coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );
      coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );

      expect(suspendCalls, 1);
      expect(resumeCalls, 1);
      expect(coordinator.isSuspended, isFalse);
    });
  });
}
