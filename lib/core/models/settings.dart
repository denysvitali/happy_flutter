// Settings model matching the original Zod schema
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'settings.g.dart';

// Sentinel used in copyWith to distinguish "not provided" from explicit null.
const Object _unset = Object();

/// Settings model — mutable fields, not freezed.
/// Uses @JsonSerializable for fromJson/toJson generation only.
///
/// Note: inferenceOpenAIKey is intentionally excluded from toJson
/// (stored in secure storage). API keys in nested configs are also
/// excluded via toJsonWithoutApiKeys().
@JsonSerializable(explicitToJson: true, includeIfNull: true)
class Settings {
  Settings();

  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(_normalizeSettingsJson(json));

  factory Settings.fromJsonWithFallback(
    Map<String, dynamic> json,
    Settings fallback,
  ) =>
      _$SettingsFromJson(
        _normalizeSettingsJson(json, fallback: fallback.toJson()),
      );

  int schemaVersion = 2;
  String themeMode = 'system';
  bool viewInline = false;
  bool hideToolCalls = false;
  @JsonKey(includeToJson: false)
  String? inferenceOpenAIKey;
  bool expandTodos = true;
  bool showLineNumbers = true;
  bool showLineNumbersInToolViews = false;
  bool wrapLinesInDiffs = false;
  bool analyticsOptOut = false;
  bool experiments = false;
  bool markdownCopyV2 = false;
  bool useEnhancedSessionWizard = false;
  bool alwaysShowContextSize = false;
  bool agentInputEnterToSend = false;
  bool developerModeEnabled = false;
  bool toolCallDebugEnabled = false;
  String avatarStyle = 'brutalist';
  bool showFlavorIcons = false;
  bool compactSessionView = false;
  String sessionsViewStyle = 'mission_control';
  bool hideInactiveSessions = false;
  bool reviewPromptAnswered = false;
  bool? reviewPromptLikedApp;
  bool ttsEnabled = false;
  bool ttsUseOffline = true;
  String? voiceAssistantLanguage;
  String? ttsEngine;
  String? ttsVoiceId;
  String? sttModelId;
  String? preferredLanguage;
  String usagePeriod = 'thirtyDays';

  /// Alias for preferredLanguage to maintain compatibility
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get locale => preferredLanguage ?? '';
  set locale(String value) {
    preferredLanguage = value.isEmpty ? null : value;
  }

  List<RecentMachinePath> recentMachinePaths = [];
  String? lastUsedAgent;
  String? lastUsedPermissionMode;
  String? lastUsedModelMode;
  List<String> customModelModes = [];
  // Profile API keys excluded from serialization via toJsonWithoutApiKeys()
  List<AIBackendProfile> profiles = [];
  String? lastUsedProfile;
  Map<String, String> lastUsedProfilesByAgent = {};
  List<String> favoriteDirectories = ['~/src', '~/Desktop', '~/Documents'];
  List<String> favoriteMachines = [];
  List<String> folders = [];
  DismissedCLIWarnings dismissedCLIWarnings = DismissedCLIWarnings();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settings &&
          schemaVersion == other.schemaVersion &&
          themeMode == other.themeMode &&
          viewInline == other.viewInline &&
          hideToolCalls == other.hideToolCalls &&
          inferenceOpenAIKey == other.inferenceOpenAIKey &&
          expandTodos == other.expandTodos &&
          showLineNumbers == other.showLineNumbers &&
          showLineNumbersInToolViews == other.showLineNumbersInToolViews &&
          wrapLinesInDiffs == other.wrapLinesInDiffs &&
          analyticsOptOut == other.analyticsOptOut &&
          experiments == other.experiments &&
          markdownCopyV2 == other.markdownCopyV2 &&
          useEnhancedSessionWizard == other.useEnhancedSessionWizard &&
          alwaysShowContextSize == other.alwaysShowContextSize &&
          agentInputEnterToSend == other.agentInputEnterToSend &&
          developerModeEnabled == other.developerModeEnabled &&
          toolCallDebugEnabled == other.toolCallDebugEnabled &&
          avatarStyle == other.avatarStyle &&
          showFlavorIcons == other.showFlavorIcons &&
          compactSessionView == other.compactSessionView &&
          sessionsViewStyle == other.sessionsViewStyle &&
          hideInactiveSessions == other.hideInactiveSessions &&
          ttsEnabled == other.ttsEnabled &&
          ttsUseOffline == other.ttsUseOffline &&
          voiceAssistantLanguage == other.voiceAssistantLanguage &&
          ttsEngine == other.ttsEngine &&
          ttsVoiceId == other.ttsVoiceId &&
          sttModelId == other.sttModelId &&
          preferredLanguage == other.preferredLanguage &&
          usagePeriod == other.usagePeriod &&
          lastUsedAgent == other.lastUsedAgent &&
          lastUsedPermissionMode == other.lastUsedPermissionMode &&
          lastUsedModelMode == other.lastUsedModelMode &&
          customModelModes.length == other.customModelModes.length &&
          customModelModes.asMap().entries.every(
            (e) => e.value == other.customModelModes[e.key],
          ) &&
          lastUsedProfile == other.lastUsedProfile &&
          _stringMapsEqual(
            lastUsedProfilesByAgent,
            other.lastUsedProfilesByAgent,
          ) &&
          folders == other.folders &&
          profiles.length == other.profiles.length &&
          profiles.asMap().entries.every(
            (e) => identical(e.value, other.profiles[e.key]),
          );

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    themeMode,
    viewInline,
    hideToolCalls,
    expandTodos,
    showLineNumbers,
    analyticsOptOut,
    avatarStyle,
    compactSessionView,
    sessionsViewStyle,
    hideInactiveSessions,
    ttsEnabled,
    preferredLanguage,
    usagePeriod,
    lastUsedProfile,
    Object.hashAll(
      lastUsedProfilesByAgent.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAll(folders),
    Object.hashAll(profiles),
  );

