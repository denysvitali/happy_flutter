import 'package:flutter/widgets.dart';

/// Process-wide app focus, so any screen can ask "is anyone looking?"
/// without reaching into the root widget's state.
///
/// Driven by the root observer in `main.dart` from
/// [AppLifecycleState.inactive] (desktop focus loss) and the paused/resumed
/// edge. It is intentionally *not* the same as "is the app suspended": a
/// suspended app has no socket to receive data from, while a merely unfocused
/// desktop window is still streaming and would otherwise repaint on every
/// token. See [AppVisibilityCoordinator.isFocused].
class AppFocusState {
  AppFocusState._();

  static final AppFocusState instance = AppFocusState._();

  final List<VoidCallback> _listeners = [];
  bool _isFocused = true;

  /// False while the app is backgrounded or the desktop window is unfocused.
  bool get isFocused => _isFocused;

  void setFocused(bool value) {
    if (_isFocused == value) return;
    _isFocused = value;
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

enum AppVisibilityEdge { none, suspended, resumed }

/// Maps Flutter lifecycle states to a single suspend/resume edge.
///
/// Flutter can emit `hidden -> paused` when the app backgrounds and may send
/// repeated lifecycle callbacks during OS transitions. We only want one
/// logical suspend until the app is visible again.
///
/// [isFocused] is deliberately distinct from [isSuspended]. `inactive` means
/// a desktop window lost OS focus but the app keeps running and receiving
/// socket traffic; suspending there would drop the socket and break a live
/// session. It still, however, means nobody is looking at the pixels, so
/// callers that only *paint* (rebuild a screen from Sync state) should skip
/// the work until focus returns. See `SessionsScreen`'s focus gate.
class AppVisibilityCoordinator {
  bool _isSuspended = false;
  bool _isFocused = true;
  final List<VoidCallback> _focusListeners = [];

  bool get isSuspended => _isSuspended;

  /// True while the app can paint something a human is looking at.
  ///
  /// Mobile: false only once `paused`/`hidden`. Desktop: also false while
  /// the window is visible but unfocused (`inactive`).
  bool get isFocused => _isFocused && !_isSuspended;

  /// Notifies when [isFocused] flips, so a caller can catch up on whatever
  /// it skipped while unfocused.
  void addFocusListener(VoidCallback listener) =>
      _focusListeners.add(listener);

  void removeFocusListener(VoidCallback listener) =>
      _focusListeners.remove(listener);

  void _setFocused(bool value) {
    if (_isFocused == value) return;
    _isFocused = value;
    AppFocusState.instance.setFocused(isFocused);
    for (final listener in List<VoidCallback>.of(_focusListeners)) {
      listener();
    }
  }

  AppVisibilityEdge handleLifecycleState(
    AppLifecycleState state, {
    required VoidCallback onSuspend,
    required VoidCallback onResume,
  }) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_isSuspended) {
          return AppVisibilityEdge.none;
        }
        _isSuspended = true;
        onSuspend();
        return AppVisibilityEdge.suspended;
      case AppLifecycleState.resumed:
        if (!_isSuspended) {
          return AppVisibilityEdge.none;
        }
        _isSuspended = false;
        _setFocused(true);
        onResume();
        return AppVisibilityEdge.resumed;
      case AppLifecycleState.inactive:
        // Desktop focus loss: stay connected and subscribed (a live session
        // must keep streaming), but stop painting.
        _setFocused(false);
        return AppVisibilityEdge.none;
      case AppLifecycleState.detached:
        _setFocused(false);
        return AppVisibilityEdge.none;
    }
  }
}
