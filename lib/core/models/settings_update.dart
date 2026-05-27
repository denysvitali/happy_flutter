import 'settings.dart';

/// Thrown by [SettingsUpdate.copyWithUpdated] when [key] is not part of
/// the current `Settings` schema.
///
/// Callers that read keys from untrusted sources (persisted JSON on
/// disk, server echoes, socket pushes from older or newer app versions)
/// should catch this and treat it as a forward/backward compatibility
/// signal rather than a programmer error — see
/// `SettingsNotifier.applyRemoteSettingsPatch` and
/// `SettingsStorage.updateSetting`.
class UnknownSettingsKeyException implements Exception {
  const UnknownSettingsKeyException(this.key);

  final String key;

  @override
  String toString() =>
      'UnknownSettingsKeyException: Unknown settings key: "$key"';
}

/// Shared settings mutation helpers used by providers and storage.
///
/// Keeping this mapping in one place prevents provider/storage drift.
/// Unknown keys throw [UnknownSettingsKeyException]; callers handling
/// untrusted input (e.g. legacy persisted JSON, server echoes) catch it
/// and drop the offending key so a renamed/removed setting never
/// crashes the app on startup.
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
      'toolCallDebugEnabled' => settings.copyWith(
        toolCallDebugEnabled: value as bool,
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
      'ttsUseOffline' => settings.copyWith(ttsUseOffline: value as bool),
      'voiceAssistantLanguage' => settings.copyWith(
        voiceAssistantLanguage: value as String?,
      ),
      'ttsEngine' => settings.copyWith(ttsEngine: value as String?),
      'ttsVoiceId' => settings.copyWith(ttsVoiceId: value as String?),
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
      _ => throw UnknownSettingsKeyException(key),
    };
  }

  /// Returns true when [key] is part of the current `Settings` schema and
  /// can be passed to [copyWithUpdated] / [applyMutable] without throwing
  /// [UnknownSettingsKeyException]. Callers that load persisted JSON or
  /// remote patches can use this to skip legacy keys defensively.
  static bool isKnownKey(String key) {
    try {
      copyWithUpdated(Settings(), key, null);
      return true;
    } on UnknownSettingsKeyException {
      return false;
    } on TypeError {
      // The dispatcher casts `value` to its expected runtime type, so
      // passing `null` for a non-nullable field throws TypeError. That
      // still confirms the key itself is known.
      return true;
    }
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
      ..toolCallDebugEnabled = updated.toolCallDebugEnabled
      ..avatarStyle = updated.avatarStyle
      ..showFlavorIcons = updated.showFlavorIcons
      ..compactSessionView = updated.compactSessionView
      ..sessionsViewStyle = updated.sessionsViewStyle
      ..hideInactiveSessions = updated.hideInactiveSessions
      ..reviewPromptAnswered = updated.reviewPromptAnswered
      ..reviewPromptLikedApp = updated.reviewPromptLikedApp
      ..ttsEnabled = updated.ttsEnabled
      ..ttsUseOffline = updated.ttsUseOffline
      ..voiceAssistantLanguage = updated.voiceAssistantLanguage
      ..ttsEngine = updated.ttsEngine
      ..ttsVoiceId = updated.ttsVoiceId
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
      'profiles' => _profilesToJsonCached(value as List<AIBackendProfile>),
      _ => value,
    };
  }

  /// Cache `profiles.toJson()` keyed by the profiles list identity.
  ///
  /// `SettingsNotifier.updateSetting` is called on every settings sync
  /// fan-out and serializes the profiles list each time even when it is
  /// the exact same instance. The cache short-circuits repeated calls
  /// for the same list reference; mutating the profiles list reference
  /// (e.g. `settings.profiles = [...]`) invalidates the cache naturally
  /// because the Expando is keyed by list identity (perf #11).
  static List<Map<String, dynamic>> _profilesToJsonCached(
    List<AIBackendProfile> profiles,
  ) {
    final cached = _profilesJsonCache[profiles];
    if (cached != null) return cached;
    final encoded = profiles.map((p) => p.toJson()).toList(growable: false);
    _profilesJsonCache[profiles] = encoded;
    return encoded;
  }

  static final Expando<List<Map<String, dynamic>>> _profilesJsonCache =
      Expando<List<Map<String, dynamic>>>('SettingsUpdate.profilesJsonCache');
}
