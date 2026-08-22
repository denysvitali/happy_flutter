import '../utils/shell_script_parser.dart' show buildAnthropicModelEnvVars;
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
  'xiaomi-mimo',
  'qwen',
  'openrouter',
  'openai',
  'azure-openai',
  'qwen-token-plan-codex',
  'custom-codex-proxy',
];

/// All built-in profile IDs in display order.
List<String> get builtInProfileIds => List<String>.unmodifiable(_builtInIds);

/// Stable Codex-compatible model slugs served by the Qwen Token Plan
/// gateway (OpenAI-compatible `responses` wire API). The daemon's
/// `get-codex-models` RPC only reports `gpt-*` for OpenAI, so these never
/// appear in the live catalog; this list keeps provider-owned selections
/// alive in model normalization (picker + spawn) for Codex profiles.
const qwenTokenPlanCodexModels = <String>[
  // Keep in sync with happy-cli-go codex_model_catalog.go
  // (codexTokenPlanCatalogModels). Missing slugs get normalized away
  // on ChatGPT/default Codex spawns and can stick as session.modelMode.
  'qwen3.8-max-preview',
  'qwen3.7-max',
  'qwen3.7-plus',
  'qwen3.6-flash',
  'glm-5.2',
  'deepseek-v4-pro',
];

final Set<String> _qwenTokenPlanCodexSlugSet = Set.unmodifiable(
  qwenTokenPlanCodexModels,
);

/// Whether [slug] is a known Codex-compatible model slug beyond the
/// daemon-reported `gpt-*` / `o*` families (Qwen Token Plan models).
bool isTokenPlanCodexModelSlug(String slug) =>
    _qwenTokenPlanCodexSlugSet.contains(slug);

/// All built-in profiles in display order.
List<AIBackendProfile> get builtInProfiles =>
    _builtInIds.map(getBuiltInProfile).whereType<AIBackendProfile>().toList();

/// Normalize stale built-in profile defaults persisted by older app versions.
AIBackendProfile normalizeBuiltInProfileDefaults(AIBackendProfile profile) {
  if (profile.id != 'minimax') return profile;
  final canonicalMiniMax = getBuiltInProfile('minimax')?.defaultModelMode;
  if (canonicalMiniMax == null) return profile;

  var changed = false;
  final updatedEnv = <EnvironmentVariable>[];
  for (final env in profile.environmentVariables) {
    if (env.value.contains('MiniMax-M3')) {
      changed = true;
      updatedEnv.add(
        EnvironmentVariable(
          name: env.name,
          value: env.value.replaceAll('MiniMax-M3', canonicalMiniMax),
        ),
      );
    } else {
      updatedEnv.add(env);
    }
  }

  final staleDefault = profile.defaultModelMode == 'MiniMax-M3';
  if (!changed && !staleDefault) return profile;

  return profile.copyWith(
    defaultModelMode: staleDefault
        ? canonicalMiniMax
        : profile.defaultModelMode,
    environmentVariables: updatedEnv,
  );
}

/// Model-selection env vars that alias- and subagent-based selection
/// consult. A profile missing any of these falls back to Claude's real
/// model names for those selections, which third-party providers reject.
const _modelSelectionEnvKeys = [
  'ANTHROPIC_MODEL',
  'ANTHROPIC_SMALL_FAST_MODEL',
  'ANTHROPIC_DEFAULT_OPUS_MODEL',
  'ANTHROPIC_DEFAULT_SONNET_MODEL',
  'ANTHROPIC_DEFAULT_HAIKU_MODEL',
  'CLAUDE_CODE_SUBAGENT_MODEL',
];

