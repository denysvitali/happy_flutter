import '../models/settings.dart';

/// Parsed result from a shell script containing export statements.
class ShellScriptParseResult {
  const ShellScriptParseResult({
    required this.envVars,
    required this.rawScript,
  });

  final List<EnvironmentVariable> envVars;
  final String rawScript;
}

/// Parses a shell script and extracts environment variables from
/// `export KEY=value` or `KEY=value` lines.
ShellScriptParseResult parseShellScript(String content) {
  final envVars = <EnvironmentVariable>[];

  for (final line in content.split('\n')) {
    final trimmed = line.trim();

    // Skip empty lines and comments
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    // Match: export KEY=value or KEY=value
    final match = RegExp(r'^(?:export\s+)?(\w+)=(.*)$').firstMatch(trimmed);
    if (match == null) continue;

    final key = match.group(1)!;
    var value = match.group(2)!.trim();

    // Strip surrounding single or double quotes
    if ((value.startsWith("'") && value.endsWith("'")) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      value = value.substring(1, value.length - 1);
    }

    envVars.add(EnvironmentVariable(name: key, value: value));
  }

  return ShellScriptParseResult(envVars: envVars, rawScript: content);
}

/// Known env var names that map directly to profile config fields.
const _anthropicBaseUrlKey = 'ANTHROPIC_BASE_URL';
const _anthropicAuthTokenKey = 'ANTHROPIC_AUTH_TOKEN';
const _anthropicModelKey = 'ANTHROPIC_MODEL';
const _openaiApiKeyKey = 'OPENAI_API_KEY';
const _openaiBaseUrlKey = 'OPENAI_BASE_URL';
const _openaiModelKey = 'OPENAI_MODEL';

/// Keys that should be stored as env vars (not mapped to config fields).
const _envOnlyKeys = {
  'ANTHROPIC_DEFAULT_OPUS_MODEL',
  'ANTHROPIC_DEFAULT_SONNET_MODEL',
  'ANTHROPIC_DEFAULT_HAIKU_MODEL',
  'ANTHROPIC_DEFAULT_MODEL',
  'API_TIMEOUT_MS',
};

/// Builds an [AIBackendProfile] from a parsed shell script result.
///
/// Maps known env var keys to the appropriate profile config fields
/// (AnthropicConfig, OpenAIConfig) and stores the rest as
/// environment variables. Also preserves the raw script content.
AIBackendProfile buildProfileFromEnvVars(
  String name,
  ShellScriptParseResult result,
) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final envVars = <EnvironmentVariable>[];
  AnthropicConfig? anthropicConfig;
  OpenAIConfig? openaiConfig;

  String? anthropicBaseUrl;
  String? anthropicAuthToken;
  String? anthropicModel;
  String? openaiApiKey;
  String? openaiBaseUrl;
  String? openaiModel;

  for (final env in result.envVars) {
    switch (env.name) {
      case _anthropicBaseUrlKey:
        anthropicBaseUrl = env.value;
      case _anthropicAuthTokenKey:
        anthropicAuthToken = env.value;
      case _anthropicModelKey:
        anthropicModel = env.value;
      case _openaiApiKeyKey:
        openaiApiKey = env.value;
      case _openaiBaseUrlKey:
        openaiBaseUrl = env.value;
      case _openaiModelKey:
        openaiModel = env.value;
      default:
        if (_envOnlyKeys.contains(env.name) ||
            !env.name.startsWith('ANTHROPIC_') &&
                !env.name.startsWith('OPENAI_')) {
          envVars.add(env);
        }
    }
  }

  if (anthropicBaseUrl != null ||
      anthropicAuthToken != null ||
      anthropicModel != null) {
    anthropicConfig = AnthropicConfig(
      baseUrl: anthropicBaseUrl,
      authToken: anthropicAuthToken,
      model: anthropicModel,
    );
  }

  if (openaiApiKey != null || openaiBaseUrl != null || openaiModel != null) {
    openaiConfig = OpenAIConfig(
      apiKey: openaiApiKey,
      baseUrl: openaiBaseUrl,
      model: openaiModel,
    );
  }

  return AIBackendProfile(
    id: 'custom_$now',
    name: name,
    anthropicConfig: anthropicConfig,
    openaiConfig: openaiConfig,
    environmentVariables: envVars,
    startupBashScript: result.rawScript,
    defaultModelMode: AIBackendProfile.inferDefaultModelMode(
      anthropicConfig: anthropicConfig,
      openaiConfig: openaiConfig,
      environmentVariables: envVars,
    ),
    isBuiltIn: false,
    createdAt: now,
    updatedAt: now,
  );
}
