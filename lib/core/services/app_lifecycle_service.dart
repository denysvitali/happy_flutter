import 'package:riverpod/riverpod.dart';

import '../providers/artifacts_notifier.dart';
import '../providers/current_session_notifier.dart';
import '../providers/feed_notifier.dart';
import '../providers/friends_notifier.dart';
import '../providers/machines_notifier.dart';
import '../providers/profile_notifier.dart';
import '../providers/session_git_status_notifier.dart';
import '../providers/sessions_notifier.dart';
import '../providers/settings_notifier.dart';
import '../providers/todo_notifier.dart';

/// Coordinates notifier state in response to app lifecycle events (auth
/// changes). Keeps [AuthStateNotifier] decoupled from individual data-domain
/// providers — auth shouldn't know about artifacts, friends, or git status.
abstract final class AppLifecycleService {
  /// Populates all domain notifiers from the in-memory sync state.
  ///
  /// Call this after a successful auth restore or login, once the initial
  /// sync data has been loaded into memory.
  static void loadAll(Ref ref) {
    ref.read(sessionsNotifierProvider.notifier).loadFromSync();
    ref.read(machinesNotifierProvider.notifier).loadFromSync();
    ref.read(settingsNotifierProvider.notifier).loadFromSync();
    ref.read(profileNotifierProvider.notifier).loadFromSync();
  }

  /// Clears all domain notifier state on sign-out.
  static void clearAll(Ref ref) {
    ref.read(sessionsNotifierProvider.notifier).clear();
    ref.read(machinesNotifierProvider.notifier).clear();
    ref.read(profileNotifierProvider.notifier).clear();
    ref.read(friendsNotifierProvider.notifier).clear();
    ref.read(feedNotifierProvider.notifier).clear();
    ref.read(settingsNotifierProvider.notifier).clear();
    ref.read(currentSessionNotifierProvider.notifier).clear();
    ref.read(artifactsNotifierProvider.notifier).clear();
    ref.read(todoStateNotifierProvider.notifier).clear();
    ref.read(sessionGitStatusNotifierProvider.notifier).clear();
  }
}