/// Backfill model-selection env vars on a saved Claude-compatible profile.
///
/// Profiles created before the wizard mapped every selection knob carry only
/// `ANTHROPIC_MODEL`, so picking `sonnet`/`opus`/`haiku` or spawning a
/// subagent resolved to Claude's real model names and got rejected by the
/// provider. When the profile has a selected model but is missing any of
/// [_modelSelectionEnvKeys], map the selected model onto every knob (the
/// fast/haiku-class knobs get the small-fast value when one exists).
/// Built-in profiles are left untouched — their defaults are curated.
AIBackendProfile normalizeModelSelectionEnv(AIBackendProfile profile) {
  if (!profile.compatibility.claude) return profile;
  if (profile.isBuiltIn) {
    // Built-ins are curated; only fill vars they never define.
    if (_modelSelectionEnvKeys.every(
      (key) => profile.environmentVariables.any((e) => e.name == key),
    )) {
      return profile;
    }
    // Fall through to backfill with their own selected model below.
  }
  final selected = AIBackendProfile.inferDefaultModelMode(
    defaultModelMode: profile.defaultModelMode,
    anthropicConfig: profile.anthropicConfig,
    openaiConfig: profile.openaiConfig,
    azureOpenAIConfig: profile.azureOpenAIConfig,
    environmentVariables: profile.environmentVariables,
  );
  if (selected == null) return profile;

  final existing = <String, String>{};
  var complete = true;
  for (final env in profile.environmentVariables) {
    if (_modelSelectionEnvKeys.contains(env.name)) {
      if (env.value.isEmpty && env.name != 'ANTHROPIC_MODEL') {
        complete = false;
      } else {
        existing[env.name] = env.value;
      }
    }
  }
  for (final key in _modelSelectionEnvKeys) {
    if (!existing.containsKey(key)) {
      complete = false;
      break;
    }
  }
  if (complete) return profile;

  String? fast;
  for (final name in const [
    'ANTHROPIC_SMALL_FAST_MODEL',
    'ANTHROPIC_DEFAULT_SONNET_MODEL',
    'ANTHROPIC_DEFAULT_HAIKU_MODEL',
  ]) {
    final v = existing[name];
    if (v != null && v.isNotEmpty && v != selected) {
      fast = v;
      break;
    }
  }

  final mapped = buildAnthropicModelEnvVars(
    mainModel: selected,
    fastModel: fast,
  );

  // Replace blank/incomplete entries, keep unrelated env vars as-is.
  final updated = <EnvironmentVariable>[];
  final seen = <String>{};
  for (final env in profile.environmentVariables) {
    final replacement = mapped.where((m) => m.name == env.name).toList();
    if (replacement.isNotEmpty) {
      if (!seen.add(env.name)) {
        continue; // drop duplicate stale entry
      }
      updated.add(replacement.first);
    } else {
      updated.add(env);
    }
  }
  for (final m in mapped) {
    if (updated.any((e) => e.name == m.name)) continue;
    updated.add(m);
  }

  return profile.copyWith(environmentVariables: updated);
}

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
          pi: true,
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
          pi: true,
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
          pi: true,
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
          pi: true,
        ),
      );

    case 'xiaomi-mimo':
      return AIBackendProfile(
        id: 'xiaomi-mimo',
        name: 'Xiaomi MiMo (Token Plan)',
        description:
            'Xiaomi MiMo Token Plan via Anthropic-compatible interface',
        isBuiltIn: true,
        defaultModelMode: 'mimo-v2.5-pro',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value:
                r'${XIAOMI_MIMO_BASE_URL:-https://token-plan-sgp.xiaomimimo.com/anthropic}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: r'${XIAOMI_MIMO_API_KEY:-}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: r'${XIAOMI_MIMO_MODEL:-mimo-v2.5-pro}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_SMALL_FAST_MODEL',
            value: r'${XIAOMI_MIMO_SMALL_FAST_MODEL:-mimo-v2.5-pro}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: r'${XIAOMI_MIMO_OPUS_MODEL:-mimo-v2.5-pro}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: r'${XIAOMI_MIMO_SONNET_MODEL:-mimo-v2.5-pro}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: r'${XIAOMI_MIMO_HAIKU_MODEL:-mimo-v2.5-pro}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${XIAOMI_MIMO_API_TIMEOUT_MS:-3000000}',
          ),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value:
                r'${XIAOMI_MIMO_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          gemini: false,
          pi: true,
        ),
      );

    case 'qwen':
      return AIBackendProfile(
        id: 'qwen',
        name: 'Qwen (Token Plan)',
        description: 'Qwen Cloud Token Plan via Anthropic-compatible interface',
        isBuiltIn: true,
        defaultModelMode: 'qwen3.7-max',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value:
                r'${QWEN_BASE_URL:-https://token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: r'${QWEN_API_KEY:-}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: r'${QWEN_MODEL:-qwen3.7-max}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_SMALL_FAST_MODEL',
            value: r'${QWEN_SMALL_FAST_MODEL:-qwen3.7-max}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: r'${QWEN_SONNET_MODEL:-qwen3.7-max}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: r'${QWEN_OPUS_MODEL:-qwen3.7-max}',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: r'${QWEN_HAIKU_MODEL:-qwen3.7-max}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${QWEN_API_TIMEOUT_MS:-3000000}',
          ),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value: r'${QWEN_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          gemini: false,
          pi: true,
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
          pi: true,
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
          pi: false,
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
          pi: false,
        ),
      );

    case 'qwen-token-plan-codex':
      return AIBackendProfile(
        id: 'qwen-token-plan-codex',
        name: 'Qwen (Token Plan, Codex)',
        description:
            'Qwen Cloud Token Plan via OpenAI-compatible interface (Codex)',
        isBuiltIn: true,
        defaultModelMode: 'qwen3.7-max',
        environmentVariables: [
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value:
                r'${QWEN_OPENAI_BASE_URL:-https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1}',
          ),
          EnvironmentVariable(
            name: 'OPENAI_API_KEY',
            value: r'${QWEN_API_KEY:-}',
          ),
          EnvironmentVariable(
            name: 'OPENAI_MODEL',
            value: r'${QWEN_MODEL:-qwen3.7-max}',
          ),
          EnvironmentVariable(
            name: 'OPENAI_SMALL_FAST_MODEL',
            value: r'${QWEN_SMALL_FAST_MODEL:-qwen3.7-max}',
          ),
          EnvironmentVariable(
            name: 'OPENAI_API_TIMEOUT_MS',
            value: r'${QWEN_API_TIMEOUT_MS:-3000000}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${QWEN_API_TIMEOUT_MS:-3000000}',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
          pi: false,
        ),
      );

    case 'custom-codex-proxy':
      return AIBackendProfile(
        id: 'custom-codex-proxy',
        name: 'Custom Codex Proxy',
        description:
            'Any OpenAI-compatible gateway for Codex (base URL required)',
        isBuiltIn: true,
        defaultModelMode: 'default',
        environmentVariables: [
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value: r'${CUSTOM_CODEX_BASE_URL:-}',
          ),
          EnvironmentVariable(
            name: 'OPENAI_API_KEY',
            value: r'${CUSTOM_CODEX_API_KEY:-}',
          ),
          EnvironmentVariable(
            name: 'OPENAI_MODEL',
            value: r'${CUSTOM_CODEX_MODEL:-}',
          ),
          // Optional Codex provider-definition overrides (daemon
          // codexProviderArgs): env_key names the variable carrying the API
          // key, wire_api selects chat (OpenAI-compatible) or responses
          // (Codex-native). Empty values keep the daemon defaults.
          EnvironmentVariable(
            name: 'HAPPY_CODEX_PROVIDER_ENV_KEY',
            value: r'${CUSTOM_CODEX_ENV_KEY:-OPENAI_API_KEY}',
          ),
          EnvironmentVariable(
            name: 'HAPPY_CODEX_PROVIDER_WIRE_API',
            value: r'${CUSTOM_CODEX_WIRE_API:-chat}',
          ),
          EnvironmentVariable(
            name: 'HAPPY_CODEX_PROVIDER_NAME',
            value: r'${CUSTOM_CODEX_PROVIDER_NAME:-}',
          ),
          EnvironmentVariable(
            name: 'API_TIMEOUT_MS',
            value: r'${CUSTOM_CODEX_API_TIMEOUT_MS:-600000}',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
          pi: false,
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
    if (agent == null && settings.lastUsedAgent == null) return scoped;

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
