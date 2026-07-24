import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_card.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/mcp_server.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/safe_pop.dart';
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
  late final TextEditingController _envController;
  late final TextEditingController _urlController;
  late final TextEditingController _headersController;

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
    _envController = TextEditingController(
      text: _encodePairs(server?.env ?? const {}),
    );
    _urlController = TextEditingController(text: server?.url ?? '');
    _headersController = TextEditingController(
      text: _encodePairs(server?.headers ?? const {}),
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
    _envController.dispose();
    _urlController.dispose();
    _headersController.dispose();
    super.dispose();
  }

  static String _encodePairs(Map<String, String> pairs) => pairs.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join('\n');

  /// Parses `KEY=VALUE` lines. Blank lines are ignored; the first `=` splits,
  /// so values may contain `=` (common in tokens and base64).
  static Map<String, String> _decodePairs(String raw) {
    final out = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.indexOf('=');
      if (separator <= 0) continue;
      final key = trimmed.substring(0, separator).trim();
      if (key.isEmpty) continue;
      out[key] = trimmed.substring(separator + 1).trim();
    }
    return out;
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
      env: _decodePairs(_envController.text),
      url: _urlController.text.trim(),
      headers: _decodePairs(_headersController.text),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!response.success) {
      setState(() => _error = response.error ?? l10n.mcpSaveFailed);
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
                      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._-]*$')
                          .hasMatch(name)) {
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
                        for (final project
                            in <String>{
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
                    onSelectionChanged: (selection) => setState(
                      () => _transport = selection.first,
                    ),
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
                        TextFormField(
                          controller: _envController,
                          autocorrect: false,
                          minLines: 2,
                          maxLines: 8,
                          decoration: InputDecoration(
                            labelText: l10n.mcpFieldEnv,
                            helperText: l10n.mcpEnvHelper,
                            helperMaxLines: 3,
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
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
                        TextFormField(
                          controller: _headersController,
                          autocorrect: false,
                          minLines: 2,
                          maxLines: 6,
                          decoration: InputDecoration(
                            labelText: l10n.mcpFieldHeaders,
                            helperText: l10n.mcpHeadersHelper,
                            helperMaxLines: 3,
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
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
