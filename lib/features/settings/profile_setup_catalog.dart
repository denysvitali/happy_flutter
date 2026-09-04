import 'package:flutter/material.dart';

import '../../core/models/built_in_profiles.dart';
import '../../core/models/settings.dart';

class ProfileSetupOption {
  const ProfileSetupOption({
    required this.id,
    required this.label,
    required this.shortDescription,
    required this.icon,
    required this.apiKeyLabel,
  });

  final String id;
  final String label;
  final String shortDescription;
  final IconData icon;
  final String apiKeyLabel;
}

List<ProfileSetupOption> get profileSetupOptions => builtInProfileIds
    .map(_profileSetupOptionForId)
    .whereType<ProfileSetupOption>()
    .toList(growable: false);

ProfileSetupOption? profileSetupOption(String id) =>
    _profileSetupOptionForId(id);

ProfileSetupOption? _profileSetupOptionForId(String id) {
  switch (id) {
    case 'anthropic':
      return const ProfileSetupOption(
        id: 'anthropic',
        label: 'Anthropic',
        shortDescription: 'Claude API',
        icon: Icons.auto_awesome,
        apiKeyLabel: 'Anthropic API Key',
      );
    case 'deepseek':
      return const ProfileSetupOption(
        id: 'deepseek',
        label: 'DeepSeek',
        shortDescription: 'deepseek-chat',
        icon: Icons.psychology,
        apiKeyLabel: 'DeepSeek API Key',
      );
    case 'zai':
      return const ProfileSetupOption(
        id: 'zai',
        label: 'Z.AI GLM',
        shortDescription: 'GLM Coding Plan',
        icon: Icons.bolt,
        apiKeyLabel: 'Z.AI API Key',
      );
    case 'minimax':
      return const ProfileSetupOption(
        id: 'minimax',
        label: 'MiniMax',
        shortDescription: 'MiniMax-M2.7',
        icon: Icons.memory,
        apiKeyLabel: 'MiniMax API Key',
      );
    case 'xiaomi-mimo':
      return const ProfileSetupOption(
        id: 'xiaomi-mimo',
        label: 'Xiaomi MiMo',
        shortDescription: 'MiMo-V2.5-Pro',
        icon: Icons.rocket_launch,
        apiKeyLabel: 'Xiaomi MiMo API Key',
      );
    case 'qwen':
      return const ProfileSetupOption(
        id: 'qwen',
        label: 'Qwen',
        shortDescription: 'qwen3.7-max',
        icon: Icons.generating_tokens,
        apiKeyLabel: 'Qwen API Key',
      );
    case 'openrouter':
      return const ProfileSetupOption(
        id: 'openrouter',
        label: 'OpenRouter',
        shortDescription: '200+ models',
        icon: Icons.hub,
        apiKeyLabel: 'OpenRouter API Key',
      );
    case 'openai':
      return const ProfileSetupOption(
        id: 'openai',
        label: 'OpenAI',
        shortDescription: 'GPT-5 Codex',
        icon: Icons.smart_toy,
        apiKeyLabel: 'OpenAI API Key',
      );
    case 'azure-openai':
      return const ProfileSetupOption(
        id: 'azure-openai',
        label: 'Azure OpenAI',
        shortDescription: 'Enterprise OpenAI',
        icon: Icons.cloud,
        apiKeyLabel: 'Azure API Key',
      );
    case 'qwen-token-plan-codex':
      return const ProfileSetupOption(
        id: 'qwen-token-plan-codex',
        label: 'Qwen (Codex)',
        shortDescription: 'qwen3.7-max · Codex',
        icon: Icons.generating_tokens,
        apiKeyLabel: 'Qwen API Key',
      );
    case 'custom-codex-proxy':
      return const ProfileSetupOption(
        id: 'custom-codex-proxy',
        label: 'Custom Codex Proxy',
        shortDescription: 'Any OpenAI-compatible gateway',
        icon: Icons.settings_ethernet,
        apiKeyLabel: 'Proxy API Key',
      );
    default:
      return null;
  }
}