  String? lastUsedProfileForAgent(String? agent) {
    final key = normalizeAgentKey(agent);
    final scopedProfile = lastUsedProfilesByAgent[key];
    if (scopedProfile != null) return scopedProfile;

    // Migration fallback for settings saved before profiles were scoped.
    final legacyAgent = normalizeAgentKey(lastUsedAgent);
    if (legacyAgent == key) return lastUsedProfile;
    return null;
  }

  Map<String, String> lastUsedProfilesWithAgent(
    String? agent,
    String? profileId,
  ) {
    final key = normalizeAgentKey(agent);
    final next = Map<String, String>.from(lastUsedProfilesByAgent);
    if (profileId == null) {
      next.remove(key);
    } else {
      next[key] = profileId;
    }
    return next;
  }

  /// Custom toJson that excludes API keys from profiles
  Map<String, dynamic> toJson() {
    final json = _$SettingsToJson(this);
    // Replace profiles with API-key-stripped versions
    json['profiles'] = profiles.map((e) => e.toJsonWithoutApiKeys()).toList();
    return json;
  }

  /// Shallow clone — used to detach the cached snapshot from callers
  /// that might mutate top-level fields. Collection fields are shallow
  /// copies so caller mutation of the list/map doesn't leak back into
  /// the cache; element objects (e.g. AIBackendProfile) are shared
  /// since they are effectively immutable (`final` fields).
  ///
  /// This replaces the previous `Settings.fromJson(toJson())` clone,
  /// which round-tripped through JSON encoding for the same effect.
  Settings shallowClone() {
    return Settings()
      ..schemaVersion = schemaVersion
      ..themeMode = themeMode
      ..viewInline = viewInline
      ..hideToolCalls = hideToolCalls
      ..inferenceOpenAIKey = inferenceOpenAIKey
      ..expandTodos = expandTodos
      ..showLineNumbers = showLineNumbers
      ..showLineNumbersInToolViews = showLineNumbersInToolViews
      ..wrapLinesInDiffs = wrapLinesInDiffs
      ..analyticsOptOut = analyticsOptOut
      ..experiments = experiments
      ..markdownCopyV2 = markdownCopyV2
      ..useEnhancedSessionWizard = useEnhancedSessionWizard
      ..alwaysShowContextSize = alwaysShowContextSize
      ..agentInputEnterToSend = agentInputEnterToSend
      ..developerModeEnabled = developerModeEnabled
      ..toolCallDebugEnabled = toolCallDebugEnabled
      ..avatarStyle = avatarStyle
      ..showFlavorIcons = showFlavorIcons
      ..compactSessionView = compactSessionView
      ..sessionsViewStyle = sessionsViewStyle
      ..hideInactiveSessions = hideInactiveSessions
      ..reviewPromptAnswered = reviewPromptAnswered
      ..reviewPromptLikedApp = reviewPromptLikedApp
      ..ttsEnabled = ttsEnabled
      ..ttsUseOffline = ttsUseOffline
      ..voiceAssistantLanguage = voiceAssistantLanguage
      ..ttsEngine = ttsEngine
      ..ttsVoiceId = ttsVoiceId
      ..sttModelId = sttModelId
      ..preferredLanguage = preferredLanguage
      ..usagePeriod = usagePeriod
      ..recentMachinePaths = List<RecentMachinePath>.from(recentMachinePaths)
      ..lastUsedAgent = lastUsedAgent
      ..lastUsedPermissionMode = lastUsedPermissionMode
      ..lastUsedModelMode = lastUsedModelMode
      ..profiles = List<AIBackendProfile>.from(profiles)
      ..lastUsedProfile = lastUsedProfile
      ..lastUsedProfilesByAgent = Map<String, String>.from(
        lastUsedProfilesByAgent,
      )
      ..favoriteDirectories = List<String>.from(favoriteDirectories)
      ..favoriteMachines = List<String>.from(favoriteMachines)
      ..folders = List<String>.from(folders)
      ..dismissedCLIWarnings = dismissedCLIWarnings;
  }

