import 'package:riverpod/riverpod.dart';

import '../models/session.dart';

class CurrentSessionNotifier extends Notifier<Session?> {
  @override
  Session? build() => null;

  void setSession(Session? session) {
    state = session;
  }

  void updateDraft(String draft) {
    if (state != null) {
      state = state!.copyWith(draft: draft);
    }
  }

  void updatePermissionMode(String? mode) {
    if (state != null) {
      state = state!.copyWith(permissionMode: mode);
    }
  }

  void updateModelMode(String? mode) {
    if (state != null) {
      state = state!.copyWith(modelMode: mode);
    }
  }

  void clear() {
    state = null;
  }
}

final currentSessionNotifierProvider =
    NotifierProvider<CurrentSessionNotifier, Session?>(() {
      return CurrentSessionNotifier();
    });
