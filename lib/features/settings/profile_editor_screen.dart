import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/shell_script_parser.dart';

/// Full-screen editor for creating or editing a custom AI backend profile.
class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key, this.existing});

  /// Existing profile to edit; null means create new.
  final AIBackendProfile? existing;

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _scriptCtrl;
  late final List<_EnvRow> _envRows;

  bool _showScript = false;
  String? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _scriptCtrl =
        TextEditingController(text: p?.startupBashScript ?? '');
    _envRows = (p?.environmentVariables ?? [])
        .map((e) => _EnvRow(name: e.name, value: e.value))
        .toList();
    _showScript =
        p?.startupBashScript != null && p!.startupBashScript!.isNotEmpty;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _scriptCtrl.dispose();
    for (final r in _envRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addEnvRow() {
    setState(() => _envRows.add(_EnvRow()));
  }

  void _removeEnvRow(int index) {
    setState(() {
      _envRows[index].dispose();
      _envRows.removeAt(index);
    });
  }

  Future<void> _showImportDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profilesImportTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profilesImportHint,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: l10n.profilesImportLabel,
                  hintText: 'export ANTHROPIC_BASE_URL=...\nexport '
                      'ANTHROPIC_AUTH_TOKEN=...',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.md,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profilesImportButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }

    final text = controller.text;
    controller.dispose();

    if (text.trim().isEmpty) return;

    final result = parseShellScript(text);
    if (result.envVars.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilesImportNoVars)),
        );
      }
      return;
    }

    // Auto-fill name if empty
    if (_nameCtrl.text.trim().isEmpty) {
      final modelVar = result.envVars.firstWhere(
        (e) =>
            e.name == 'ANTHROPIC_MODEL' ||
            e.name == 'ANTHROPIC_DEFAULT_OPUS_MODEL' ||
            e.name == 'OPENAI_MODEL',
        orElse: () => result.envVars.first,
      );
      final modelValue = modelVar.value;
      if (modelValue.isNotEmpty) {
        final parts = modelValue.split('/');
        _nameCtrl.text = parts.length > 1 ? parts.last : modelValue;
      }
    }

    setState(() {
      for (final r in _envRows) {
        r.dispose();
      }
      _envRows.clear();
      for (final env in result.envVars) {
        _envRows.add(_EnvRow(name: env.name, value: env.value));
      }
      _scriptCtrl.text = result.rawScript;
      _showScript = true;
    });
  }

  /// Reset a built-in profile to its factory defaults by removing
  /// the user's customisation from [Settings.profiles].
  Future<void> _resetToDefaults() async {
    final existing = widget.existing;
    if (existing == null) return;

    final builtIn = getBuiltInProfile(existing.id);
    if (builtIn == null) return;

    // Remove the user's stored override so resolveProfile falls
    // back to the immutable built-in definition.
    final settings = ref.read(settingsNotifierProvider);
    final updatedProfiles =
        settings.profiles.where((p) => p.id != existing.id).toList();

    final failedMsg = context.l10n.profilesFailedToSave;
    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('profiles', updatedProfiles);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failedMsg)),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final envVars = _envRows
        .where((r) => r.nameCtrl.text.trim().isNotEmpty)
        .map(
          (r) => EnvironmentVariable(
            name: r.nameCtrl.text.trim(),
            value: r.valueCtrl.text,
          ),
        )
        .toList();

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = widget.existing;
    final updated = AIBackendProfile(
      id: existing?.id ?? 'custom_$now',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      startupBashScript: _showScript && _scriptCtrl.text.trim().isNotEmpty
          ? _scriptCtrl.text.trim()
          : null,
      environmentVariables: envVars,
      isBuiltIn: existing?.isBuiltIn ?? false,
      compatibility: existing?.compatibility ??
          const ProfileCompatibility(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final settings = ref.read(settingsNotifierProvider);
    final List<AIBackendProfile> profiles;
    if (existing != null) {
      final alreadyStored =
          settings.profiles.any((p) => p.id == updated.id);
      if (alreadyStored) {
        profiles = settings.profiles
            .map((p) => p.id == updated.id ? updated : p)
            .toList();
      } else {
        // First time customising a built-in profile — add to list.
        profiles = [...settings.profiles, updated];
      }
    } else {
      profiles = [...settings.profiles, updated];
    }

    final failedMsg = context.l10n.profilesFailedToSave;
    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('profiles', profiles);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failedMsg)),
        );
      }
    }
  }

  void _applyTemplate(String templateId) {
    setState(() {
      _selectedTemplate = templateId;
      // Clear existing env rows
      for (final r in _envRows) {
        r.dispose();
      }
      _envRows.clear();

      switch (templateId) {
        case 'zai':
          _nameCtrl.text = 'Z.AI (GLM)';
          _descCtrl.text = 'Z.AI GLM via Anthropic-compatible interface';
          _envRows.addAll([
            _EnvRow(
              name: 'ANTHROPIC_BASE_URL',
              value: 'https://api.z.ai/api/anthropic',
            ),
            _EnvRow(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
            _EnvRow(name: 'API_TIMEOUT_MS', value: '300000'),
            _EnvRow(name: 'ANTHROPIC_MODEL', value: 'GLM-5'),
            _EnvRow(
              name: 'ANTHROPIC_DEFAULT_OPUS_MODEL',
              value: 'GLM-5',
            ),
            _EnvRow(
              name: 'ANTHROPIC_DEFAULT_SONNET_MODEL',
              value: 'GLM-5',
            ),
            _EnvRow(
              name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
              value: 'GLM-4.7',
            ),
          ]);
          break;
        case 'minimax':
          _nameCtrl.text = 'MiniMax';
          _descCtrl.text = 'MiniMax via OpenAI-compatible interface';
          _envRows.addAll([
            _EnvRow(
              name: 'OPENAI_BASE_URL',
              value: 'https://api.minimax.io/v1',
            ),
            _EnvRow(name: 'OPENAI_API_KEY', value: ''),
            _EnvRow(name: 'OPENAI_MODEL', value: 'MiniMax-Text-01'),
            _EnvRow(
              name: 'OPENAI_SMALL_FAST_MODEL',
              value: 'MiniMax-Text-01',
            ),
            _EnvRow(name: 'API_TIMEOUT_MS', value: '300000'),
          ]);
          break;
        case 'deepseek':
          _nameCtrl.text = 'DeepSeek (Reasoner)';
          _descCtrl.text = 'DeepSeek API via Anthropic-compatible interface';
          _envRows.addAll([
            _EnvRow(
              name: 'ANTHROPIC_BASE_URL',
              value: 'https://api.deepseek.com/anthropic',
            ),
            _EnvRow(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
            _EnvRow(name: 'API_TIMEOUT_MS', value: '600000'),
            _EnvRow(
              name: 'ANTHROPIC_MODEL',
              value: 'deepseek-reasoner',
            ),
            _EnvRow(
              name: 'ANTHROPIC_SMALL_FAST_MODEL',
              value: 'deepseek-chat',
            ),
          ]);
          break;
        case 'openai':
          _nameCtrl.text = 'OpenAI (GPT-5)';
          _descCtrl.text = 'OpenAI GPT-5 Codex API';
          _envRows.addAll([
            _EnvRow(
              name: 'OPENAI_BASE_URL',
              value: 'https://api.openai.com/v1',
            ),
            _EnvRow(name: 'OPENAI_API_KEY', value: ''),
            _EnvRow(name: 'OPENAI_MODEL', value: 'gpt-5-codex-high'),
            _EnvRow(
              name: 'OPENAI_SMALL_FAST_MODEL',
              value: 'gpt-5-codex-low',
            ),
            _EnvRow(name: 'API_TIMEOUT_MS', value: '600000'),
          ]);
          break;
        case 'anthropic':
          _nameCtrl.text = 'Anthropic (Default)';
          _descCtrl.text = 'Official Anthropic Claude API';
          _envRows.addAll([
            _EnvRow(
              name: 'ANTHROPIC_BASE_URL',
              value: 'https://api.anthropic.com',
            ),
            _EnvRow(name: 'ANTHROPIC_AUTH_TOKEN', value: ''),
            _EnvRow(name: 'API_TIMEOUT_MS', value: '300000'),
            _EnvRow(name: 'ANTHROPIC_MODEL', value: 'claude-opus-4-5'),
          ]);
          break;
      }
      _showScript = _envRows.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.existing != null;
    final isBuiltIn = widget.existing?.isBuiltIn ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? l10n.profilesEditProfile
              : l10n.profilesAddProfile,
        ),
        actions: [
          if (isBuiltIn)
            TextButton(
              onPressed: _resetToDefaults,
              child: Text(l10n.commonReset),
            ),
          TextButton(
            onPressed: _save,
            child: Text(l10n.commonSave),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppScreenPadding.settings,
          children: [
            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.profilesProfileName,
                hintText: l10n.profilesNameHint,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? l10n.profilesNameRequired
                      : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: l10n.profilesDescriptionLabel,
                hintText: l10n.profilesDescriptionHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Template selector for new profiles
            if (!isEditing) ...[
              _TemplateSelector(
                selectedTemplate: _selectedTemplate,
                onSelect: _applyTemplate,
                colorScheme: cs,
                textTheme: tt,
                l10n: l10n,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            _EnvVarsSection(
              envRows: _envRows,
              l10n: l10n,
              textTheme: tt,
              colorScheme: cs,
              onImport: _showImportDialog,
              onAdd: _addEnvRow,
              onRemove: _removeEnvRow,
              onChanged: () => setState(() {}),
            ),

            const SizedBox(height: AppSpacing.lg),

            _ScriptSection(
              show: _showScript,
              l10n: l10n,
              textTheme: tt,
              colorScheme: cs,
              controller: _scriptCtrl,
              onToggle: () => setState(() => _showScript = !_showScript),
            ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _TemplateSelector extends StatelessWidget {
  const _TemplateSelector({
    required this.selectedTemplate,
    required this.onSelect,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  final String? selectedTemplate;
  final void Function(String) onSelect;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.profilesQuickSetup,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.profilesQuickSetupHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _TemplateChip(
              label: 'Anthropic',
              icon: Icons.auto_awesome,
              color: colorForProfile('anthropic'),
              isSelected: selectedTemplate == 'anthropic',
              onTap: () => onSelect('anthropic'),
            ),
            _TemplateChip(
              label: 'Z.AI GLM',
              icon: Icons.bolt,
              color: colorForProfile('zai'),
              isSelected: selectedTemplate == 'zai',
              onTap: () => onSelect('zai'),
            ),
            _TemplateChip(
              label: 'DeepSeek',
              icon: Icons.psychology,
              color: colorForProfile('deepseek'),
              isSelected: selectedTemplate == 'deepseek',
              onTap: () => onSelect('deepseek'),
            ),
            _TemplateChip(
              label: 'MiniMax',
              icon: Icons.memory,
              color: colorForProfile('minimax'),
              isSelected: selectedTemplate == 'minimax',
              onTap: () => onSelect('minimax'),
            ),
            _TemplateChip(
              label: 'OpenAI',
              icon: Icons.smart_toy,
              color: colorForProfile('openai'),
              isSelected: selectedTemplate == 'openai',
              onTap: () => onSelect('openai'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withAlpha(40) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvVarsSection extends StatelessWidget {
  const _EnvVarsSection({
    required this.envRows,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
    required this.onImport,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<_EnvRow> envRows;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final VoidCallback onImport;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.profilesEnvVarsTitle,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.paste, size: 18),
              label: Text(l10n.profilesImportLabelShort),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.commonCreate),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.profilesEnvVarsHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (envRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              l10n.profilesEnvVarsEmpty,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ...envRows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.profilesEnvKeyLabel,
                      hintText: l10n.profilesEnvKeyHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.smd,
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.md,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 3,
                  child: _ValueField(row: row),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: colorScheme.error,
                  ),
                  onPressed: () => onRemove(i),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ScriptSection extends StatelessWidget {
  const _ScriptSection({
    required this.show,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
    required this.controller,
    required this.onToggle,
  });

  final bool show;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final TextEditingController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  show ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.profilesScriptTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.commonOptional,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (show) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.profilesScriptDescription,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.profilesScriptLabel,
              hintText: 'export MY_VAR=value\nsource ~/.env',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// Mutable row state for a single env variable entry.
class _EnvRow {
  _EnvRow({String name = '', String value = ''})
      : nameCtrl = TextEditingController(text: name),
        valueCtrl = TextEditingController(text: value);

  final TextEditingController nameCtrl;
  final TextEditingController valueCtrl;

  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
  }
}

/// Value field with toggle to show/hide the value (sensitive data).
class _ValueField extends StatefulWidget {
  const _ValueField({required this.row});
  final _EnvRow row;

  @override
  State<_ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<_ValueField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.row.valueCtrl,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).profilesEnvValueLabel,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            size: 18,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: AppFontSize.md,
      ),
    );
  }
}