  Settings copyWith({
    int? schemaVersion,
    String? themeMode,
    bool? viewInline,
    bool? hideToolCalls,
    // Nullable fields use Object? + _unset sentinel so that passing null
    // explicitly clears the field instead of keeping the previous value.
    Object? inferenceOpenAIKey = _unset,
    bool? expandTodos,
    bool? showLineNumbers,
    bool? showLineNumbersInToolViews,
    bool? wrapLinesInDiffs,
    bool? analyticsOptOut,
    bool? experiments,
    bool? markdownCopyV2,
    bool? useEnhancedSessionWizard,
    bool? alwaysShowContextSize,
    bool? agentInputEnterToSend,
    bool? developerModeEnabled,
    bool? toolCallDebugEnabled,
    String? avatarStyle,
    bool? showFlavorIcons,
    bool? compactSessionView,
    String? sessionsViewStyle,
    bool? hideInactiveSessions,
    bool? reviewPromptAnswered,
    Object? reviewPromptLikedApp = _unset,
    bool? ttsEnabled,
    bool? ttsUseOffline,
    Object? voiceAssistantLanguage = _unset,
    Object? ttsEngine = _unset,
    Object? ttsVoiceId = _unset,
    Object? sttModelId = _unset,
    Object? preferredLanguage = _unset,
    String? usagePeriod,
    List<RecentMachinePath>? recentMachinePaths,
    Object? lastUsedAgent = _unset,
    Object? lastUsedPermissionMode = _unset,
    Object? lastUsedModelMode = _unset,
    List<String>? customModelModes,
    List<AIBackendProfile>? profiles,
    Object? lastUsedProfile = _unset,
    Map<String, String>? lastUsedProfilesByAgent,
    List<String>? favoriteDirectories,
    List<String>? favoriteMachines,
    List<String>? folders,
    DismissedCLIWarnings? dismissedCLIWarnings,
  }) {
    return Settings()
      ..schemaVersion = schemaVersion ?? this.schemaVersion
      ..themeMode = themeMode ?? this.themeMode
      ..viewInline = viewInline ?? this.viewInline
      ..hideToolCalls = hideToolCalls ?? this.hideToolCalls
      ..inferenceOpenAIKey = identical(inferenceOpenAIKey, _unset)
          ? this.inferenceOpenAIKey
          : inferenceOpenAIKey as String?
      ..expandTodos = expandTodos ?? this.expandTodos
      ..showLineNumbers = showLineNumbers ?? this.showLineNumbers
      ..showLineNumbersInToolViews =
          showLineNumbersInToolViews ?? this.showLineNumbersInToolViews
      ..wrapLinesInDiffs = wrapLinesInDiffs ?? this.wrapLinesInDiffs
      ..analyticsOptOut = analyticsOptOut ?? this.analyticsOptOut
      ..experiments = experiments ?? this.experiments
      ..markdownCopyV2 = markdownCopyV2 ?? this.markdownCopyV2
      ..useEnhancedSessionWizard =
          useEnhancedSessionWizard ?? this.useEnhancedSessionWizard
      ..alwaysShowContextSize =
          alwaysShowContextSize ?? this.alwaysShowContextSize
      ..agentInputEnterToSend =
          agentInputEnterToSend ?? this.agentInputEnterToSend
      ..developerModeEnabled = developerModeEnabled ?? this.developerModeEnabled
      ..toolCallDebugEnabled =
          toolCallDebugEnabled ?? this.toolCallDebugEnabled
      ..avatarStyle = avatarStyle ?? this.avatarStyle
      ..showFlavorIcons = showFlavorIcons ?? this.showFlavorIcons
      ..compactSessionView = compactSessionView ?? this.compactSessionView
      ..sessionsViewStyle = sessionsViewStyle ?? this.sessionsViewStyle
      ..hideInactiveSessions = hideInactiveSessions ?? this.hideInactiveSessions
      ..reviewPromptAnswered = reviewPromptAnswered ?? this.reviewPromptAnswered
      ..reviewPromptLikedApp = identical(reviewPromptLikedApp, _unset)
          ? this.reviewPromptLikedApp
          : reviewPromptLikedApp as bool?
      ..ttsEnabled = ttsEnabled ?? this.ttsEnabled
      ..ttsUseOffline = ttsUseOffline ?? this.ttsUseOffline
      ..voiceAssistantLanguage = identical(voiceAssistantLanguage, _unset)
          ? this.voiceAssistantLanguage
          : voiceAssistantLanguage as String?
      ..ttsEngine = identical(ttsEngine, _unset)
          ? this.ttsEngine
          : ttsEngine as String?
      ..ttsVoiceId = identical(ttsVoiceId, _unset)
          ? this.ttsVoiceId
          : ttsVoiceId as String?
      ..sttModelId = identical(sttModelId, _unset)
          ? this.sttModelId
          : sttModelId as String?
      ..preferredLanguage = identical(preferredLanguage, _unset)
          ? this.preferredLanguage
          : preferredLanguage as String?
      ..usagePeriod = usagePeriod ?? this.usagePeriod
      ..recentMachinePaths = recentMachinePaths != null
          ? (identical(recentMachinePaths, this.recentMachinePaths)
                ? this.recentMachinePaths
                : List<RecentMachinePath>.from(recentMachinePaths))
          : this.recentMachinePaths
      ..lastUsedAgent = identical(lastUsedAgent, _unset)
          ? this.lastUsedAgent
          : lastUsedAgent as String?
      ..lastUsedPermissionMode = identical(lastUsedPermissionMode, _unset)
          ? this.lastUsedPermissionMode
          : lastUsedPermissionMode as String?
      ..lastUsedModelMode = identical(lastUsedModelMode, _unset)
          ? this.lastUsedModelMode
          : lastUsedModelMode as String?
      ..customModelModes = customModelModes != null
          ? List<String>.from(customModelModes)
          : this.customModelModes
      ..profiles = profiles != null
          ? (identical(profiles, this.profiles)
                ? this.profiles
                : List<AIBackendProfile>.from(profiles))
          : this.profiles
      ..lastUsedProfile = identical(lastUsedProfile, _unset)
          ? this.lastUsedProfile
          : lastUsedProfile as String?
      ..lastUsedProfilesByAgent = lastUsedProfilesByAgent != null
          ? (identical(lastUsedProfilesByAgent, this.lastUsedProfilesByAgent)
                ? this.lastUsedProfilesByAgent
                : Map<String, String>.from(lastUsedProfilesByAgent))
          : this.lastUsedProfilesByAgent
      ..favoriteDirectories = favoriteDirectories != null
          ? (identical(favoriteDirectories, this.favoriteDirectories)
                ? this.favoriteDirectories
                : List<String>.from(favoriteDirectories))
          : this.favoriteDirectories
      ..favoriteMachines = favoriteMachines != null
          ? (identical(favoriteMachines, this.favoriteMachines)
                ? this.favoriteMachines
                : List<String>.from(favoriteMachines))
          : this.favoriteMachines
      ..folders = folders != null
          ? (identical(folders, this.folders)
                ? this.folders
                : List<String>.from(folders))
          : this.folders
      ..dismissedCLIWarnings =
          dismissedCLIWarnings ?? this.dismissedCLIWarnings;
  }
}

