// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Settings _$SettingsFromJson(Map<String, dynamic> json) => Settings()
  ..schemaVersion = (json['schemaVersion'] as num).toInt()
  ..themeMode = json['themeMode'] as String
  ..viewInline = json['viewInline'] as bool
  ..hideToolCalls = json['hideToolCalls'] as bool
  ..inferenceOpenAIKey = json['inferenceOpenAIKey'] as String?
  ..expandTodos = json['expandTodos'] as bool
  ..showLineNumbers = json['showLineNumbers'] as bool
  ..showLineNumbersInToolViews = json['showLineNumbersInToolViews'] as bool
  ..wrapLinesInDiffs = json['wrapLinesInDiffs'] as bool
  ..analyticsOptOut = json['analyticsOptOut'] as bool
  ..experiments = json['experiments'] as bool
  ..markdownCopyV2 = json['markdownCopyV2'] as bool
  ..useEnhancedSessionWizard = json['useEnhancedSessionWizard'] as bool
  ..alwaysShowContextSize = json['alwaysShowContextSize'] as bool
  ..agentInputEnterToSend = json['agentInputEnterToSend'] as bool
  ..developerModeEnabled = json['developerModeEnabled'] as bool
  ..toolCallDebugEnabled = json['toolCallDebugEnabled'] as bool
  ..avatarStyle = json['avatarStyle'] as String
  ..showFlavorIcons = json['showFlavorIcons'] as bool
  ..compactSessionView = json['compactSessionView'] as bool
  ..sessionsViewStyle = json['sessionsViewStyle'] as String
  ..hideInactiveSessions = json['hideInactiveSessions'] as bool
  ..reviewPromptAnswered = json['reviewPromptAnswered'] as bool
  ..reviewPromptLikedApp = json['reviewPromptLikedApp'] as bool?
  ..ttsEnabled = json['ttsEnabled'] as bool
  ..ttsUseOffline = json['ttsUseOffline'] as bool
  ..voiceAssistantLanguage = json['voiceAssistantLanguage'] as String?
  ..ttsEngine = json['ttsEngine'] as String?
  ..ttsVoiceId = json['ttsVoiceId'] as String?
  ..sttModelId = json['sttModelId'] as String?
  ..preferredLanguage = json['preferredLanguage'] as String?
  ..usagePeriod = json['usagePeriod'] as String
  ..recentMachinePaths = (json['recentMachinePaths'] as List<dynamic>)
      .map((e) => RecentMachinePath.fromJson(e as Map<String, dynamic>))
      .toList()
  ..lastUsedAgent = json['lastUsedAgent'] as String?
  ..lastUsedPermissionMode = json['lastUsedPermissionMode'] as String?
  ..lastUsedModelMode = json['lastUsedModelMode'] as String?
  ..customModelModes = (json['customModelModes'] as List<dynamic>)
      .map((e) => e as String)
      .toList()
  ..profiles = (json['profiles'] as List<dynamic>)
      .map((e) => AIBackendProfile.fromJson(e as Map<String, dynamic>))
      .toList()
  ..lastUsedProfile = json['lastUsedProfile'] as String?
  ..lastUsedProfilesByAgent = Map<String, String>.from(
    json['lastUsedProfilesByAgent'] as Map,
  )
  ..favoriteDirectories = (json['favoriteDirectories'] as List<dynamic>)
      .map((e) => e as String)
      .toList()
  ..favoriteMachines = (json['favoriteMachines'] as List<dynamic>)
      .map((e) => e as String)
      .toList()
  ..folders = (json['folders'] as List<dynamic>)
      .map((e) => e as String)
      .toList()
  ..dismissedCLIWarnings = DismissedCLIWarnings.fromJson(
    json['dismissedCLIWarnings'] as Map<String, dynamic>,
  );

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'themeMode': instance.themeMode,
  'viewInline': instance.viewInline,
  'hideToolCalls': instance.hideToolCalls,
  'expandTodos': instance.expandTodos,
  'showLineNumbers': instance.showLineNumbers,
  'showLineNumbersInToolViews': instance.showLineNumbersInToolViews,
  'wrapLinesInDiffs': instance.wrapLinesInDiffs,
  'analyticsOptOut': instance.analyticsOptOut,
  'experiments': instance.experiments,
  'markdownCopyV2': instance.markdownCopyV2,
  'useEnhancedSessionWizard': instance.useEnhancedSessionWizard,
  'alwaysShowContextSize': instance.alwaysShowContextSize,
  'agentInputEnterToSend': instance.agentInputEnterToSend,
  'developerModeEnabled': instance.developerModeEnabled,
  'toolCallDebugEnabled': instance.toolCallDebugEnabled,
  'avatarStyle': instance.avatarStyle,
  'showFlavorIcons': instance.showFlavorIcons,
  'compactSessionView': instance.compactSessionView,
  'sessionsViewStyle': instance.sessionsViewStyle,
  'hideInactiveSessions': instance.hideInactiveSessions,
  'reviewPromptAnswered': instance.reviewPromptAnswered,
  'reviewPromptLikedApp': instance.reviewPromptLikedApp,
  'ttsEnabled': instance.ttsEnabled,
  'ttsUseOffline': instance.ttsUseOffline,
  'voiceAssistantLanguage': instance.voiceAssistantLanguage,
  'ttsEngine': instance.ttsEngine,
  'ttsVoiceId': instance.ttsVoiceId,
  'sttModelId': instance.sttModelId,
  'preferredLanguage': instance.preferredLanguage,
  'usagePeriod': instance.usagePeriod,
  'recentMachinePaths': instance.recentMachinePaths
      .map((e) => e.toJson())
      .toList(),
  'lastUsedAgent': instance.lastUsedAgent,
  'lastUsedPermissionMode': instance.lastUsedPermissionMode,
  'lastUsedModelMode': instance.lastUsedModelMode,
  'customModelModes': instance.customModelModes,
  'profiles': instance.profiles.map((e) => e.toJson()).toList(),
  'lastUsedProfile': instance.lastUsedProfile,
  'lastUsedProfilesByAgent': instance.lastUsedProfilesByAgent,
  'favoriteDirectories': instance.favoriteDirectories,
  'favoriteMachines': instance.favoriteMachines,
  'folders': instance.folders,
  'dismissedCLIWarnings': instance.dismissedCLIWarnings.toJson(),
};

