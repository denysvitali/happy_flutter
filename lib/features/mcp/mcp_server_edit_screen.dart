import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_card.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/remote_feature_failure_localization.dart';
import '../../core/models/mcp_server.dart';
import '../../core/routing/safe_pop.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import 'mcp_servers_screen.dart' show scopeLabel;

/// Navigation payload for [McpServerEditScreen].
class McpServerEditArgs {
  const McpServerEditArgs({
    required this.machineId,
    this.projectDir,
    this.knownProjects = const [],
    this.server,
  });

  final String machineId;

  /// Project directory selected on the list screen; pre-fills project scopes.
  final String? projectDir;
  final List<String> knownProjects;

  /// Null for a new server; set when editing an existing declaration.
  final McpServer? server;
}

/// Presence-only editor state for an MCP secret map.
///
/// Existing wire values are deliberately discarded. A null draft value means
/// "preserve this existing key" and serializes to [mcpRedactedValue].
class McpSecretMapController {
  McpSecretMapController._(this._values);

  factory McpSecretMapController.fromWire(Map<String, String> values) {
    return McpSecretMapController._({
      for (final key in values.keys.where((key) => key.trim().isNotEmpty))
        key: null,
    });
  }

  factory McpSecretMapController.empty() => McpSecretMapController._({});

  final Map<String, String?> _values;

  List<String> get keys => _values.keys.toList()..sort();

  bool containsKey(String key) => _values.containsKey(key);

  bool hasReplacement(String key) => _values[key] != null;

  void replace(String key, String value) => _values[key] = value;

  void add(String key, String value) => _values[key] = value;

  void remove(String key) => _values.remove(key);

  Map<String, String> toWire() => {
    for (final entry in _values.entries)
      entry.key: entry.value ?? mcpRedactedValue,
  };
}

/// Form for creating or editing one MCP server on a machine.
///
/// Name and scope together identify a declaration, so both are locked while
/// editing — changing either would silently create a second server instead of
/// moving the original. Deleting and re-adding is the explicit path.
class McpServerEditScreen extends ConsumerStatefulWidget {
  const McpServerEditScreen({required this.args, super.key});

  final McpServerEditArgs args;

  @override
  ConsumerState<McpServerEditScreen> createState() =>
      _McpServerEditScreenState();
}