String normalizeAgentKey(String? agent) {
  return switch (agent) {
    'codex' => 'codex',
    'gemini' => 'gemini',
    'pi' => 'pi',
    'opencode' => 'opencode',
    'grok' || 'grok-build' => 'grok',
    _ => 'claude',
  };
}

bool _stringMapsEqual(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Cached default-Settings JSON. Defaults are pure (no instance state),
/// so building once and reusing eliminates the per-decode
/// `Settings().toJson()` allocation that previously fired on every
/// settings sync, MMKV restore, and clone.
Map<String, dynamic> _settingsDefaultsCache = _buildDefaultsJson();

Map<String, dynamic> _buildDefaultsJson() => Settings().toJson();

/// Snapshot of expected top-level keys present in default settings JSON.
/// Used by [_normalizeSettingsJson] to decide whether a fast-path
/// short-circuit (skip defaults merge) is safe.
final Set<String> _settingsDefaultKeys = _settingsDefaultsCache.keys.toSet();

@visibleForTesting
void debugResetSettingsDefaultsCache() {
  _settingsDefaultsCache = _buildDefaultsJson();
}

Map<String, dynamic> _normalizeSettingsJson(
  Map<String, dynamic> json, {
  Map<String, dynamic>? fallback,
}) {
  // Defaults are reused across calls — Settings() carries no instance
  // state at construction, so the JSON shape is stable for the process
  // lifetime. Avoid the per-call `Settings().toJson()` allocation.
  final defaults = fallback ?? _settingsDefaultsCache;

  // Fast path: when no fallback is provided and the incoming JSON
  // already contains every expected default key with a non-null value,
  // we can skip the defaults-merge entirely. This is the common case
  // for cache restore and clone paths where the JSON was just produced
  // by `Settings.toJson()`.
  if (fallback == null) {
    var hasAllKeys = true;
    for (final key in _settingsDefaultKeys) {
      if (json[key] == null) {
        hasAllKeys = false;
        break;
      }
    }
    if (hasAllKeys) {
      // Still need list/map shape coercion for hostile inputs — but if
      // every collection key is already a List/Map of the right shape
      // we can return `json` directly. Verify cheaply.
      final lastUsedProfilesByAgent = json['lastUsedProfilesByAgent'];
      final dismissed = json['dismissedCLIWarnings'];
      if (json['recentMachinePaths'] is List &&
          json['profiles'] is List &&
          json['favoriteDirectories'] is List &&
          json['favoriteMachines'] is List &&
          json['folders'] is List &&
          lastUsedProfilesByAgent is Map &&
          dismissed is Map &&
          dismissed['perMachine'] is Map &&
          dismissed['global'] is Map) {
        return json;
      }
    }
  }

  final normalized = <String, dynamic>{...defaults, ...json};

  for (final entry in defaults.entries) {
    if (json[entry.key] == null) {
      normalized[entry.key] = entry.value;
    }
  }

  void normalizeListField(String key) {
    final value = normalized[key];
    if (value is List) return;
    normalized[key] = defaults[key];
  }

  normalizeListField('recentMachinePaths');
  normalizeListField('customModelModes');
  normalizeListField('profiles');
  normalizeListField('favoriteDirectories');
  normalizeListField('favoriteMachines');
  normalizeListField('folders');

  final lastUsedProfilesByAgent = normalized['lastUsedProfilesByAgent'];
  if (lastUsedProfilesByAgent is Map) {
    normalized['lastUsedProfilesByAgent'] = {
      for (final entry in lastUsedProfilesByAgent.entries)
        if (entry.value != null) entry.key.toString(): entry.value.toString(),
    };
  } else {
    normalized['lastUsedProfilesByAgent'] = defaults['lastUsedProfilesByAgent'];
  }

  final dismissed = normalized['dismissedCLIWarnings'];
  if (dismissed is! Map) {
    normalized['dismissedCLIWarnings'] = defaults['dismissedCLIWarnings'];
  } else {
    final dismissedMap = Map<String, dynamic>.from(dismissed);
    final dismissedDefaults =
        defaults['dismissedCLIWarnings'] as Map<String, dynamic>;
    final perMachine = dismissedMap['perMachine'];
    if (perMachine is! Map) {
      dismissedMap['perMachine'] = dismissedDefaults['perMachine'];
    }
    final global = dismissedMap['global'];
    if (global is! Map) {
      dismissedMap['global'] = dismissedDefaults['global'];
    }
    normalized['dismissedCLIWarnings'] = dismissedMap;
  }

  return normalized;
}

@JsonSerializable(explicitToJson: true)
class RecentMachinePath {
  RecentMachinePath({required this.machineId, required this.path});

  factory RecentMachinePath.fromJson(Map<String, dynamic> json) =>
      _$RecentMachinePathFromJson(json);

  final String machineId;
  final String path;

  Map<String, dynamic> toJson() => _$RecentMachinePathToJson(this);
}

@JsonSerializable(explicitToJson: true)
class DismissedCLIWarnings {
  DismissedCLIWarnings();

  factory DismissedCLIWarnings.fromJson(Map<String, dynamic> json) =>
      _$DismissedCLIWarningsFromJson(json);

  Map<String, PerMachineWarnings> perMachine = {};
  GlobalWarnings global = GlobalWarnings();

  Map<String, dynamic> toJson() => _$DismissedCLIWarningsToJson(this);
}

@JsonSerializable()
class PerMachineWarnings {
  PerMachineWarnings({this.claude, this.codex, this.gemini});

  factory PerMachineWarnings.fromJson(Map<String, dynamic> json) =>
      _$PerMachineWarningsFromJson(json);

  bool? claude;
  bool? codex;
  bool? gemini;

  Map<String, dynamic> toJson() => _$PerMachineWarningsToJson(this);
}

@JsonSerializable()
class GlobalWarnings {
  GlobalWarnings({this.claude, this.codex, this.gemini});

  factory GlobalWarnings.fromJson(Map<String, dynamic> json) =>
      _$GlobalWarningsFromJson(json);

  bool? claude;
  bool? codex;
  bool? gemini;

  Map<String, dynamic> toJson() => _$GlobalWarningsToJson(this);
}

/// Extended (1M-token) context window. Profiles set
/// [AIBackendProfile.contextWindow] to this to request the Claude Code
/// `[1m]` model suffix — the only wire-supported override today.
const int extendedContextWindowTokens = 1000000;

/// AI backend profile for environment configuration
@JsonSerializable(explicitToJson: true)
class AIBackendProfile {
  AIBackendProfile({
    required this.id,
    required this.name,
    this.description,
    this.anthropicConfig,
    this.openaiConfig,
    this.azureOpenAIConfig,
    this.togetherAIConfig,
    this.tmuxConfig,
    this.codexModelProvider,
    this.codexProviders = const [],
    this.startupBashScript,
    this.environmentVariables = const [],
    this.defaultSessionType,
    this.defaultPermissionMode,
    this.defaultModelMode,
    this.contextWindow,
    this.models = const [],
    this.compatibility = const ProfileCompatibility(
      claude: true,
      codex: true,
      gemini: true,
    ),
    this.isBuiltIn = false,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.version = '1.0.0',
  });

  factory AIBackendProfile.fromJson(Map<String, dynamic> json) =>
      _$AIBackendProfileFromJson(json);

  final String id;
  final String name;
  final String? description;
  final AnthropicConfig? anthropicConfig;
  final OpenAIConfig? openaiConfig;
  final AzureOpenAIConfig? azureOpenAIConfig;
  final TogetherAIConfig? togetherAIConfig;
  final TmuxConfig? tmuxConfig;

  /// Provider id selected through Codex's `model_provider` setting.
  final String? codexModelProvider;

  /// Custom Codex `model_providers.<id>` definitions for this profile.
  final List<CodexProviderConfig> codexProviders;
  final String? startupBashScript;
  final List<EnvironmentVariable> environmentVariables;
  final String? defaultSessionType;
  final String? defaultPermissionMode;
  final String? defaultModelMode;

  /// Context window in tokens the profile requests for its models, or null
  /// to use each model's default. The only wire-supported override today is
  /// [extendedContextWindowTokens] (1M), mapped to the Claude Code `[1m]`
  /// model suffix at send time.
  final int? contextWindow;
  final List<String> models;
  final ProfileCompatibility compatibility;
  final bool isBuiltIn;
  final int createdAt;
  final int updatedAt;
  final String version;

  Map<String, dynamic> toJson() => _$AIBackendProfileToJson(this);

  String? get inferredDefaultModelMode => inferDefaultModelMode(
    defaultModelMode: defaultModelMode,
    anthropicConfig: anthropicConfig,
    openaiConfig: openaiConfig,
    azureOpenAIConfig: azureOpenAIConfig,
    environmentVariables: environmentVariables,
    models: models,
  );

  static String? inferDefaultModelMode({
    String? defaultModelMode,
    AnthropicConfig? anthropicConfig,
    OpenAIConfig? openaiConfig,
    AzureOpenAIConfig? azureOpenAIConfig,
    List<EnvironmentVariable> environmentVariables = const [],
    List<String> models = const [],
  }) {
    return _nonDefaultModelMode(defaultModelMode) ??
        _nonDefaultModelMode(openaiConfig?.model) ??
        _nonDefaultModelMode(azureOpenAIConfig?.deploymentName) ??
        _nonDefaultModelMode(anthropicConfig?.model) ??
        _envModelMode(environmentVariables, 'OPENAI_MODEL') ??
        _envModelMode(environmentVariables, 'AZURE_OPENAI_DEPLOYMENT_NAME') ??
        _envModelMode(environmentVariables, 'ANTHROPIC_MODEL') ??
        _envModelMode(environmentVariables, 'ANTHROPIC_DEFAULT_OPUS_MODEL') ??
        models.map(_nonDefaultModelMode).whereType<String>().firstOrNull;
  }

  static String? _envModelMode(
    List<EnvironmentVariable> environmentVariables,
    String name,
  ) {
    for (final env in environmentVariables) {
      if (env.name != name) continue;
      return _nonDefaultModelMode(env.value);
    }
    return null;
  }

  static String? _nonDefaultModelMode(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'default') {
      return null;
    }
    return trimmed;
  }

  /// Serialize to JSON without API keys (for secure storage)
  Map<String, dynamic> toJsonWithoutApiKeys() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'anthropicConfig': anthropicConfig?.toJson(),
      'openaiConfig': openaiConfig?.toJsonWithoutApiKey(),
      'azureOpenAIConfig': azureOpenAIConfig?.toJsonWithoutApiKey(),
      'togetherAIConfig': togetherAIConfig?.toJsonWithoutApiKey(),
      'tmuxConfig': tmuxConfig?.toJson(),
      'codexModelProvider': codexModelProvider,
      'codexProviders': codexProviders.map((e) => e.toJson()).toList(),
      'startupBashScript': startupBashScript,
      'environmentVariables': environmentVariables
          .map((e) => e.toJson())
          .toList(),
      'defaultSessionType': defaultSessionType,
      'defaultPermissionMode': defaultPermissionMode,
      'defaultModelMode': defaultModelMode,
      'contextWindow': contextWindow,
      'models': models.map((e) => e).toList(),
      'compatibility': compatibility.toJson(),
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'version': version,
    };
  }

  AIBackendProfile copyWith({
    String? id,
    String? name,
    String? description,
    AnthropicConfig? anthropicConfig,
    OpenAIConfig? openaiConfig,
    AzureOpenAIConfig? azureOpenAIConfig,
    TogetherAIConfig? togetherAIConfig,
    TmuxConfig? tmuxConfig,
    String? codexModelProvider,
    List<CodexProviderConfig>? codexProviders,
    String? startupBashScript,
    List<EnvironmentVariable>? environmentVariables,
    String? defaultSessionType,
    String? defaultPermissionMode,
    String? defaultModelMode,
    int? contextWindow,
    List<String>? models,
    ProfileCompatibility? compatibility,
    bool? isBuiltIn,
    int? createdAt,
    int? updatedAt,
    String? version,
  }) {
    return AIBackendProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      anthropicConfig: anthropicConfig ?? this.anthropicConfig,
      openaiConfig: openaiConfig ?? this.openaiConfig,
      azureOpenAIConfig: azureOpenAIConfig ?? this.azureOpenAIConfig,
      togetherAIConfig: togetherAIConfig ?? this.togetherAIConfig,
      tmuxConfig: tmuxConfig ?? this.tmuxConfig,
      codexModelProvider: codexModelProvider ?? this.codexModelProvider,
      codexProviders: codexProviders != null
          ? List<CodexProviderConfig>.from(codexProviders)
          : List<CodexProviderConfig>.from(this.codexProviders),
      startupBashScript: startupBashScript ?? this.startupBashScript,
      environmentVariables: environmentVariables != null
          ? List<EnvironmentVariable>.from(environmentVariables)
          : List<EnvironmentVariable>.from(this.environmentVariables),
      defaultSessionType: defaultSessionType ?? this.defaultSessionType,
      defaultPermissionMode:
          defaultPermissionMode ?? this.defaultPermissionMode,
      defaultModelMode: defaultModelMode ?? this.defaultModelMode,
      contextWindow: contextWindow ?? this.contextWindow,
      models: models != null ? List<String>.from(models) : this.models,
      compatibility: compatibility ?? this.compatibility,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}

