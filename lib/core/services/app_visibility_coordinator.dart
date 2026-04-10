import 'package:flutter/widgets.dart';

/// Maps Flutter lifecycle states to a single suspend/resume edge.
///
/// Flutter can emit `hidden -> paused` when the app backgrounds and may send
/// repeated lifecycle callbacks during OS transitions. We only want one
/// logical suspend until the app is visible again.
class AppVisibilityCoordinator {
  bool _isSuspended = false;

  bool get isSuspended => _isSuspended;

  void handleLifecycleState(
    AppLifecycleState state, {
    required VoidCallback onSuspend,
    required VoidCallback onResume,
  }) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_isSuspended) {
          return;
        }
        _isSuspended = true;
        onSuspend();
      case AppLifecycleState.resumed:
        if (!_isSuspended) {
          return;
        }
        _isSuspended = false;
        onResume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        return;
    }
  }
}
