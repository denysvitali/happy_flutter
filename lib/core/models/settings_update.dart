import 'settings.dart';

/// Shared settings mutation helpers used by providers and storage.
///
/// Keeping this mapping in one place prevents provider/storage drift and
/// ensures unknown keys fail loudly instead of being ignored.
final class SettingsUpdate {
  const SettingsUpdate._();

  static Settings copyWithUpdated(
    Settings settings,
    String key,
    Object? value,
  ) {
    return switch (key) {
      'schemaVersion' => settings.copyWith(schemaVersion: value as int),
      'themeMode' => settings.copyWith(themeMode: value as String),
      'viewInline' => settings.copyWith(viewInline: value as bool),
      'hideToolCalls' => settings.copyWith(hideToolCalls: value as bool),
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
      'sessionsViewStyle' => settings.copyWith(
        sessionsViewStyle: value as String,
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
      'ttsEngine' => settings.copyWith(ttsEngine: value as String?),
      'preferredLanguage' => settings.copyWith(
        preferredLanguage: value as String?,
      ),
      'usagePeriod' => settings.copyWith(usagePeriod: value as String),
      'recentMachinePaths' => settings.copyWith(
        recentMachinePaths:
            (value as List<dynamic>?)?.cast<RecentMachinePath>() ?? [],
      ),
      'lastUsedAgent' => settings.copyWith(lastUsedAgent: value as String?),
      'lastUsedPermissionMode' => settings.copyWith(
        lastUsedPermissionMode: value as String?,
      ),
      'lastUsedModelMode' => settings.copyWith(
        lastUsedModelMode: value as String?,
      ),
      'profiles' => settings.copyWith(
        profiles: (value as List<dynamic>?)?.cast<AIBackendProfile>() ?? [],
      ),
      'lastUsedProfile' => settings.copyWith(lastUsedProfile: value as String?),
      'lastUsedProfilesByAgent' => settings.copyWith(
        lastUsedProfilesByAgent:
            (value as Map<dynamic, dynamic>?)?.cast<String, String>() ?? {},
      ),
      'favoriteDirectories' => settings.copyWith(
        favoriteDirectories: (value as List<dynamic>?)?.cast<String>() ?? [],
      ),
      'favoriteMachines' => settings.copyWith(
        favoriteMachines: (value as List<dynamic>?)?.cast<String>() ?? [],
      ),
      'folders' => settings.copyWith(
        folders: (value as List<dynamic>?)?.cast<String>() ?? [],
      ),
      'dismissedCLIWarnings' => settings.copyWith(
        dismissedCLIWarnings: value as DismissedCLIWarnings,
      ),
      _ => throw ArgumentError.value(key, 'key', 'Unknown settings key'),
    };
  }

  static void applyMutable(Settings settings, String key, Object? value) {
    final updated = copyWithUpdated(settings, key, value);
    settings
      ..schemaVersion = updated.schemaVersion
      ..themeMode = updated.themeMode
      ..viewInline = updated.viewInline
      ..hideToolCalls = updated.hideToolCalls
      ..inferenceOpenAIKey = updated.inferenceOpenAIKey
      ..expandTodos = updated.expandTodos
      ..showLineNumbers = updated.showLineNumbers
      ..showLineNumbersInToolViews = updated.showLineNumbersInToolViews
      ..wrapLinesInDiffs = updated.wrapLinesInDiffs
      ..analyticsOptOut = updated.analyticsOptOut
      ..experiments = updated.experiments
      ..markdownCopyV2 = updated.markdownCopyV2
      ..useEnhancedSessionWizard = updated.useEnhancedSessionWizard
      ..alwaysShowContextSize = updated.alwaysShowContextSize
      ..agentInputEnterToSend = updated.agentInputEnterToSend
      ..developerModeEnabled = updated.developerModeEnabled
      ..avatarStyle = updated.avatarStyle
      ..showFlavorIcons = updated.showFlavorIcons
      ..compactSessionView = updated.compactSessionView
      ..sessionsViewStyle = updated.sessionsViewStyle
      ..hideInactiveSessions = updated.hideInactiveSessions
      ..reviewPromptAnswered = updated.reviewPromptAnswered
      ..reviewPromptLikedApp = updated.reviewPromptLikedApp
      ..ttsEnabled = updated.ttsEnabled
      ..voiceAssistantLanguage = updated.voiceAssistantLanguage
      ..ttsEngine = updated.ttsEngine
      ..preferredLanguage = updated.preferredLanguage
      ..usagePeriod = updated.usagePeriod
      ..recentMachinePaths = updated.recentMachinePaths
      ..lastUsedAgent = updated.lastUsedAgent
      ..lastUsedPermissionMode = updated.lastUsedPermissionMode
      ..lastUsedModelMode = updated.lastUsedModelMode
      ..profiles = updated.profiles
      ..lastUsedProfile = updated.lastUsedProfile
      ..lastUsedProfilesByAgent = updated.lastUsedProfilesByAgent
      ..favoriteDirectories = updated.favoriteDirectories
      ..favoriteMachines = updated.favoriteMachines
      ..folders = updated.folders
      ..dismissedCLIWarnings = updated.dismissedCLIWarnings;
  }

  static Object? toSyncValue(String key, Object? value) {
    return switch (key) {
      'profiles' =>
        (value as List<AIBackendProfile>).map((p) => p.toJson()).toList(),
      _ => value,
    };
  }
}