@JsonSerializable()
class AnthropicConfig {
  AnthropicConfig({this.baseUrl, this.authToken, this.model});

  factory AnthropicConfig.fromJson(Map<String, dynamic> json) =>
      _$AnthropicConfigFromJson(json);

  final String? baseUrl;
  final String? authToken;
  final String? model;

  Map<String, dynamic> toJson() => _$AnthropicConfigToJson(this);
}

@JsonSerializable()
class OpenAIConfig {
  OpenAIConfig({this.apiKey, this.baseUrl, this.model});

  factory OpenAIConfig.fromJson(Map<String, dynamic> json) =>
      _$OpenAIConfigFromJson(json);

  final String? apiKey;
  final String? baseUrl;
  final String? model;

  Map<String, dynamic> toJson() => _$OpenAIConfigToJson(this);

  /// Serialize to JSON without API key (for secure storage)
  Map<String, dynamic> toJsonWithoutApiKey() {
    return {'baseUrl': baseUrl, 'model': model};
  }
}

@JsonSerializable()
class AzureOpenAIConfig {
  AzureOpenAIConfig({
    this.apiKey,
    this.endpoint,
    this.apiVersion,
    this.deploymentName,
  });

  factory AzureOpenAIConfig.fromJson(Map<String, dynamic> json) =>
      _$AzureOpenAIConfigFromJson(json);