class _McpServerEditScreenState extends ConsumerState<McpServerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _commandController;
  late final TextEditingController _argsController;
  late final TextEditingController _urlController;
  late final McpSecretMapController _envSecrets;
  late final McpSecretMapController _headerSecrets;

  late McpServerScope _scope;
  late McpTransport _transport;
  String? _projectDir;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.args.server != null;

  @override
  void initState() {
    super.initState();
    final server = widget.args.server;
    _nameController = TextEditingController(text: server?.name ?? '');
    _commandController = TextEditingController(text: server?.command ?? '');
    _argsController = TextEditingController(
      text: (server?.args ?? const []).join('\n'),
    );
    _envSecrets = McpSecretMapController.fromWire(server?.env ?? const {});
    _urlController = TextEditingController(text: server?.url ?? '');
    _headerSecrets = McpSecretMapController.fromWire(
      server?.headers ?? const {},
    );
    _scope = server?.scope ?? McpServerScope.user;
    _transport = server?.transport ?? McpTransport.stdio;
    _projectDir = server?.projectDir ?? widget.args.projectDir;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _argsController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  static List<String> _decodeLines(String raw) => raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_scope.isProjectScoped && (_projectDir ?? '').isEmpty) {
      setState(() => _error = l10n.mcpProjectRequired);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final response = await Sync().machineSetMcpServer(
      machineId: widget.args.machineId,
      scope: _scope,
      name: _nameController.text.trim(),
      transport: _transport,
      projectDir: _scope.isProjectScoped ? _projectDir : null,
      command: _commandController.text.trim(),
      args: _decodeLines(_argsController.text),
      env: _envSecrets.toWire(),
      url: _urlController.text.trim(),
      headers: _headerSecrets.toWire(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!response.success) {
      setState(
        () => _error = response.failureKind == null
            ? l10n.mcpSaveFailed
            : response.failureKind.localizedRemoteFeatureFailure(l10n),
      );
      return;
    }
    safePop<McpConfigResponse>(context, result: response);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isStdio = _transport == McpTransport.stdio;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.mcpEditTitle : l10n.mcpAddServer),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => unawaited(_save()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            SettingsSection(
              title: l10n.mcpIdentitySection,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextFormField(
                    controller: _nameController,
                    enabled: !_isEditing,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.mcpFieldName,
                      helperText: _isEditing
                          ? l10n.mcpNameLockedHelper
                          : l10n.mcpNameHelper,
                      helperMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final name = (value ?? '').trim();
                      if (name.isEmpty) return l10n.mcpNameRequired;
                      if (!RegExp(
                        r'^[A-Za-z0-9][A-Za-z0-9 ._-]*$',
                      ).hasMatch(name)) {
                        return l10n.mcpNameInvalid;
                      }
                      return null;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: DropdownButtonFormField<McpServerScope>(
                    initialValue: _scope,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.mcpFieldScope,
                      helperText: l10n.mcpScopeHelper,
                      helperMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final scope in McpServerScope.values)
                        DropdownMenuItem<McpServerScope>(
                          value: scope,
                          child: Text(
                            scopeLabel(context, scope),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _isEditing
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _scope = value);
                          },
                  ),
                ),
                if (_scope.isProjectScoped)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _projectDir,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.mcpFieldProject,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final project in <String>{
                          ...widget.args.knownProjects,
                          ?_projectDir,
                        }.toList()..sort())
                          DropdownMenuItem<String>(
                            value: project,
                            child: Text(
                              project,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _isEditing
                          ? null
                          : (value) => setState(() => _projectDir = value),
                    ),
                  ),
              ],
            ),
            SettingsSection(
              title: l10n.mcpTransportSection,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SegmentedButton<McpTransport>(
                    segments: [
                      for (final transport in McpTransport.values)
                        ButtonSegment<McpTransport>(
                          value: transport,
                          label: Text(transport.wire),
                        ),
                    ],
                    selected: {_transport},
                    onSelectionChanged: (selection) =>
                        setState(() => _transport = selection.first),
                  ),
                ),
              ],
            ),
            if (isStdio)
              SettingsSection(
                title: l10n.mcpProcessSection,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _commandController,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: l10n.mcpFieldCommand,
                            helperText: l10n.mcpCommandHelper,
                            helperMaxLines: 3,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (_transport != McpTransport.stdio) return null;
                            if ((value ?? '').trim().isEmpty) {
                              return l10n.mcpCommandRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _argsController,
                          autocorrect: false,
                          minLines: 2,
                          maxLines: 6,
                          decoration: InputDecoration(
                            labelText: l10n.mcpFieldArgs,
                            helperText: l10n.mcpArgsHelper,
                            helperMaxLines: 3,
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SecretMapEditor(
                          title: l10n.mcpFieldEnv,
                          helper: l10n.mcpEnvHelper,
                          controller: _envSecrets,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              SettingsSection(
                title: l10n.mcpEndpointSection,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _urlController,
                          autocorrect: false,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: l10n.mcpFieldUrl,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (_transport == McpTransport.stdio) return null;
                            final url = (value ?? '').trim();
                            if (url.isEmpty) return l10n.mcpUrlRequired;
                            final parsed = Uri.tryParse(url);
                            if (parsed == null || !parsed.hasScheme) {
                              return l10n.mcpUrlInvalid;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SecretMapEditor(
                          title: l10n.mcpFieldHeaders,
                          helper: l10n.mcpHeadersHelper,
                          controller: _headerSecrets,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: FilledButton(
                onPressed: _isSaving ? null : () => unawaited(_save()),
                child: Text(_isSaving ? l10n.commonSaving : l10n.commonSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecretMapEditor extends StatelessWidget {
  const _SecretMapEditor({
    required this.title,
    required this.helper,
    required this.controller,
    required this.onChanged,
  });

  final String title;
  final String helper;
  final McpSecretMapController controller;
  final VoidCallback onChanged;

  Future<void> _editSecret(BuildContext context, {String? existingKey}) async {
    final l10n = context.l10n;
    final keyController = TextEditingController(text: existingKey ?? '');
    final valueController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<({String key, String value})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existingKey == null ? l10n.mcpSecretAdd : l10n.mcpSecretReplace,
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: keyController,
                readOnly: existingKey != null,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: l10n.mcpSecretKey),
                validator: (value) {
                  final key = (value ?? '').trim();
                  if (key.isEmpty) return l10n.mcpSecretKeyRequired;
                  if (existingKey == null && controller.containsKey(key)) {
                    return l10n.mcpSecretKeyExists;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: valueController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: l10n.mcpSecretValue),
                validator: (value) =>
                    (value ?? '').isEmpty ? l10n.mcpSecretValueRequired : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(context).pop((
                key: keyController.text.trim(),
                value: valueController.text,
              ));
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    keyController.dispose();
    valueController.dispose();
    if (result == null) return;
    if (existingKey == null) {
      controller.add(result.key, result.value);
    } else {
      controller.replace(existingKey, result.value);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          helper,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final key in controller.keys)
          SettingsRow(
            icon: Icons.key_outlined,
            title: key,
            subtitle: controller.hasReplacement(key)
                ? l10n.mcpSecretReplacementReady
                : l10n.mcpSecretStored,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.mcpSecretReplace,
                  onPressed: () => _editSecret(context, existingKey: key),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: l10n.mcpSecretRemove,
                  onPressed: () {
                    controller.remove(key);
                    onChanged();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _editSecret(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.mcpSecretAdd),
          ),
        ),
      ],
    );
  }
}
