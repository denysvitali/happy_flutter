import 'package:riverpod/riverpod.dart';

import '../models/profile.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

class ProfileNotifier extends Notifier<Profile?> {
  int _lastDataChangeCounter = -1;

  @override
  Profile? build() => null;

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.dataChangeCounter;
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.profile;
    if (state == next) return;
    state = next;
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    try {
      await sync.profileSync.invalidateAndAwait();
    } catch (e) {
      logger.warning('Failed to refresh profile: $e');
    }
    loadFromSync();
  }

  void updateProfile(Profile profile) {
    state = profile;
  }

  Future<void> updateAvatar(String avatarUrl) async {
    if (state != null) {
      // Create a new ImageRef with minimal data from URL
      final newAvatar = ImageRef(
        width: state!.avatar?.width ?? 200,
        height: state!.avatar?.height ?? 200,
        thumbhash: state!.avatar?.thumbhash ?? '',
        path: state!.avatar?.path ?? '',
        url: avatarUrl,
      );
      state = state!.copyWith(avatar: newAvatar);
    }
  }

  Future<void> disconnectGitHub() async {
    if (state != null && state!.github != null) {
      state = state!.copyWith(clearGithub: true);
    }
  }

  void clear() {
    state = null;
  }
}

final profileNotifierProvider = NotifierProvider<ProfileNotifier, Profile?>(() {
  return ProfileNotifier();
});
