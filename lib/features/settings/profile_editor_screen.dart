import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/env_secrets.dart';
import '../../core/utils/shell_script_parser.dart';
import '../../core/utils/snack.dart';
import 'profile_setup_catalog.dart';
import 'widgets/profile_editor_row_state.dart';
import 'widgets/profile_editor_widgets.dart';

/// Full-screen editor for creating or editing a custom AI backend
/// profile.
class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({
    super.key,
    this.existing,
    this.profileId,
    this.embedded = false,
    this.onClose,
  });

  /// Existing profile to edit; null means create new. Takes
  /// precedence over [profileId] when both are provided.
  final AIBackendProfile? existing;

  /// Optional profile ID; when set and [existing] is null, the editor
  /// resolves the profile from current settings (custom + built-in).
  /// Useful for embedded master-detail flows where the master keeps
  /// only an ID in state.
  final String? profileId;

  /// When true, renders without a [Scaffold]/[AppBar] for use inside
  /// a master-detail pane on tablet. A thin in-pane header with the
  /// title and a close icon is rendered instead.
  final bool embedded;

  /// Callback invoked when the editor wants to close itself while in
  /// [embedded] mode (replaces the route pop).
  final VoidCallback? onClose;

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
  late final List<ModelRow> _modelRows;
  AIBackendProfile? _profile;
  late ProfileCompatibility _compatibility;
  int? _contextWindow;

  bool _showScript = false;
  String? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _profile = widget.existing ?? _resolveProfileById(widget.profileId);
    final p = _profile;
    _compatibility = p?.compatibility ?? const ProfileCompatibility();
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _scriptCtrl = TextEditingController(text: p?.startupBashScript ?? '');
    _envRows = (p?.environmentVariables ?? [])
        .map((e) => EnvRow(name: e.name, value: e.value))
        .toList();
    _modelRows = (p?.models ?? []).map((m) => ModelRow(model: m)).toList();
    _contextWindow = p?.contextWindow;
    _showScript = p?.startupBashScript?.isNotEmpty ?? false;
  }

  AIBackendProfile? _resolveProfileById(String? id) {
    if (id == null) return null;
    final settings = ref.read(settingsNotifierProvider);
    for (final p in settings.profiles) {
      if (p.id == id) return p;
    }
    return getBuiltInProfile(id);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _scriptCtrl.dispose();
    for (final r in _envRows) {
      r.dispose();
    }
    for (final r in _modelRows) {
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

  void _addModelRow() {
    setState(() => _modelRows.add(ModelRow()));
  }

  void _removeModelRow(int index) {
    setState(() {
      _modelRows[index].dispose();
      _modelRows.removeAt(index);
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
        context.showSnack(l10n.profilesImportNoVars);
      }
      return;
    }

    // Auto-fill name if empty — secret variables are skipped so a
    // pasted credential can never become the (unmasked) profile name.
    if (_nameCtrl.text.trim().isEmpty) {
      final suggested = suggestProfileName(result.envVars);
      if (suggested != null) {
        _nameCtrl.text = suggested;
      }
    }

    setState(() {
      final inferredCompatibility = inferProfileCompatibility(result.envVars);
      for (final r in _envRows) {
        r.dispose();
      }
      _envRows.clear();
      _compatibility = inferredCompatibility;
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
    final existing = _profile;
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
      if (mounted) _close();
    } catch (e) {
      if (mounted) {
        context.showSnack(failedMsg);
      }
    }
  }

  void _close() {
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }
    Navigator.of(context).pop();
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

    final models = _modelRows
        .map((r) => r.modelCtrl.text.trim())
        .where((m) => m.isNotEmpty)
        .toList();

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _profile;
    final updated = AIBackendProfile(
      id: existing?.id ?? 'custom_$now',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      startupBashScript: _showScript && _scriptCtrl.text.trim().isNotEmpty
          ? _scriptCtrl.text.trim()
          : null,
      environmentVariables: envVars,
      defaultModelMode:
          AIBackendProfile.inferDefaultModelMode(
            environmentVariables: envVars,
          ) ??
          existing?.defaultModelMode,
      contextWindow: _contextWindow,
      models: models,
      isBuiltIn: existing?.isBuiltIn ?? false,
      compatibility: _compatibility,
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
      if (mounted) _close();
    } catch (e) {
      if (mounted) {
        context.showSnack(failedMsg);
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
      _compatibility = template.compatibility;
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

  void _setAgentCompatibility(String agent, bool selected) {
    final selectedCount = [
      _compatibility.claude,
      _compatibility.codex,
      _compatibility.gemini,
    ].where((value) => value).length;
    if (!selected && selectedCount == 1) {
      context.showSnack(context.l10n.profilesAtLeastOneAgent);
      return;
    }

    setState(() {
      _compatibility = ProfileCompatibility(
        claude: agent == 'claude' ? selected : _compatibility.claude,
        codex: agent == 'codex' ? selected : _compatibility.codex,
        gemini: agent == 'gemini' ? selected : _compatibility.gemini,
        pi: _compatibility.pi,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final isEditing = _profile != null;
    final isBuiltIn = _profile?.isBuiltIn ?? false;
    final title = isEditing
        ? l10n.profilesEditProfile
        : l10n.profilesAddProfile;

    final form = Form(
      key: _formKey,
      child: ListView(
        padding: AppScreenPadding.settings,
        children: [
          AppCard(
            child: Column(
              children: [
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
                TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.profilesDescriptionLabel,
                    hintText: l10n.profilesDescriptionHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Template selector for new profiles
          if (!isEditing)
            AppCard(
              child: TemplateSelector(
                selectedTemplate: _selectedTemplate,
                onSelect: _applyTemplate,
                colorScheme: cs,
                textTheme: tt,
                l10n: l10n,
              ),
            ),
          const SizedBox(height: AppSpacing.md),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profilesCompatibleAgents,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.profilesCompatibleAgentsHint,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilterChip(
                      label: Text(l10n.agentAgentClaude),
                      selected: _compatibility.claude,
                      onSelected: (selected) =>
                          _setAgentCompatibility('claude', selected),
                    ),
                    FilterChip(
                      label: Text(l10n.agentAgentCodex),
                      selected: _compatibility.codex,
                      onSelected: (selected) =>
                          _setAgentCompatibility('codex', selected),
                    ),
                    FilterChip(
                      label: Text(l10n.agentAgentGemini),
                      selected: _compatibility.gemini,
                      onSelected: (selected) =>
                          _setAgentCompatibility('gemini', selected),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          AppCard(
            child: EnvVarsSection(
              envRows: _envRows,
              l10n: l10n,
              textTheme: tt,
              colorScheme: cs,
              onImport: _showImportDialog,
              onAdd: _addEnvRow,
              onRemove: _removeEnvRow,
              onChanged: () => setState(() {}),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          AppCard(
            child: ModelsSection(
              modelRows: _modelRows,
              l10n: l10n,
              textTheme: tt,
              colorScheme: cs,
              onAdd: _addModelRow,
              onRemove: _removeModelRow,
              onChanged: () => setState(() {}),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          AppCard(
            child: ContextWindowSection(
              contextWindow: _contextWindow,
              l10n: l10n,
              textTheme: tt,
              colorScheme: cs,
              onChanged: (value) => setState(() => _contextWindow = value),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: ScriptSection(
              show: _showScript,
              l10n: l10n,
              textTheme: tt,
              colorScheme: cs,
              controller: _scriptCtrl,
              onToggle: () => setState(() => _showScript = !_showScript),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EmbeddedHeader(
            title: title,
            onClose: _close,
            onReset: isBuiltIn ? _resetToDefaults : null,
            onSave: _save,
            resetLabel: l10n.commonReset,
            saveLabel: l10n.commonSave,
          ),
          Expanded(child: form),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
      body: form,
    );
  }
}

class _EmbeddedHeader extends StatelessWidget {
  const _EmbeddedHeader({
    required this.title,
    required this.onClose,
    required this.onSave,
    required this.saveLabel,
    required this.resetLabel,
    this.onReset,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final VoidCallback? onReset;
  final String saveLabel;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: AppBorder.thin),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: MaterialLocalizations.of(context).closeButtonLabel,
              onPressed: onClose,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                title,
                style: tt.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onReset != null)
              TextButton(onPressed: onReset, child: Text(resetLabel)),
            TextButton(onPressed: onSave, child: Text(saveLabel)),
          ],
        ),
      ),
    );
  }
}
