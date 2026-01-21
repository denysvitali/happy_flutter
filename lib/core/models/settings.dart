/// Settings model matching the original Zod schema
class Settings {
  int schemaVersion = 2;
  bool viewInline = false;
  String? inferenceOpenAIKey;
  bool expandTodos = true;
  bool showLineNumbers = true;
  bool showLineNumbersInToolViews = false;
  bool wrapLinesInDiffs = false;
  bool analyticsOptOut = false;
  bool experiments = false;
  bool useEnhancedSessionWizard = false;
  bool alwaysShowContextSize = false;
  bool agentInputEnterToSend = true;
  String avatarStyle = 'brutalist';
  bool showFlavorIcons = false;
  bool compactSessionView = false;
  bool hideInactiveSessions = false;
  bool reviewPromptAnswered = false;
  bool? reviewPromptLikedApp;
  String? voiceAssistantLanguage;
  String? preferredLanguage;
  List<RecentMachinePath> recentMachinePaths = [];
  String? lastUsedAgent;
  String? lastUsedPermissionMode;
  String? lastUsedModelMode;
  List<AIBackendProfile> profiles = [];
  String? lastUsedProfile;
  List<String> favoriteDirectories = ['~/src', '~/Desktop', '~/Documents'];
  List<String> favoriteMachines = [];
  DismissedCLIWarnings dismissedCLIWarnings = DismissedCLIWarnings();