RecentMachinePath _$RecentMachinePathFromJson(Map<String, dynamic> json) =>
    RecentMachinePath(
      machineId: json['machineId'] as String,
      path: json['path'] as String,
    );

Map<String, dynamic> _$RecentMachinePathToJson(RecentMachinePath instance) =>
    <String, dynamic>{'machineId': instance.machineId, 'path': instance.path};

DismissedCLIWarnings _$DismissedCLIWarningsFromJson(
  Map<String, dynamic> json,
) => DismissedCLIWarnings()
  ..perMachine = (json['perMachine'] as Map<String, dynamic>).map(
    (k, e) =>
        MapEntry(k, PerMachineWarnings.fromJson(e as Map<String, dynamic>)),
  )
  ..global = GlobalWarnings.fromJson(json['global'] as Map<String, dynamic>);

Map<String, dynamic> _$DismissedCLIWarningsToJson(
  DismissedCLIWarnings instance,
) => <String, dynamic>{
  'perMachine': instance.perMachine.map((k, e) => MapEntry(k, e.toJson())),
  'global': instance.global.toJson(),
};

PerMachineWarnings _$PerMachineWarningsFromJson(Map<String, dynamic> json) =>
    PerMachineWarnings(
      claude: json['claude'] as bool?,
      codex: json['codex'] as bool?,
      gemini: json['gemini'] as bool?,
    );

Map<String, dynamic> _$PerMachineWarningsToJson(PerMachineWarnings instance) =>
    <String, dynamic>{
      'claude': instance.claude,
      'codex': instance.codex,
      'gemini': instance.gemini,
    };

GlobalWarnings _$GlobalWarningsFromJson(Map<String, dynamic> json) =>
    GlobalWarnings(
      claude: json['claude'] as bool?,
      codex: json['codex'] as bool?,
      gemini: json['gemini'] as bool?,
    );

Map<String, dynamic> _$GlobalWarningsToJson(GlobalWarnings instance) =>
    <String, dynamic>{
      'claude': instance.claude,
      'codex': instance.codex,
      'gemini': instance.gemini,
    };