  final String? apiKey;
  final String? endpoint;
  final String? apiVersion;
  final String? deploymentName;

  Map<String, dynamic> toJson() => _$AzureOpenAIConfigToJson(this);

  /// Serialize to JSON without API key (for secure storage)
  Map<String, dynamic> toJsonWithoutApiKey() {
    return {
      'endpoint': endpoint,
      'apiVersion': apiVersion,
      'deploymentName': deploymentName,
    };
  }
}

@JsonSerializable()
class TogetherAIConfig {
  TogetherAIConfig({this.apiKey, this.model});

  factory TogetherAIConfig.fromJson(Map<String, dynamic> json) =>
      _$TogetherAIConfigFromJson(json);

  final String? apiKey;
  final String? model;

  Map<String, dynamic> toJson() => _$TogetherAIConfigToJson(this);

  /// Serialize to JSON without API key (for secure storage)
  Map<String, dynamic> toJsonWithoutApiKey() {
    return {'model': model};
  }
}

@JsonSerializable()
class TmuxConfig {
  TmuxConfig({this.sessionName, this.tmpDir, this.updateEnvironment});

  factory TmuxConfig.fromJson(Map<String, dynamic> json) =>
      _$TmuxConfigFromJson(json);

  final String? sessionName;
  final String? tmpDir;
  final bool? updateEnvironment;

