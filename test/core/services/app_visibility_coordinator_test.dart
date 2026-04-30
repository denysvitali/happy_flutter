import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/app_visibility_coordinator.dart';

void main() {
  group('AppVisibilityCoordinator', () {
    test('hidden triggers suspend once until resumed', () {
      final coordinator = AppVisibilityCoordinator();
      var suspendCalls = 0;
      var resumeCalls = 0;

      final hiddenEdge = coordinator.handleLifecycleState(
        AppLifecycleState.hidden,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );
      final pausedEdge = coordinator.handleLifecycleState(
        AppLifecycleState.paused,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );

      expect(suspendCalls, 1);
      expect(resumeCalls, 0);
      expect(hiddenEdge, AppVisibilityEdge.suspended);
      expect(pausedEdge, AppVisibilityEdge.none);
      expect(coordinator.isSuspended, isTrue);
    });

    test('inactive does not suspend or resume', () {
      final coordinator = AppVisibilityCoordinator();
      var suspendCalls = 0;
      var resumeCalls = 0;

      final edge = coordinator.handleLifecycleState(
        AppLifecycleState.inactive,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );

      expect(suspendCalls, 0);
      expect(resumeCalls, 0);
      expect(edge, AppVisibilityEdge.none);
      expect(coordinator.isSuspended, isFalse);
    });

    test('resumed only fires after a prior suspend edge', () {
      final coordinator = AppVisibilityCoordinator();
      var suspendCalls = 0;
      var resumeCalls = 0;

      final firstResumeEdge = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );
      final hiddenEdge = coordinator.handleLifecycleState(
        AppLifecycleState.hidden,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );
      final secondResumeEdge = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );
      final thirdResumeEdge = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
        onSuspend: () => suspendCalls++,
        onResume: () => resumeCalls++,
      );

      expect(suspendCalls, 1);
      expect(resumeCalls, 1);
      expect(firstResumeEdge, AppVisibilityEdge.none);
      expect(hiddenEdge, AppVisibilityEdge.suspended);
      expect(secondResumeEdge, AppVisibilityEdge.resumed);
      expect(thirdResumeEdge, AppVisibilityEdge.none);
      expect(coordinator.isSuspended, isFalse);
    });
  });
}
