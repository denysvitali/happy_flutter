import 'package:riverpod/riverpod.dart';

import '../models/settings.dart';
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

  void clear() {
    state = Settings();
  }

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.dataChangeCounter;
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
    state = _updateSetting(state, key, value);
    await _storage.updateSetting(key, value);

    // Sync developer mode to logger so DevLogsScreen can capture all logs
    // even in release builds when developer mode is enabled.
    if (key == 'developerModeEnabled') {
      logger.setDeveloperMode(value as bool);
    }

    if (sync.isInitialized) {
      // Profiles must be serialized to JSON maps for applySettings.
      final syncValue = key == 'profiles'
          ? (value as List<AIBackendProfile>).map((p) => p.toJson()).toList()
          : value;
      await sync.applySettings({key: syncValue});
    }
  }

  Settings _updateSetting(Settings settings, String key, dynamic value) {
    // Use copyWith for immutable state updates
    return switch (key) {
      'schemaVersion' => settings.copyWith(schemaVersion: value as int),
      'themeMode' => settings.copyWith(themeMode: value as String),
      'viewInline' => settings.copyWith(viewInline: value as bool),
      'inferenceOpenAIKey' => settings.copyWith(
        inferenceOpenAIKey: value as String?,
      ),
      'expandTodos' => settings.copyWith(expandTodos: value as bool),
      'showLineNumbers' => settings.copyWith(showLineNumbers: value as bool),
      'showLineNumbersInToolViews' => settings.copyWith(
        showLineNumbersInToolViews: value as bool,
      ),
      'wrapLinesInDiffs' => settings.copyWith(wrapLinesInDiffs: value as bool),
      'analyticsOptOut' => settings.copyWith(analyticsOptOut: value as bool),
      'experiments' => settings.copyWith(experiments: value as bool),
      'markdownCopyV2' => settings.copyWith(markdownCopyV2: value as bool),
      'useEnhancedSessionWizard' => settings.copyWith(
        useEnhancedSessionWizard: value as bool,
      ),
      'alwaysShowContextSize' => settings.copyWith(
        alwaysShowContextSize: value as bool,
      ),
      'agentInputEnterToSend' => settings.copyWith(
        agentInputEnterToSend: value as bool,
      ),
      'developerModeEnabled' => settings.copyWith(
        developerModeEnabled: value as bool,
      ),
      'avatarStyle' => settings.copyWith(avatarStyle: value as String),
      'showFlavorIcons' => settings.copyWith(showFlavorIcons: value as bool),
      'compactSessionView' => settings.copyWith(
        compactSessionView: value as bool,
      ),
      'hideInactiveSessions' => settings.copyWith(
        hideInactiveSessions: value as bool,
      ),
      'reviewPromptAnswered' => settings.copyWith(
        reviewPromptAnswered: value as bool,
      ),
      'reviewPromptLikedApp' => settings.copyWith(
        reviewPromptLikedApp: value as bool?,
      ),
      'ttsEnabled' => settings.copyWith(ttsEnabled: value as bool),
      'voiceAssistantLanguage' => settings.copyWith(
        voiceAssistantLanguage: value as String?,
      ),
      'preferredLanguage' => settings.copyWith(
        preferredLanguage: value as String?,
      ),
      'usagePeriod' => settings.copyWith(usagePeriod: value as String),
      'lastUsedAgent' => settings.copyWith(lastUsedAgent: value as String?),
      'lastUsedPermissionMode' => settings.copyWith(
        lastUsedPermissionMode: value as String?,
      ),
      'lastUsedModelMode' => settings.copyWith(
        lastUsedModelMode: value as String?,
      ),
      'lastUsedProfile' => settings.copyWith(lastUsedProfile: value),
      'profiles' => settings.copyWith(
        profiles: value as List<AIBackendProfile>,
      ),
      _ => settings,
    };
  }
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, Settings>(
  () {
    return SettingsNotifier();
  },
);
