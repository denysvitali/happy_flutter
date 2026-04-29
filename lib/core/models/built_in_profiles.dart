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
  'openrouter',
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
        name: 'DeepSeek (Chat)',
        description: 'DeepSeek API via Anthropic-compatible interface',
        isBuiltIn: true,
        defaultModelMode: 'deepseek-chat',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: r'${DEEPSEEK_BASE_URL:-https://api.deepseek.com/anthropic}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: r'${DEEPSEEK_AUTH_TOKEN:-}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${DEEPSEEK_API_TIMEOUT_MS:-600000}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: r'${DEEPSEEK_MODEL:-deepseek-chat}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: r'${DEEPSEEK_HAIKU_MODEL:-deepseek-chat}',
          ),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value: r'${DEEPSEEK_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}',
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
        name: 'Z.AI (GLM-5.1)',
        description: 'Z.AI GLM Coding Plan via Anthropic-compatible interface',
        isBuiltIn: true,
        defaultModelMode: 'GLM-5.1',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: r'${Z_AI_BASE_URL:-https://api.z.ai/api/anthropic}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: r'${Z_AI_AUTH_TOKEN:-}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${Z_AI_API_TIMEOUT_MS:-3000000}',
          ),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value: r'${Z_AI_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: r'${Z_AI_OPUS_MODEL:-glm-5.1}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: r'${Z_AI_SONNET_MODEL:-glm-4.7}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: r'${Z_AI_HAIKU_MODEL:-glm-4.5-air}',
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
        name: 'MiniMax (MiniMax-M2.7)',
        description: 'MiniMax-M2.7 via Anthropic-compatible interface',
        isBuiltIn: true,
        defaultModelMode: 'MiniMax-M2.7',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: r'${MINIMAX_BASE_URL:-https://api.minimax.io/anthropic}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: r'${MINIMAX_API_KEY:-}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: r'${MINIMAX_MODEL:-MiniMax-M2.7}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_SMALL_FAST_MODEL',
            value: r'${MINIMAX_SMALL_FAST_MODEL:-MiniMax-M2.7}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: r'${MINIMAX_SONNET_MODEL:-MiniMax-M2.7}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: r'${MINIMAX_OPUS_MODEL:-MiniMax-M2.7}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: r'${MINIMAX_HAIKU_MODEL:-MiniMax-M2.7}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${MINIMAX_API_TIMEOUT_MS:-3000000}',
          ),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value: r'${MINIMAX_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          gemini: false,
        ),
      );

    case 'openrouter':
      return AIBackendProfile(
        id: 'openrouter',
        name: 'OpenRouter',
        description: 'OpenRouter — unified gateway to 200+ models',
        isBuiltIn: true,
        defaultModelMode: 'anthropic/claude-opus-4-6',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: r'${OPENROUTER_BASE_URL:-https://openrouter.ai/api}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: r'${OPENROUTER_API_KEY:-}',
          ),
          EnvironmentVariable(name: 'ANTHROPIC_API_KEY', value: ''),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: r'${OPENROUTER_OPUS_MODEL:-anthropic/claude-opus-4.6}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: r'${OPENROUTER_SONNET_MODEL:-anthropic/claude-sonnet-4.6}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: r'${OPENROUTER_HAIKU_MODEL:-anthropic/claude-haiku-4.5}',
          ),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_SUBAGENT_MODEL',
            value: r'${OPENROUTER_SUBAGENT_MODEL:-anthropic/claude-opus-4.6}',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          gemini: false,
        ),
      );

    case 'openai':
      return AIBackendProfile(
        id: 'openai',
        name: 'OpenAI (Codex)',
        description: 'OpenAI Codex API',
        isBuiltIn: true,
        defaultModelMode: 'default',
        environmentVariables: [
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value: 'https://api.openai.com/v1',
          ),
          EnvironmentVariable(name: 'OPENAI_MODEL', value: ''),
          EnvironmentVariable(name: 'OPENAI_API_TIMEOUT_MS', value: '600000'),
          EnvironmentVariable(name: 'OPENAI_SMALL_FAST_MODEL', value: ''),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '600000'),
          EnvironmentVariable(name: 'CODEX_SMALL_FAST_MODEL', value: ''),
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
        description: 'Azure OpenAI Service for enterprise deployments',
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
          EnvironmentVariable(name: 'OPENAI_API_TIMEOUT_MS', value: '600000'),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '600000'),
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

/// Resolve the selected profile ID for an agent.
///
/// Newer settings store selections in [Settings.lastUsedProfilesByAgent].
/// Older installs only have [Settings.lastUsedProfile], and some users may
/// still have that legacy field without a scoped entry. Use it only when the
/// referenced profile exists and supports the requested agent, so a Codex-only
/// profile cannot leak into Claude.
String? resolveSelectedProfileIdForAgent(Settings settings, String? agent) {
  final agentKey = normalizeAgentKey(agent);

  final scoped = settings.lastUsedProfileForAgent(agent);
  if (scoped != null) {
    final scopedProfile = resolveProfile(scoped, settings.profiles);
    if (scopedProfile == null) return null;
    if (!scopedProfile.compatibility.supportsAgent(agentKey)) return null;
    return scoped;
  }

  final legacy = settings.lastUsedProfile;
  if (legacy == null || legacy.isEmpty) return null;

  final profile = resolveProfile(legacy, settings.profiles);
  if (profile == null) return null;

  if (!profile.compatibility.supportsAgent(agentKey)) return null;

  return legacy;
}
