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
  AIBackendProfile? _profile;

  bool _showScript = false;
  String? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _profile = widget.existing ?? _resolveProfileById(widget.profileId);
    final p = _profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _scriptCtrl = TextEditingController(text: p?.startupBashScript ?? '');
    _envRows = (p?.environmentVariables ?? [])
        .map((e) => EnvRow(name: e.name, value: e.value))
        .toList();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failedMsg)));
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
      if (mounted) _close();
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