  Settings();

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings()
      ..schemaVersion = json['schemaVersion'] as int? ?? 2
      ..viewInline = json['viewInline'] as bool? ?? false
      ..inferenceOpenAIKey = json['inferenceOpenAIKey'] as String?
      ..expandTodos = json['expandTodos'] as bool? ?? true
      ..showLineNumbers = json['showLineNumbers'] as bool? ?? true
      ..showLineNumbersInToolViews = json['showLineNumbersInToolViews'] as bool? ?? false
      ..wrapLinesInDiffs = json['wrapLinesInDiffs'] as bool? ?? false
      ..analyticsOptOut = json['analyticsOptOut'] as bool? ?? false
      ..experiments = json['experiments'] as bool? ?? false
      ..useEnhancedSessionWizard = json['useEnhancedSessionWizard'] as bool? ?? false
      ..alwaysShowContextSize = json['alwaysShowContextSize'] as bool? ?? false
      ..agentInputEnterToSend = json['agentInputEnterToSend'] as bool? ?? true
      ..avatarStyle = json['avatarStyle'] as String? ?? 'brutalist'
      ..showFlavorIcons = json['showFlavorIcons'] as bool? ?? false
      ..compactSessionView = json['compactSessionView'] as bool? ?? false
      ..hideInactiveSessions = json['hideInactiveSessions'] as bool? ?? false
      ..reviewPromptAnswered = json['reviewPromptAnswered'] as bool? ?? false
      ..reviewPromptLikedApp = json['reviewPromptLikedApp'] as bool?
      ..voiceAssistantLanguage = json['voiceAssistantLanguage'] as String?
      ..preferredLanguage = json['preferredLanguage'] as String?
      ..recentMachinePaths = (json['recentMachinePaths'] as List<dynamic>?)
          ?.map((e) => RecentMachinePath.fromJson(e as Map<String, dynamic>))
          .toList() ?? []
      ..lastUsedAgent = json['lastUsedAgent'] as String?
      ..lastUsedPermissionMode = json['lastUsedPermissionMode'] as String?
      ..lastUsedModelMode = json['lastUsedModelMode'] as String?
      ..profiles = (json['profiles'] as List<dynamic>?)
          ?.map((e) => AIBackendProfile.fromJson(e as Map<String, dynamic>))
          .toList() ?? []
      ..lastUsedProfile = json['lastUsedProfile'] as String?
      ..favoriteDirectories = (json['favoriteDirectories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? ['~/src', '~/Desktop', '~/Documents']
      ..favoriteMachines = (json['favoriteMachines'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? []
      ..dismissedCLIWarnings = json['dismissedCLIWarnings'] != null
          ? DismissedCLIWarnings.fromJson(json['dismissedCLIWarnings'] as Map<String, dynamic>)
          : DismissedCLIWarnings();
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'viewInline': viewInline,
      'inferenceOpenAIKey': inferenceOpenAIKey,
      'expandTodos': expandTodos,
      'showLineNumbers': showLineNumbers,
      'showLineNumbersInToolViews': showLineNumbersInToolViews,
      'wrapLinesInDiffs': wrapLinesInDiffs,
      'analyticsOptOut': analyticsOptOut,
      'experiments': experiments,
      'useEnhancedSessionWizard': useEnhancedSessionWizard,
      'alwaysShowContextSize': alwaysShowContextSize,
      'agentInputEnterToSend': agentInputEnterToSend,
      'avatarStyle': avatarStyle,
      'showFlavorIcons': showFlavorIcons,
      'compactSessionView': compactSessionView,
      'hideInactiveSessions': hideInactiveSessions,
      'reviewPromptAnswered': reviewPromptAnswered,
      'reviewPromptLikedApp': reviewPromptLikedApp,
      'voiceAssistantLanguage': voiceAssistantLanguage,
      'preferredLanguage': preferredLanguage,
      'recentMachinePaths': recentMachinePaths.map((e) => e.toJson()).toList(),
      'lastUsedAgent': lastUsedAgent,
      'lastUsedPermissionMode': lastUsedPermissionMode,
      'lastUsedModelMode': lastUsedModelMode,
      'profiles': profiles.map((e) => e.toJson()).toList(),
      'lastUsedProfile': lastUsedProfile,
      'favoriteDirectories': favoriteDirectories,
      'favoriteMachines': favoriteMachines,
      'dismissedCLIWarnings': dismissedCLIWarnings.toJson(),
    };
  }
}

class RecentMachinePath {
  final String machineId;
  final String path;

  RecentMachinePath({required this.machineId, required this.path});

  factory RecentMachinePath.fromJson(Map<String, dynamic> json) {
    return RecentMachinePath(
      machineId: json['machineId'] as String,
      path: json['path'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'machineId': machineId, 'path': path};
  }
}

class DismissedCLIWarnings {
  Map<String, PerMachineWarnings> perMachine = {};
  GlobalWarnings global = GlobalWarnings();

  DismissedCLIWarnings();

  factory DismissedCLIWarnings.fromJson(Map<String, dynamic> json) {
    return DismissedCLIWarnings()
      ..perMachine = (json['perMachine'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, PerMachineWarnings.fromJson(v as Map<String, dynamic>)),
          ) ??
          {}
      ..global = json['global'] != null
          ? GlobalWarnings.fromJson(json['global'] as Map<String, dynamic>)
          : GlobalWarnings();
  }

  Map<String, dynamic> toJson() {
    return {
      'perMachine': perMachine.map((k, v) => MapEntry(k, v.toJson())),
      'global': global.toJson(),
    };
  }
}

class PerMachineWarnings {
  bool? claude;
  bool? codex;
  bool? gemini;

  PerMachineWarnings({this.claude, this.codex, this.gemini});

  factory PerMachineWarnings.fromJson(Map<String, dynamic> json) {
    return PerMachineWarnings(
      claude: json['claude'] as bool?,
      codex: json['codex'] as bool?,
      gemini: json['gemini'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'claude': claude, 'codex': codex, 'gemini': gemini};
  }
}

class GlobalWarnings {
  bool? claude;
  bool? codex;
  bool? gemini;

  GlobalWarnings({this.claude, this.codex, this.gemini});

  factory GlobalWarnings.fromJson(Map<String, dynamic> json) {
    return GlobalWarnings(
      claude: json['claude'] as bool?,
      codex: json['codex'] as bool?,
      gemini: json['gemini'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'claude': claude, 'codex': codex, 'gemini': gemini};
  }
}

/// AI backend profile for environment configuration
class AIBackendProfile {
  final String id;
  final String name;
  final String? description;
  final AnthropicConfig? anthropicConfig;
  final OpenAIConfig? openaiConfig;
  final AzureOpenAIConfig? azureOpenAIConfig;
  final TogetherAIConfig? togetherAIConfig;
  final TmuxConfig? tmuxConfig;
  final String? startupBashScript;
  List<EnvironmentVariable> environmentVariables = [];
  final String? defaultSessionType;
  final String? defaultPermissionMode;
  final String? defaultModelMode;
  ProfileCompatibility compatibility = ProfileCompatibility();
  bool isBuiltIn = false;
  int createdAt = 0;
  int updatedAt = 0;
  String version = '1.0.0';

  AIBackendProfile({
    required this.id,
    required this.name,
    this.description,
    this.anthropicConfig,
    this.openaiConfig,
    this.azureOpenAIConfig,
    this.togetherAIConfig,
    this.tmuxConfig,
    this.startupBashScript,
    this.environmentVariables = const [],
    this.defaultSessionType,
    this.defaultPermissionMode,
    this.defaultModelMode,
    this.compatibility = const ProfileCompatibility(claude: true, codex: true, gemini: true),
    this.isBuiltIn = false,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.version = '1.0.0',
  });

  factory AIBackendProfile.fromJson(Map<String, dynamic> json) {
    return AIBackendProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      anthropicConfig: json['anthropicConfig'] != null
          ? AnthropicConfig.fromJson(json['anthropicConfig'] as Map<String, dynamic>)
          : null,
      openaiConfig: json['openaiConfig'] != null
          ? OpenAIConfig.fromJson(json['openaiConfig'] as Map<String, dynamic>)
          : null,
      azureOpenAIConfig: json['azureOpenAIConfig'] != null
          ? AzureOpenAIConfig.fromJson(json['azureOpenAIConfig'] as Map<String, dynamic>)
          : null,
      togetherAIConfig: json['togetherAIConfig'] != null
          ? TogetherAIConfig.fromJson(json['togetherAIConfig'] as Map<String, dynamic>)
          : null,
      tmuxConfig: json['tmuxConfig'] != null
          ? TmuxConfig.fromJson(json['tmuxConfig'] as Map<String, dynamic>)
          : null,
      startupBashScript: json['startupBashScript'] as String?,
      environmentVariables: (json['environmentVariables'] as List<dynamic>?)
              ?.map((e) => EnvironmentVariable.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      defaultSessionType: json['defaultSessionType'] as String?,
      defaultPermissionMode: json['defaultPermissionMode'] as String?,
      defaultModelMode: json['defaultModelMode'] as String?,
      compatibility: json['compatibility'] != null
          ? ProfileCompatibility.fromJson(json['compatibility'] as Map<String, dynamic>)
          : ProfileCompatibility(),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      createdAt: json['createdAt'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? 0,
      version: json['version'] as String? ?? '1.0.0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'anthropicConfig': anthropicConfig?.toJson(),
      'openaiConfig': openaiConfig?.toJson(),
      'azureOpenAIConfig': azureOpenAIConfig?.toJson(),
      'togetherAIConfig': togetherAIConfig?.toJson(),
      'tmuxConfig': tmuxConfig?.toJson(),
      'startupBashScript': startupBashScript,
      'environmentVariables': environmentVariables.map((e) => e.toJson()).toList(),
      'defaultSessionType': defaultSessionType,
      'defaultPermissionMode': defaultPermissionMode,
      'defaultModelMode': defaultModelMode,
      'compatibility': compatibility.toJson(),
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'version': version,
    };
  }
}

class AnthropicConfig {
  final String? baseUrl;
  final String? authToken;
  final String? model;

  AnthropicConfig({this.baseUrl, this.authToken, this.model});

  factory AnthropicConfig.fromJson(Map<String, dynamic> json) {
    return AnthropicConfig(
      baseUrl: json['baseUrl'] as String?,
      authToken: json['authToken'] as String?,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'baseUrl': baseUrl, 'authToken': authToken, 'model': model};
  }
}

class OpenAIConfig {
  final String? apiKey;
  final String? baseUrl;
  final String? model;

  OpenAIConfig({this.apiKey, this.baseUrl, this.model});

  factory OpenAIConfig.fromJson(Map<String, dynamic> json) {
    return OpenAIConfig(
      apiKey: json['apiKey'] as String?,
      baseUrl: json['baseUrl'] as String?,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'apiKey': apiKey, 'baseUrl': baseUrl, 'model': model};
  }
}

class AzureOpenAIConfig {
  final String? apiKey;
  final String? endpoint;
  final String? apiVersion;
  final String? deploymentName;

  AzureOpenAIConfig({this.apiKey, this.endpoint, this.apiVersion, this.deploymentName});

  factory AzureOpenAIConfig.fromJson(Map<String, dynamic> json) {
    return AzureOpenAIConfig(
      apiKey: json['apiKey'] as String?,
      endpoint: json['endpoint'] as String?,
      apiVersion: json['apiVersion'] as String?,
      deploymentName: json['deploymentName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'endpoint': endpoint,
      'apiVersion': apiVersion,
      'deploymentName': deploymentName,
    };
  }
}

class TogetherAIConfig {
  final String? apiKey;
  final String? model;

  TogetherAIConfig({this.apiKey, this.model});

  factory TogetherAIConfig.fromJson(Map<String, dynamic> json) {
    return TogetherAIConfig(
      apiKey: json['apiKey'] as String?,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'apiKey': apiKey, 'model': model};
  }
}

class TmuxConfig {
  final String? sessionName;
  final String? tmpDir;
  final bool? updateEnvironment;

  TmuxConfig({this.sessionName, this.tmpDir, this.updateEnvironment});

  factory TmuxConfig.fromJson(Map<String, dynamic> json) {
    return TmuxConfig(
      sessionName: json['sessionName'] as String?,
      tmpDir: json['tmpDir'] as String?,
      updateEnvironment: json['updateEnvironment'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionName': sessionName,
      'tmpDir': tmpDir,
      'updateEnvironment': updateEnvironment,
    };
  }
}

class EnvironmentVariable {
  final String name;
  final String value;

  EnvironmentVariable({required this.name, required this.value});

  factory EnvironmentVariable.fromJson(Map<String, dynamic> json) {
    return EnvironmentVariable(
      name: json['name'] as String,
      value: json['value'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'value': value};
  }
}

class ProfileCompatibility {
  final bool claude;
  final bool codex;
  final bool gemini;

  const ProfileCompatibility({this.claude = true, this.codex = true, this.gemini = true});

  factory ProfileCompatibility.fromJson(Map<String, dynamic> json) {
    return ProfileCompatibility(
      claude: json['claude'] as bool? ?? true,
      codex: json['codex'] as bool? ?? true,
      gemini: json['gemini'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'claude': claude, 'codex': codex, 'gemini': gemini};
  }
}
