import 'settings.dart';

/// Built-in AI backend profiles matching the daemon's profile registry
/// (see ../happy/packages/happy-app/sources/sync/profileUtils.ts).
///
/// Environment variables use `${VAR:-default}` syntax — the daemon expands
/// these from its own process.env when spawning sessions.

const _builtInIds = [
  'anthropic',
  'deepseek',
  'zai',
  'minimax',
  'openai',
  'azure-openai',
];

/// All built-in profile IDs in display order.
List<String> get builtInProfileIds => List<String>.unmodifiable(_builtInIds);

/// All built-in profiles in display order.
List<AIBackendProfile> get builtInProfiles =>
    _builtInIds.map(getBuiltInProfile).whereType<AIBackendProfile>().toList();

/// Return the built-in [AIBackendProfile] for [id], or `null` if unknown.
AIBackendProfile? getBuiltInProfile(String id) {
  switch (id) {
    case 'anthropic':
      return AIBackendProfile(
        id: 'anthropic',
        name: 'Anthropic (Default)',
        description: 'Official Anthropic Claude API',
        isBuiltIn: true,
        defaultModelMode: 'default',
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          gemini: false,
        ),
      );

    case 'deepseek':
      return AIBackendProfile(
        id: 'deepseek',
        name: 'DeepSeek (Reasoner)',
        description:
            'DeepSeek API via Anthropic-compatible interface',
        isBuiltIn: true,
        defaultModelMode: 'deepseek-reasoner',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value:
                r'${DEEPSEEK_BASE_URL:-https://api.deepseek.com/anthropic}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: r'${DEEPSEEK_AUTH_TOKEN}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${DEEPSEEK_API_TIMEOUT_MS:-600000}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: r'${DEEPSEEK_MODEL:-deepseek-reasoner}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_SMALL_FAST_MODEL',
            value: r'${DEEPSEEK_SMALL_FAST_MODEL:-deepseek-chat}',
          ),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value:
                r'${DEEPSEEK_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          gemini: false,
        ),
      );

    case 'zai':
      return AIBackendProfile(
        id: 'zai',
        name: 'Z.AI (GLM)',
        description:
            'Z.AI GLM via Anthropic-compatible interface',
        isBuiltIn: true,
        defaultModelMode: 'GLM-5',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value:
                r'${Z_AI_BASE_URL:-https://api.z.ai/api/anthropic}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: r'${Z_AI_AUTH_TOKEN}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${Z_AI_API_TIMEOUT_MS:-300000}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: r'${Z_AI_MODEL:-GLM-5}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: r'${Z_AI_OPUS_MODEL:-GLM-5}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: r'${Z_AI_SONNET_MODEL:-GLM-5}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: r'${Z_AI_HAIKU_MODEL:-GLM-4.7}',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          gemini: false,
        ),
      );

    case 'minimax':
      return AIBackendProfile(
        id: 'minimax',
        name: 'MiniMax',
        description:
            'MiniMax via OpenAI-compatible interface',
        isBuiltIn: true,
        defaultModelMode: 'MiniMax-Text-01',
        environmentVariables: [
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value: r'${MINIMAX_BASE_URL:-https://api.minimax.io/v1}',
          ),
          EnvironmentVariable(
            name: 'OPENAI_API_KEY',
            value: r'${MINIMAX_API_KEY}',
          ),
          EnvironmentVariable(
            name: 'OPENAI_MODEL',
            value: r'${MINIMAX_MODEL:-MiniMax-Text-01}',
          ),
          EnvironmentVariable(
            name: 'OPENAI_SMALL_FAST_MODEL',
            value: r'${MINIMAX_SMALL_FAST_MODEL:-MiniMax-Text-01}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${MINIMAX_API_TIMEOUT_MS:-300000}',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
        ),
      );

    case 'openai':
      return AIBackendProfile(
        id: 'openai',
        name: 'OpenAI (GPT-5)',
        description: 'OpenAI GPT-5 Codex API',
        isBuiltIn: true,
        defaultModelMode: 'gpt-5-codex-high',
        environmentVariables: [
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value: 'https://api.openai.com/v1',
          ),
          EnvironmentVariable(
            name: 'OPENAI_MODEL',
            value: 'gpt-5-codex-high',
          ),
          EnvironmentVariable(
            name: 'OPENAI_API_TIMEOUT_MS',
            value: '600000',
          ),
          EnvironmentVariable(
            name: 'OPENAI_SMALL_FAST_MODEL',
            value: 'gpt-5-codex-low',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: '600000',
          ),
          EnvironmentVariable(
            name: 'CODEX_SMALL_FAST_MODEL',
            value: 'gpt-5-codex-low',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
        ),
      );

    case 'azure-openai':
      return AIBackendProfile(
        id: 'azure-openai',
        name: 'Azure OpenAI',
        description:
            'Azure OpenAI Service for enterprise deployments',
        isBuiltIn: true,
        defaultModelMode: 'gpt-5-codex',
        environmentVariables: [
          EnvironmentVariable(
            name: 'AZURE_OPENAI_API_VERSION',
            value: '2024-02-15-preview',
          ),
          EnvironmentVariable(
            name: 'AZURE_OPENAI_DEPLOYMENT_NAME',
            value: 'gpt-5-codex',
          ),
          EnvironmentVariable(
            name: 'OPENAI_API_TIMEOUT_MS',
            value: '600000',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: '600000',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
        ),
      );

    default:
      return null;
  }
}

/// Resolve a profile by ID: first check user custom profiles in
/// [customProfiles], then fall back to built-in profiles.
AIBackendProfile? resolveProfile(
  String id,
  List<AIBackendProfile> customProfiles,
) {
  for (final p in customProfiles) {
    if (p.id == id) return p;
  }
  return getBuiltInProfile(id);
}
