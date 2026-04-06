import 'package:riverpod/riverpod.dart';

import '../models/settings.dart';
import '../models/settings_update.dart';
import '../services/logger_service.dart' show logger;
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class SettingsNotifier extends Notifier<Settings> {
  final _storage = SettingsStorage();
  int _lastDataChangeCounter = -1;

  @override
  Settings build() => Settings();

  Future<void> loadSettings() async {
    final settings = await _storage.getSettings();
    state = settings;
    // Sync developer mode to logger so DevLogsScreen captures all logs
    // even in release builds when developer mode was enabled previously.
    logger.setDeveloperMode(settings.developerModeEnabled);
  }

  Future<void> loadLocalSettings() async {
    final settings = await _storage.getLocalSettings();
    state = settings;
    logger.setDeveloperMode(settings.developerModeEnabled);
  }

  void clear() {
    state = Settings();
  }

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.domainChangeCounter(SyncDomain.settings);
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.settingsSnapshot;
    if (state == next) return;
    // Preserve local-only settings that the server doesn't
    // know about — sync.settingsSnapshot defaults them to
    // false, which overwrites the user's local choice.
    final preserved = next.copyWith(
      developerModeEnabled: state.developerModeEnabled,
    );
    state = preserved;
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    try {
      await sync.settingsSync.invalidateAndAwait();
    } catch (e, stack) {
      logger.warning('Failed to refresh settings', e, stack);
    }
    loadFromSync();
  }

  Future<void> updateSetting<T>(String key, T value) async {
    // Update provider state synchronously (before yielding to the event
    // loop) so that other screens see the change immediately.  Without
    // this, callers that use `unawaited(updateSetting(...))` would leave
    // a window where `ref.read(settingsNotifierProvider)` still returns
    // the old value — e.g. NewSessionScreen reading `lastUsedProfile`.
    state = SettingsUpdate.copyWithUpdated(state, key, value);
    await _storage.updateSetting(key, value);

    // Sync developer mode to logger so DevLogsScreen can capture all logs
    // even in release builds when developer mode is enabled.
    if (key == 'developerModeEnabled') {
      logger.setDeveloperMode(value as bool);
    }

    if (sync.isInitialized) {
      final syncValue = SettingsUpdate.toSyncValue(key, value);
      await sync.applySettings({key: syncValue});
    }
  }
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, Settings>(
  () {
    return SettingsNotifier();
  },
);
