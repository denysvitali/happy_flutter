import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/shell_script_parser.dart';
import 'profile_setup_catalog.dart';
import 'widgets/profile_editor_widgets.dart';

/// Full-screen editor for creating or editing a custom AI backend
/// profile.
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
  late final List<EnvRow> _envRows;

  bool _showScript = false;
  String? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _scriptCtrl = TextEditingController(text: p?.startupBashScript ?? '');
    _envRows = (p?.environmentVariables ?? [])
        .map((e) => EnvRow(name: e.name, value: e.value))
        .toList();
    _showScript = p?.startupBashScript?.isNotEmpty ?? false;
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
    setState(() => _envRows.add(EnvRow()));
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
                  hintText:
                      'export ANTHROPIC_BASE_URL=...\n'
                      'export ANTHROPIC_AUTH_TOKEN=...',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profilesImportNoVars)));
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
        _envRows.add(EnvRow(name: env.name, value: env.value));
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
    final updatedProfiles = settings.profiles
        .where((p) => p.id != existing.id)
        .toList();

    final failedMsg = context.l10n.profilesFailedToSave;
    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('profiles', updatedProfiles);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failedMsg)));
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
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      startupBashScript: _showScript && _scriptCtrl.text.trim().isNotEmpty
          ? _scriptCtrl.text.trim()
          : null,
      environmentVariables: envVars,
      isBuiltIn: existing?.isBuiltIn ?? false,
      compatibility: existing?.compatibility ?? const ProfileCompatibility(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final settings = ref.read(settingsNotifierProvider);
    final List<AIBackendProfile> profiles;
    if (existing != null) {
      final alreadyStored = settings.profiles.any((p) => p.id == updated.id);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failedMsg)));
      }
    }
  }

  void _applyTemplate(String templateId) {
    final template = profileSetupTemplate(templateId);
    if (template == null) {
      return;
    }

    setState(() {
      _selectedTemplate = templateId;
      for (final r in _envRows) {
        r.dispose();
      }
      _envRows.clear();
      _nameCtrl.text = template.name;
      _descCtrl.text = template.description ?? '';
      _envRows.addAll(
        template.environmentVariables.map(
          (env) => EnvRow(name: env.name, value: env.value),
        ),
      );
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
          isEditing ? l10n.profilesEditProfile : l10n.profilesAddProfile,
        ),
        actions: [
          if (isBuiltIn)
            TextButton(
              onPressed: _resetToDefaults,
              child: Text(l10n.commonReset),
            ),
          TextButton(onPressed: _save, child: Text(l10n.commonSave)),
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
              validator: (v) => v == null || v.trim().isEmpty
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
              TemplateSelector(
                selectedTemplate: _selectedTemplate,
                onSelect: _applyTemplate,
                colorScheme: cs,
                textTheme: tt,
                l10n: l10n,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            EnvVarsSection(
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

            ScriptSection(
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
