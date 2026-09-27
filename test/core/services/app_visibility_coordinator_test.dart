import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/app_visibility_coordinator.dart';

void main() {
  late AppVisibilityCoordinator coordinator;
  var suspends = 0;
  var resumes = 0;

  setUp(() {
    coordinator = AppVisibilityCoordinator();
    AppFocusState.instance.setFocused(true);
    suspends = 0;
    resumes = 0;
  });

  AppVisibilityEdge lifecycle(AppLifecycleState state) =>
      coordinator.handleLifecycleState(
        state,
        onSuspend: () => suspends++,
        onResume: () => resumes++,
      );

  test('starts focused and not suspended by default', () {
    expect(coordinator.isFocused, isTrue);
    expect(coordinator.isSuspended, isFalse);
  });

  test('inactive clears focus but does not suspend', () {
    // Desktop focus loss: the window is still visible and the socket must
    // keep streaming, so this must NOT be a suspend edge.
    expect(lifecycle(AppLifecycleState.inactive), AppVisibilityEdge.none);
    expect(coordinator.isSuspended, isFalse);
    expect(coordinator.isFocused, isFalse);
    expect(AppFocusState.instance.isFocused, isFalse);
    expect(suspends, 0);
    expect(resumes, 0);
  });

  test('detached clears focus without suspending', () {
    expect(lifecycle(AppLifecycleState.detached), AppVisibilityEdge.none);
    expect(coordinator.isFocused, isFalse);
  });

  test('paused suspends and is therefore not focused', () {
    expect(lifecycle(AppLifecycleState.paused), AppVisibilityEdge.suspended);
    expect(coordinator.isSuspended, isTrue);
    expect(coordinator.isFocused, isFalse);
    expect(AppFocusState.instance.isFocused, isFalse);
    expect(suspends, 1);
  });

  test('resumed after a suspend restores focus', () {
    lifecycle(AppLifecycleState.paused);
    expect(lifecycle(AppLifecycleState.resumed), AppVisibilityEdge.resumed);
    expect(coordinator.isSuspended, isFalse);
    expect(coordinator.isFocused, isTrue);
    expect(AppFocusState.instance.isFocused, isTrue);
    expect(resumes, 1);
  });

  test('desktop refocus restores focus without reconnecting the socket', () {
    lifecycle(AppLifecycleState.inactive);
    expect(lifecycle(AppLifecycleState.resumed), AppVisibilityEdge.none);
    expect(coordinator.isFocused, isTrue);
    expect(AppFocusState.instance.isFocused, isTrue);
    expect(suspends, 0);
    expect(resumes, 0);
  });

  test('hidden and paused publish one focus and suspend transition', () {
    final globalFocus = <bool>[];
    final localFocus = <bool>[];
    void globalListener() => globalFocus.add(AppFocusState.instance.isFocused);
    void localListener() => localFocus.add(coordinator.isFocused);
    AppFocusState.instance.addListener(globalListener);
    coordinator.addFocusListener(localListener);
    addTearDown(() {
      AppFocusState.instance.removeListener(globalListener);
      coordinator.removeFocusListener(localListener);
    });

    expect(lifecycle(AppLifecycleState.hidden), AppVisibilityEdge.suspended);
    expect(lifecycle(AppLifecycleState.paused), AppVisibilityEdge.none);
    expect(lifecycle(AppLifecycleState.hidden), AppVisibilityEdge.none);
    expect(AppFocusState.instance.isFocused, isFalse);
    expect(lifecycle(AppLifecycleState.resumed), AppVisibilityEdge.resumed);
    expect(lifecycle(AppLifecycleState.resumed), AppVisibilityEdge.none);

    expect(globalFocus, [false, true]);
    expect(localFocus, [false, true]);
    expect(suspends, 1);
    expect(resumes, 1);
  });

  test('repeated inactive does not re-notify focus listeners', () {
    var notifications = 0;
    final listener = () => notifications++;
    AppFocusState.instance.addListener(listener);
    addTearDown(() => AppFocusState.instance.removeListener(listener));

    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.inactive);
    expect(notifications, 1);
  });

  test('focus listeners fire once per real transition', () {
    final seen = <bool>[];
    final listener = () => seen.add(AppFocusState.instance.isFocused);
    AppFocusState.instance.addListener(listener);
    addTearDown(() => AppFocusState.instance.removeListener(listener));

    lifecycle(AppLifecycleState.inactive); // -> false
    lifecycle(AppLifecycleState.detached); // still false, no event
    lifecycle(AppLifecycleState.resumed); // -> true, without a network edge
    lifecycle(AppLifecycleState.paused); // -> false
    lifecycle(AppLifecycleState.resumed); // -> true

    expect(seen, [false, true, false, true]);
  });

  test('duplicate focus listener registration still fires per transition', () {
    var calls = 0;
    void listener() => calls++;
    coordinator.addFocusListener(listener);
    coordinator.addFocusListener(listener);
    addTearDown(() => coordinator.removeFocusListener(listener));

    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.inactive);
    // Registered twice, so two calls — but the transition itself fired once.
    expect(calls, 2);
  });
}
