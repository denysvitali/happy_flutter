import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/app_visibility_coordinator.dart';

void main() {
  late AppVisibilityCoordinator coordinator;

  setUp(() {
    coordinator = AppVisibilityCoordinator();
    AppFocusState.instance.setFocused(true);
  });

  AppVisibilityEdge lifecycle(AppLifecycleState state) =>
      coordinator.handleLifecycleState(
        state,
        onSuspend: () {},
        onResume: () {},
      );

  test('starts focused and unfocused by default', () {
    expect(coordinator.isFocused, isTrue);
    expect(coordinator.isSuspended, isFalse);
  });

  test('inactive clears focus but does not suspend', () {
    // Desktop focus loss: the window is still visible and the socket must
    // keep streaming, so this must NOT be a suspend edge.
    expect(lifecycle(AppLifecycleState.inactive), AppVisibilityEdge.none);
    expect(coordinator.isSuspended, isFalse);
    expect(coordinator.isFocused, isFalse);
  });

  test('detached clears focus without suspending', () {
    expect(lifecycle(AppLifecycleState.detached), AppVisibilityEdge.none);
    expect(coordinator.isFocused, isFalse);
  });

  test('paused suspends and is therefore not focused', () {
    expect(lifecycle(AppLifecycleState.paused), AppVisibilityEdge.suspended);
    expect(coordinator.isSuspended, isTrue);
    expect(coordinator.isFocused, isFalse);
  });

  test('resumed after a suspend restores focus', () {
    lifecycle(AppLifecycleState.paused);
    expect(lifecycle(AppLifecycleState.resumed), AppVisibilityEdge.resumed);
    expect(coordinator.isSuspended, isFalse);
    expect(coordinator.isFocused, isTrue);
  });

  test('resumed without a prior suspend does not emit an edge', () {
    // `resumed` is a no-op when we were never suspended (Flutter can deliver
    // it on platforms that skip `paused`), and it must not resurrect focus
    // that a desktop `inactive` deliberately cleared.
    lifecycle(AppLifecycleState.inactive);
    expect(lifecycle(AppLifecycleState.resumed), AppVisibilityEdge.none);
    expect(coordinator.isFocused, isFalse);
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
    lifecycle(AppLifecycleState.resumed); // no suspend first: no edge
    lifecycle(AppLifecycleState.paused); // -> false (already)
    lifecycle(AppLifecycleState.resumed); // -> true

    expect(seen, [false, true]);
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
