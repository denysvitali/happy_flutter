import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';

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
    final updated = AIBackendProfile(
      id: widget.existing?.id ?? 'custom_$now',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      startupBashScript: _showScript && _scriptCtrl.text.trim().isNotEmpty
          ? _scriptCtrl.text.trim()
          : null,
      environmentVariables: envVars,
      isBuiltIn: false,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );

    final settings = ref.read(settingsNotifierProvider);
    final List<AIBackendProfile> profiles;
    if (widget.existing != null) {
      profiles = settings.profiles
          .map((p) => p.id == updated.id ? updated : p)
          .toList();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Profile' : 'New Profile'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Profile Name',
                hintText: 'e.g. MiniMax, Kimi Code, DeepSeek',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. MiniMax via OpenAI-compatible API',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Environment variables section
            Row(
              children: [
                Text(
                  'Environment Variables',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addEnvRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Set ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, '
              'ANTHROPIC_MODEL, etc.',
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (_envRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md),
                child: Text(
                  'No environment variables. Tap Add to set one.',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),

            ..._envRows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Padding(
                padding:
                    const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: row.nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Key',
                          hintText: 'VARIABLE_NAME',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        textCapitalization:
                            TextCapitalization.characters,
                        onChanged: (_) => setState(() {}),
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
                        color: cs.error,
                      ),
                      onPressed: () => _removeEnvRow(i),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppSpacing.lg),

            // Advanced: startup script
            InkWell(
              borderRadius:
                  BorderRadius.circular(AppRadius.sm),
              onTap: () =>
                  setState(() => _showScript = !_showScript),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      _showScript
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Startup Shell Script',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '(optional)',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),

            if (_showScript) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Runs before each session starts. '
                'Use to export variables or configure the environment.',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _scriptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bash script',
                  hintText: 'export MY_VAR=value\nsource ~/.env',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
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
        labelText: 'Value',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
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
        fontSize: 13,
      ),
    );
  }
}