AIBackendProfile _$AIBackendProfileFromJson(
  Map<String, dynamic> json,
) => AIBackendProfile(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  anthropicConfig: json['anthropicConfig'] == null
      ? null
      : AnthropicConfig.fromJson(
          json['anthropicConfig'] as Map<String, dynamic>,
        ),
  openaiConfig: json['openaiConfig'] == null
      ? null
      : OpenAIConfig.fromJson(json['openaiConfig'] as Map<String, dynamic>),
  azureOpenAIConfig: json['azureOpenAIConfig'] == null
      ? null
      : AzureOpenAIConfig.fromJson(
          json['azureOpenAIConfig'] as Map<String, dynamic>,
        ),
  togetherAIConfig: json['togetherAIConfig'] == null
      ? null
      : TogetherAIConfig.fromJson(
          json['togetherAIConfig'] as Map<String, dynamic>,
        ),
  tmuxConfig: json['tmuxConfig'] == null
      ? null
      : TmuxConfig.fromJson(json['tmuxConfig'] as Map<String, dynamic>),
  startupBashScript: json['startupBashScript'] as String?,
  environmentVariables:
      (json['environmentVariables'] as List<dynamic>?)
          ?.map((e) => EnvironmentVariable.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  defaultSessionType: json['defaultSessionType'] as String?,
  defaultPermissionMode: json['defaultPermissionMode'] as String?,
  defaultModelMode: json['defaultModelMode'] as String?,
  models:
      (json['models'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  compatibility: json['compatibility'] == null
      ? const ProfileCompatibility(claude: true, codex: true, gemini: true)
      : ProfileCompatibility.fromJson(
          json['compatibility'] as Map<String, dynamic>,
        ),
  isBuiltIn: json['isBuiltIn'] as bool? ?? false,
  createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
  version: json['version'] as String? ?? '1.0.0',
);

Map<String, dynamic> _$AIBackendProfileToJson(AIBackendProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'anthropicConfig': instance.anthropicConfig?.toJson(),
      'openaiConfig': instance.openaiConfig?.toJson(),
      'azureOpenAIConfig': instance.azureOpenAIConfig?.toJson(),
      'togetherAIConfig': instance.togetherAIConfig?.toJson(),
      'tmuxConfig': instance.tmuxConfig?.toJson(),
      'startupBashScript': instance.startupBashScript,
      'environmentVariables': instance.environmentVariables
          .map((e) => e.toJson())
          .toList(),
      'defaultSessionType': instance.defaultSessionType,
      'defaultPermissionMode': instance.defaultPermissionMode,
      'defaultModelMode': instance.defaultModelMode,
      'models': instance.models,
      'compatibility': instance.compatibility.toJson(),
      'isBuiltIn': instance.isBuiltIn,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'version': instance.version,
    };

AnthropicConfig _$AnthropicConfigFromJson(Map<String, dynamic> json) =>
    AnthropicConfig(
      baseUrl: json['baseUrl'] as String?,
      authToken: json['authToken'] as String?,
      model: json['model'] as String?,
    );

Map<String, dynamic> _$AnthropicConfigToJson(AnthropicConfig instance) =>
    <String, dynamic>{
      'baseUrl': instance.baseUrl,
      'authToken': instance.authToken,
      'model': instance.model,
    };

OpenAIConfig _$OpenAIConfigFromJson(Map<String, dynamic> json) => OpenAIConfig(
  apiKey: json['apiKey'] as String?,
  baseUrl: json['baseUrl'] as String?,
  model: json['model'] as String?,
);

Map<String, dynamic> _$OpenAIConfigToJson(OpenAIConfig instance) =>
    <String, dynamic>{
      'apiKey': instance.apiKey,
      'baseUrl': instance.baseUrl,
      'model': instance.model,
    };

AzureOpenAIConfig _$AzureOpenAIConfigFromJson(Map<String, dynamic> json) =>
    AzureOpenAIConfig(
      apiKey: json['apiKey'] as String?,
      endpoint: json['endpoint'] as String?,
      apiVersion: json['apiVersion'] as String?,
      deploymentName: json['deploymentName'] as String?,
    );

Map<String, dynamic> _$AzureOpenAIConfigToJson(AzureOpenAIConfig instance) =>
    <String, dynamic>{
      'apiKey': instance.apiKey,
      'endpoint': instance.endpoint,
      'apiVersion': instance.apiVersion,
      'deploymentName': instance.deploymentName,
    };

TogetherAIConfig _$TogetherAIConfigFromJson(Map<String, dynamic> json) =>
    TogetherAIConfig(
      apiKey: json['apiKey'] as String?,
      model: json['model'] as String?,
    );

Map<String, dynamic> _$TogetherAIConfigToJson(TogetherAIConfig instance) =>
    <String, dynamic>{'apiKey': instance.apiKey, 'model': instance.model};

TmuxConfig _$TmuxConfigFromJson(Map<String, dynamic> json) => TmuxConfig(
  sessionName: json['sessionName'] as String?,
  tmpDir: json['tmpDir'] as String?,
  updateEnvironment: json['updateEnvironment'] as bool?,
);

Map<String, dynamic> _$TmuxConfigToJson(TmuxConfig instance) =>
    <String, dynamic>{
      'sessionName': instance.sessionName,
      'tmpDir': instance.tmpDir,
      'updateEnvironment': instance.updateEnvironment,
    };

EnvironmentVariable _$EnvironmentVariableFromJson(Map<String, dynamic> json) =>
    EnvironmentVariable(
      name: json['name'] as String,
      value: json['value'] as String,
    );

Map<String, dynamic> _$EnvironmentVariableToJson(
  EnvironmentVariable instance,
) => <String, dynamic>{'name': instance.name, 'value': instance.value};

ProfileCompatibility _$ProfileCompatibilityFromJson(
  Map<String, dynamic> json,
) => ProfileCompatibility(
  claude: json['claude'] as bool? ?? true,
  codex: json['codex'] as bool? ?? true,
  gemini: json['gemini'] as bool? ?? true,
  pi: json['pi'] as bool? ?? true,
);

Map<String, dynamic> _$ProfileCompatibilityToJson(
  ProfileCompatibility instance,
) => <String, dynamic>{
  'claude': instance.claude,
  'codex': instance.codex,
  'gemini': instance.gemini,
  'pi': instance.pi,
};
