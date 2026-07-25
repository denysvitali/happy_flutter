import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/routing/safe_pop.dart';
import 'profile_setup_catalog.dart';
import '../../core/utils/snack.dart';

/// Multi-step wizard for creating a new AI profile.
/// Step 1: Choose provider
/// Step 2: Enter API key and configure
/// Step 3: Review and save
class ProfileWizardScreen extends ConsumerStatefulWidget {
  const ProfileWizardScreen({super.key});

  @override
  ConsumerState<ProfileWizardScreen> createState() =>
      _ProfileWizardScreenState();
}

class _ProfileWizardScreenState extends ConsumerState<ProfileWizardScreen> {
  int _currentStep = 0;
  String? _selectedProvider;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _smallFastModelCtrl = TextEditingController();
  final _timeoutCtrl = TextEditingController();

  bool _obscureApiKey = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _smallFastModelCtrl.dispose();
    _timeoutCtrl.dispose();
    super.dispose();
  }

  void _selectProvider(String provider) {
    setState(() {
      _selectedProvider = provider;
      _applyProviderDefaults(provider);
    });
  }

  void _applyProviderDefaults(String provider) {
    final template = profileSetupTemplate(provider);
    if (template == null) {
      return;
    }

    _nameCtrl.text = template.name;
    _descCtrl.text = template.description ?? '';

    switch (provider) {
      case 'anthropic':
        _baseUrlCtrl.text = 'https://api.anthropic.com';
        _modelCtrl.text = 'claude-opus-4-5';
        _smallFastModelCtrl.text = 'claude-sonnet-4-5';
        _timeoutCtrl.text = '300000';
        break;
      case 'zai':
        _baseUrlCtrl.text = 'https://api.z.ai/api/anthropic';
        _modelCtrl.text = '';
        _smallFastModelCtrl.text = 'GLM-4.7';
        _timeoutCtrl.text = '3000000';
        break;
      case 'deepseek':
        _baseUrlCtrl.text = 'https://api.deepseek.com/anthropic';
        _modelCtrl.text = 'deepseek-chat';
        _smallFastModelCtrl.text = '';
        _timeoutCtrl.text = '600000';
        break;
      case 'minimax':
        _baseUrlCtrl.text = 'https://api.minimax.io/anthropic';
        _modelCtrl.text = 'MiniMax-M2.7';
        _smallFastModelCtrl.text = 'MiniMax-M2.7';
        _timeoutCtrl.text = '3000000';
        break;
      case 'xiaomi-mimo':
        _baseUrlCtrl.text = 'https://token-plan-sgp.xiaomimimo.com/anthropic';
        _modelCtrl.text = 'mimo-v2.5-pro';
        _smallFastModelCtrl.text = 'mimo-v2.5-pro';
        _timeoutCtrl.text = '3000000';
        break;
      case 'openrouter':
        _baseUrlCtrl.text = 'https://openrouter.ai/api';
        _modelCtrl.text = 'anthropic/claude-opus-4.6';
        _smallFastModelCtrl.text = 'anthropic/claude-sonnet-4.6';
        _timeoutCtrl.text = '';
        break;
      case 'openai':
        _baseUrlCtrl.text = 'https://api.openai.com/v1';
        _modelCtrl.text = '';
        _smallFastModelCtrl.text = '';
        _timeoutCtrl.text = '600000';
        break;
      case 'azure-openai':
        _baseUrlCtrl.text = '';
        _modelCtrl.text = '';
        _smallFastModelCtrl.text = '';
        _timeoutCtrl.text = '600000';
        break;
      case 'qwen-token-plan-codex':
        _baseUrlCtrl.text =
            'https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1';
        _modelCtrl.text = 'qwen3.7-max';
        _smallFastModelCtrl.text = 'qwen3.6-flash';
        _timeoutCtrl.text = '3000000';
        break;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final envVars = <EnvironmentVariable>[];

    // Determine which env vars to use based on provider type
    if (_selectedProvider == 'openai' ||
        _selectedProvider == 'qwen-token-plan-codex') {
      envVars
        ..add(
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value: _baseUrlCtrl.text,
          ),
        )
        ..add(
          EnvironmentVariable(name: 'OPENAI_API_KEY', value: _apiKeyCtrl.text),
        )
        ..add(
          EnvironmentVariable(name: 'OPENAI_MODEL', value: _modelCtrl.text),
        );
      if (_smallFastModelCtrl.text.isNotEmpty) {
        envVars.add(
          EnvironmentVariable(
            name: 'OPENAI_SMALL_FAST_MODEL',
            value: _smallFastModelCtrl.text,
          ),
        );
      }
      envVars.add(
        EnvironmentVariable(name: 'API_TIMEOUT_MS', value: _timeoutCtrl.text),
      );
    } else if (_selectedProvider == 'azure-openai') {
      envVars
        ..add(
          EnvironmentVariable(
            name: 'AZURE_OPENAI_API_VERSION',
            value: '2024-02-15-preview',
          ),
        )
        ..add(
          EnvironmentVariable(
            name: 'AZURE_OPENAI_DEPLOYMENT_NAME',
            value: _modelCtrl.text,
          ),
        )
        ..add(
          EnvironmentVariable(name: 'OPENAI_API_KEY', value: _apiKeyCtrl.text),
        )
        ..add(
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value: _baseUrlCtrl.text,
          ),
        )
        ..add(
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: _timeoutCtrl.text),
        );
    } else {
      // Anthropic-compatible providers
      envVars
        ..add(
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: _baseUrlCtrl.text,
          ),
        )
        ..add(
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: _apiKeyCtrl.text,
          ),
        );
      if (_timeoutCtrl.text.isNotEmpty) {
        envVars.add(
          EnvironmentVariable(name: 'API_TIMEOUT_MS', value: _timeoutCtrl.text),
        );
      }

      switch (_selectedProvider) {
        case 'zai':
          envVars
            ..add(
              EnvironmentVariable(
                name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
                value: '1',
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
                value: _modelCtrl.text.isNotEmpty ? _modelCtrl.text : 'glm-5.1',
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
                value: _smallFastModelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
                value: 'glm-4.5-air',
              ),
            );
          break;
        case 'deepseek':
          envVars
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_MODEL',
                value: _modelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
                value: 'deepseek-chat',
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
                value: '1',
              ),
            );
          break;
        case 'minimax':
          envVars
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_MODEL',
                value: _modelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_SMALL_FAST_MODEL',
                value: _smallFastModelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
                value: _smallFastModelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
                value: _modelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
                value: _smallFastModelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
                value: '1',
              ),
            );
          break;
        case 'xiaomi-mimo':
          envVars
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_MODEL',
                value: _modelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_SMALL_FAST_MODEL',
                value: _smallFastModelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
                value: _smallFastModelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
                value: _modelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
                value: _smallFastModelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
                value: '1',
              ),
            );
          break;
        case 'openrouter':
          envVars
            ..add(EnvironmentVariable(name: 'ANTHROPIC_API_KEY', value: ''))
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
                value: _modelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
                value: _smallFastModelCtrl.text,
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
                value: _smallFastModelCtrl.text.isNotEmpty
                    ? _smallFastModelCtrl.text
                    : 'anthropic/claude-haiku-4.5',
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'ANTHROPIC_DEFAULT_FABLE_MODEL',
                value: _smallFastModelCtrl.text.isNotEmpty
                    ? _smallFastModelCtrl.text
                    : 'anthropic/claude-fable-5',
              ),
            )
            ..add(
              EnvironmentVariable(
                name: 'CLAUDE_CODE_SUBAGENT_MODEL',
                value: _modelCtrl.text,
              ),
            );
          break;
        default:
          if (_modelCtrl.text.isNotEmpty) {
            envVars.add(
              EnvironmentVariable(
                name: 'ANTHROPIC_MODEL',
                value: _modelCtrl.text,
              ),
            );
          }
          if (_smallFastModelCtrl.text.isNotEmpty) {
            envVars.add(
              EnvironmentVariable(
                name: 'ANTHROPIC_SMALL_FAST_MODEL',
                value: _smallFastModelCtrl.text,
              ),
            );
          }
      }
    }

    final profile = AIBackendProfile(
      id: 'custom_$now',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      environmentVariables: envVars,
      defaultModelMode: AIBackendProfile.inferDefaultModelMode(
        environmentVariables: envVars,
      ),
      isBuiltIn: false,
      createdAt: now,
      updatedAt: now,
      compatibility: _getCompatibility(_selectedProvider!),
    );

    final settings = ref.read(settingsNotifierProvider);
    final updatedProfiles = [...settings.profiles, profile];

    final messenger = ScaffoldMessenger.of(context);
    final failedToSaveMsg = AppLocalizations.of(context).profilesFailedToSave;
    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('profiles', updatedProfiles);
      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting(
            'lastUsedProfilesByAgent',
            settings.lastUsedProfilesWithAgent(
              _primaryAgentForProfile(profile),
              profile.id,
            ),
          );
      if (mounted) safePop<void>(context, fallbackRouteName: 'profiles');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(failedToSaveMsg)));
    }
  }

  ProfileCompatibility _getCompatibility(String provider) {
    switch (provider) {
      case 'openai':
      case 'azure-openai':
      case 'qwen-token-plan-codex':
        return const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
        );
      default:
        return const ProfileCompatibility(
          claude: true,
          codex: false,
          gemini: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profilesWizardTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              safePop<void>(context, fallbackRouteName: 'profiles'),
        ),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && _selectedProvider == null) {
            context.showSnack(l10n.profilesWizardSelectProvider);
            return;
          }
          if (_currentStep < 2) {
            setState(() => _currentStep++);
          } else {
            _save();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          } else {
            safePop<void>(context, fallbackRouteName: 'profiles');
          }
        },
        onStepTapped: (step) {
          if (step <= _currentStep) {
            setState(() => _currentStep = step);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(
                    _currentStep == 2 ? l10n.commonSave : l10n.commonContinue,
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: Text(l10n.commonBack),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text(l10n.profilesWizardStep1),
            subtitle: Text(
              _selectedProvider != null
                  ? _getProviderName(_selectedProvider!)
                  : l10n.profilesWizardStep1Subtitle,
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildProviderSelection(tt, cs, l10n),
          ),
          Step(
            title: Text(l10n.profilesWizardStep2),
            subtitle: Text(l10n.profilesWizardStep2Subtitle),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildApiKeyStep(tt, cs, l10n),
          ),
          Step(
            title: Text(l10n.profilesWizardStep3),
            subtitle: Text(l10n.profilesWizardStep3Subtitle),
            isActive: _currentStep >= 2,
            state: StepState.indexed,
            content: _buildReviewStep(tt, cs, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelection(
    TextTheme tt,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profilesWizardSelectProvider,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: profileSetupOptions
                .map(
                  (option) => _ProviderCard(
                    id: option.id,
                    name: option.label,
                    description: option.shortDescription,
                    icon: option.icon,
                    color: colorForProfile(option.id),
                    isSelected: _selectedProvider == option.id,
                    onTap: () => _selectProvider(option.id),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyStep(TextTheme tt, ColorScheme cs, AppLocalizations l10n) {
    if (_selectedProvider == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: l10n.profilesProfileName,
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              v == null || v.trim().isEmpty ? l10n.profilesNameRequired : null,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _descCtrl,
          decoration: InputDecoration(
            labelText: l10n.profilesDescriptionLabel,
            border: const OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _apiKeyCtrl,
          obscureText: _obscureApiKey,
          decoration: InputDecoration(
            labelText: _getApiKeyLabel(_selectedProvider!),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureApiKey ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
            ),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'API key is required' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_selectedProvider != 'azure-openai')
          TextFormField(
            controller: _baseUrlCtrl,
            decoration: InputDecoration(
              labelText: l10n.profilesWizardBaseUrl,
              hintText: 'https://api.example.com',
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Base URL is required' : null,
          ),
        if (_selectedProvider == 'azure-openai') ...[
          TextFormField(
            controller: _baseUrlCtrl,
            decoration: InputDecoration(
              labelText: 'Azure Endpoint',
              hintText: 'https://your-resource.openai.azure.com',
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Endpoint is required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: 'Deployment Name',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Deployment name is required'
                : null,
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _modelCtrl,
            decoration: InputDecoration(
              labelText: l10n.profilesWizardModel,
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Model is required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _smallFastModelCtrl,
            decoration: InputDecoration(
              labelText: l10n.profilesWizardSmallFastModel,
              hintText: 'Optional - for quick tasks',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _timeoutCtrl,
          decoration: InputDecoration(
            labelText: l10n.profilesWizardTimeout,
            hintText: '300000',
            border: const OutlineInputBorder(),
            helperText: l10n.profilesWizardTimeoutHelp,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(TextTheme tt, ColorScheme cs, AppLocalizations l10n) {
    final selectedProvider = _selectedProvider;
    if (selectedProvider == null) {
      return Text(
        l10n.profilesWizardSelectProvider,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getProviderIcon(selectedProvider),
                      color: colorForProfile(selectedProvider),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nameCtrl.text, style: tt.titleMedium),
                          if (_descCtrl.text.isNotEmpty)
                            Text(
                              _descCtrl.text,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),
                _ReviewRow(
                  label: 'Provider',
                  value: _getProviderName(selectedProvider),
                ),
                _ReviewRow(
                  label: 'Base URL',
                  value: _baseUrlCtrl.text.isNotEmpty
                      ? _baseUrlCtrl.text
                      : 'Not configured',
                ),
                _ReviewRow(
                  label: 'Model',
                  value: _modelCtrl.text.isNotEmpty
                      ? _modelCtrl.text
                      : 'Not configured',
                ),
                _ReviewRow(
                  label: 'Timeout',
                  value: _timeoutCtrl.text.isNotEmpty
                      ? '${_timeoutCtrl.text}ms'
                      : 'Default',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.profilesWizardReviewHint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  String _getProviderName(String provider) {
    return profileSetupOption(provider)?.label ?? provider;
  }

  IconData _getProviderIcon(String provider) {
    return profileSetupOption(provider)?.icon ?? Icons.computer;
  }

  String _getApiKeyLabel(String provider) {
    return profileSetupOption(provider)?.apiKeyLabel ?? 'API Key';
  }
}

String _primaryAgentForProfile(AIBackendProfile profile) {
  final compatibility = profile.compatibility;
  if (compatibility.claude) return 'claude';
  if (compatibility.codex) return 'codex';
  if (compatibility.gemini) return 'gemini';
  return 'claude';
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? color.withValues(alpha: 30 / 255)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : cs.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 30 / 255),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : null,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: AppFontSize.xs,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: tt.bodySmall)),
        ],
      ),
    );
  }
}