  Map<String, dynamic> toJson() => _$TmuxConfigToJson(this);
}

/// A custom Codex `model_providers.<id>` definition.
///
/// API credentials are intentionally not part of this model. [envKey] names
/// the environment variable Codex should read, while the profile's ordinary
/// environment-variable list supplies that variable to the daemon.
@JsonSerializable()
class CodexProviderConfig {
  CodexProviderConfig({
    required this.id,
    required this.baseUrl,
    this.name,
    this.envKey = 'OPENAI_API_KEY',
    this.wireApi = 'responses',
  });

  factory CodexProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$CodexProviderConfigFromJson(json);

  final String id;
  final String? name;
  final String baseUrl;
  final String envKey;
  final String wireApi;

  Map<String, dynamic> toJson() => _$CodexProviderConfigToJson(this);
}

@JsonSerializable()
class EnvironmentVariable {
  EnvironmentVariable({required this.name, required this.value});

  factory EnvironmentVariable.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentVariableFromJson(json);

  final String name;
  final String value;

  Map<String, dynamic> toJson() => _$EnvironmentVariableToJson(this);
}

@JsonSerializable()
class ProfileCompatibility {
  const ProfileCompatibility({
    this.claude = true,
    this.codex = true,
    this.gemini = true,
    this.pi = true,
  });

  factory ProfileCompatibility.fromJson(Map<String, dynamic> json) =>
      _$ProfileCompatibilityFromJson(json);

  final bool claude;
  final bool codex;
  final bool gemini;
  final bool pi;

  Map<String, dynamic> toJson() => _$ProfileCompatibilityToJson(this);

  bool supportsAgent(String agent) {
    switch (agent) {
      case 'claude':
        return claude;
      case 'codex':
        return codex;
      case 'gemini':
        return gemini;
      case 'pi':
        return pi;
      // OpenCode and Grok Build use machine-local auth / default profiles;
      // treat them as always-supported unless a profile explicitly gates
      // other agents. Unknown agents stay permissive so new CLI flavors
      // remain usable before the app ships a matching profile flag.
      case 'opencode':
      case 'grok':
      case 'grok-build':
        return true;
      default:
        return true;
    }
  }
}