AIBackendProfile? profileSetupTemplate(String id) {
  switch (id) {
    case 'anthropic':
      return AIBackendProfile(
        id: 'anthropic',
        name: 'Anthropic (Default)',
        description: 'Official Anthropic Claude API',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://api.anthropic.com',
          ),
          EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '300000'),
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: 'claude-opus-4-5',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          agy: false,
        ),
      );
    case 'deepseek':
      return AIBackendProfile(
        id: 'deepseek',
        name: 'DeepSeek (Chat)',
        description: 'DeepSeek API via Anthropic-compatible interface',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://api.deepseek.com/anthropic',
          ),
          EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '600000'),
          EnvironmentVariable(name: 'ANTHROPIC_MODEL', value: 'deepseek-chat'),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: 'deepseek-chat',
          ),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value: '1',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          agy: false,
        ),
      );
    case 'zai':
      return AIBackendProfile(
        id: 'zai',
        name: 'Z.AI (GLM-5.1)',
        description: 'Z.AI GLM Coding Plan via Anthropic-compatible interface',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://api.z.ai/api/anthropic',
          ),
          EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '3000000'),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value: '1',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: 'glm-5.1',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: 'glm-4.7',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: 'glm-4.5-air',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          agy: false,
        ),
      );
    case 'minimax':
      return AIBackendProfile(
        id: 'minimax',
        name: 'MiniMax (MiniMax-M2.7)',
        description: 'MiniMax-M2.7 via Anthropic-compatible interface',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://api.minimax.io/anthropic',
          ),
          EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
          EnvironmentVariable(name: 'ANTHROPIC_MODEL', value: 'MiniMax-M2.7'),
          EnvironmentVariable(
            name: 'ANTHROPIC_SMALL_FAST_MODEL',
            value: 'MiniMax-M2.7',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: 'MiniMax-M2.7',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: 'MiniMax-M2.7',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: 'MiniMax-M2.7',
          ),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '3000000'),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value: '1',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          agy: false,
        ),
      );
    case 'xiaomi-mimo':
      return AIBackendProfile(
        id: 'xiaomi-mimo',
        name: 'Xiaomi MiMo (Token Plan)',
        description:
            'Xiaomi MiMo Token Plan via Anthropic-compatible interface',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://token-plan-sgp.xiaomimimo.com/anthropic',
          ),
          EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
          EnvironmentVariable(name: 'ANTHROPIC_MODEL', value: 'mimo-v2.5-pro'),
          EnvironmentVariable(
            name: 'ANTHROPIC_SMALL_FAST_MODEL',
            value: 'mimo-v2.5-pro',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: 'mimo-v2.5-pro',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: 'mimo-v2.5-pro',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: 'mimo-v2.5-pro',
          ),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '3000000'),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value: '1',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          agy: false,
        ),
      );
    case 'qwen':
      return AIBackendProfile(
        id: 'qwen',
        name: 'Qwen (Token Plan)',
        description: 'Qwen Cloud Token Plan via Anthropic-compatible interface',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value:
                'https://token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic',
          ),
          EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
          EnvironmentVariable(name: 'ANTHROPIC_MODEL', value: 'qwen3.7-max'),
          EnvironmentVariable(
            name: 'ANTHROPIC_SMALL_FAST_MODEL',
            value: 'qwen3.7-max',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: 'qwen3.7-max',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: 'qwen3.7-max',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: 'qwen3.7-max',
          ),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '3000000'),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
            value: '1',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          agy: false,
        ),
      );
    case 'openrouter':
      return AIBackendProfile(
        id: 'openrouter',
        name: 'OpenRouter',
        description: 'OpenRouter — unified gateway to 200+ models',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://openrouter.ai/api',
          ),
          EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
          EnvironmentVariable(name: 'ANTHROPIC_API_KEY', value: ''),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
            value: 'anthropic/claude-opus-4.6',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            value: 'anthropic/claude-sonnet-4.6',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
            value: 'anthropic/claude-haiku-4.5',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_DEFAULT_FABLE_MODEL',
            value: 'anthropic/claude-fable-5',
          ),
          EnvironmentVariable(
            name: 'CLAUDE_CODE_SUBAGENT_MODEL',
            value: 'anthropic/claude-opus-4.6',
          ),
        ],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          agy: false,
        ),
      );
    case 'openai':
      return AIBackendProfile(
        id: 'openai',
        name: 'OpenAI (Codex)',
        description: 'OpenAI Codex API',
        environmentVariables: [
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value: 'https://api.openai.com/v1',
          ),
          EnvironmentVariable(name: 'OPENAI_API_KEY', value: ''),
          EnvironmentVariable(name: 'OPENAI_MODEL', value: ''),
          EnvironmentVariable(name: 'OPENAI_SMALL_FAST_MODEL', value: ''),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '600000'),
        ],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          agy: false,
        ),
      );
    case 'azure-openai':
      return AIBackendProfile(
        id: 'azure-openai',
        name: 'Azure OpenAI',
        description: 'Azure OpenAI Service for enterprise deployments',
        environmentVariables: [
          EnvironmentVariable(
            name: 'AZURE_OPENAI_API_VERSION',
            value: '2024-02-15-preview',
          ),
          EnvironmentVariable(name: 'AZURE_OPENAI_DEPLOYMENT_NAME', value: ''),
          EnvironmentVariable(name: 'OPENAI_API_KEY', value: ''),
          EnvironmentVariable(name: 'OPENAI_BASE_URL', value: ''),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '600000'),
        ],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          agy: false,
        ),
      );
    case 'qwen-token-plan-codex':
      return AIBackendProfile(
        id: 'qwen-token-plan-codex',
        name: 'Qwen (Token Plan, Codex)',
        description:
            'Qwen Cloud Token Plan via OpenAI-compatible interface (Codex)',
        environmentVariables: [
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value:
                'https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1',
          ),
          EnvironmentVariable(name: 'OPENAI_API_KEY', value: ''),
          EnvironmentVariable(name: 'OPENAI_MODEL', value: 'qwen3.7-max'),
          EnvironmentVariable(
            name: 'OPENAI_SMALL_FAST_MODEL',
            value: 'qwen3.7-max',
          ),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '3000000'),
        ],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          agy: false,
        ),
      );
    case 'custom-codex-proxy':
      return AIBackendProfile(
        id: 'custom-codex-proxy',
        name: 'Custom Codex Proxy',
        description:
            'Any OpenAI-compatible gateway for Codex (base URL required)',
        environmentVariables: [
          EnvironmentVariable(name: 'OPENAI_BASE_URL', value: ''),
          EnvironmentVariable(name: 'OPENAI_API_KEY', value: ''),
          EnvironmentVariable(name: 'OPENAI_MODEL', value: ''),
          // Optional Codex provider-definition overrides; see
          // built_in_profiles.dart. Empty values keep the daemon defaults
          // (env_key=OPENAI_API_KEY, wire_api=responses).
          EnvironmentVariable(
            name: 'HAPPY_CODEX_PROVIDER_ENV_KEY',
            value: 'OPENAI_API_KEY',
          ),
          EnvironmentVariable(
            name: 'HAPPY_CODEX_PROVIDER_WIRE_API',
            value: 'chat',
          ),
          EnvironmentVariable(name: 'HAPPY_CODEX_PROVIDER_NAME', value: ''),
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: '600000'),
        ],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          agy: false,
        ),
      );
    default:
      return getBuiltInProfile(id);
  }
}
