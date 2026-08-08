import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_badge.dart';
import '../../core/components/app_card.dart';
import '../../core/components/app_empty_state.dart';
import '../../core/components/app_error_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/app_section_header.dart';
import '../../core/components/settings_section.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/remote_feature_failure_localization.dart';
import '../../core/models/machine.dart';
import '../../core/models/mcp_server.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/settings/widgets/machine_picker.dart';
import 'mcp_server_edit_screen.dart';

/// Remote management of a machine's Claude Code MCP servers.
///
/// Everything on this screen is read from, and written to, the selected
/// machine's daemon over encrypted RPC — the app holds no MCP state of its own.
class McpServersScreen extends ConsumerStatefulWidget {
  const McpServersScreen({super.key});

  @override
  ConsumerState<McpServersScreen> createState() => _McpServersScreenState();
}

class _McpServersScreenState extends ConsumerState<McpServersScreen> {
  String? _selectedMachineId;

  /// Project directory scoping the `local` / `project` / settings-file scopes.
  /// Null means "machine scopes only".
  String? _selectedProjectDir;

  McpConfigResponse? _config;
  bool _isLoading = false;
  String? _error;

  /// Identity of the server currently being written, so only its row shows a
  /// pending state instead of freezing the whole list.
  String? _busyIdentity;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_autoSelectMachine);
  }

  void _autoSelectMachine() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final machines = ref.read(machinesNotifierProvider).values.toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(now, a, b));
    final online = machines.where((machine) => machine.isOnline).toList();
    if (online.isEmpty) return;
    setState(() => _selectedMachineId = online.first.id);
    unawaited(_load());
  }

  Future<void> _load() async {
    final machineId = _selectedMachineId;
    if (machineId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await Sync().machineListMcpServers(
      machineId: machineId,
      projectDir: _selectedProjectDir,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.success) {
        _config = response;
        _error = null;
      } else {
        _error = response.failureKind.localizedRemoteFeatureFailure(
          context.l10n,
        );
      }
    });
  }

  void _onMachineChanged(String? machineId) {
    if (machineId == null || machineId == _selectedMachineId) return;
    setState(() {
      _selectedMachineId = machineId;
      // Project directories are machine-specific.
      _selectedProjectDir = null;
      _config = null;
    });
    unawaited(_load());
  }

  void _onProjectChanged(String? projectDir) {
    final normalized = (projectDir ?? '').isEmpty ? null : projectDir;
    if (normalized == _selectedProjectDir) return;
    setState(() => _selectedProjectDir = normalized);
    unawaited(_load());
  }

  /// Applies a mutation result: on success the fresh snapshot replaces local
  /// state, on failure the list is left untouched and the reason is shown.
  void _applyResult(McpConfigResponse response, {required String fallback}) {
    if (!mounted) return;
    if (response.success) {
      setState(() {
        _config = response;
        _error = null;
      });
      return;
    }
    final message = response.failureKind == null
        ? fallback
        : response.failureKind.localizedRemoteFeatureFailure(context.l10n);
    setState(() => _error = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(McpServer server, bool enabled) async {
    final machineId = _selectedMachineId;
    if (machineId == null) return;
    if (enabled) {
      final l10n = context.l10n;
      final secretNames = <String>{
        ...server.env.keys,
        ...server.headers.keys,
      }.toList()..sort();
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.mcpEnableTrustTitle(server.name),
        content: l10n.mcpEnableTrustBody(
          server.target.isEmpty ? server.transport.wire : server.target,
          scopeLabel(context, server.scope),
          server.projectDir ?? l10n.mcpNoProject,
          secretNames.isEmpty ? l10n.mcpNoSecrets : secretNames.join(', '),
        ),
        confirmLabel: l10n.mcpEnableServer,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _busyIdentity = server.identity);
    final response = await Sync().machineToggleMcpServer(
      machineId: machineId,
      scope: server.scope,
      name: server.name,
      enabled: enabled,
      projectDir: server.projectDir ?? _selectedProjectDir,
    );
    if (!mounted) return;
    setState(() => _busyIdentity = null);
    _applyResult(response, fallback: context.l10n.mcpToggleFailed(server.name));
    if (enabled && response.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.mcpEnabledWithUndo),
          action: SnackBarAction(
            label: context.l10n.commonUndo,
            onPressed: () => unawaited(_toggle(server, false)),
          ),
        ),
      );
    }
  }

  Future<void> _delete(McpServer server) async {
    final machineId = _selectedMachineId;
    if (machineId == null) return;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.mcpDeleteTitle,
      content: l10n.mcpDeleteConfirm(server.name, server.scope.wire),
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyIdentity = server.identity);
    final response = await Sync().machineRemoveMcpServer(
      machineId: machineId,
      scope: server.scope,
      name: server.name,
      projectDir: server.projectDir ?? _selectedProjectDir,
    );
    if (!mounted) return;
    setState(() => _busyIdentity = null);
    _applyResult(response, fallback: l10n.mcpDeleteFailed(server.name));
  }

  Future<void> _openEditor({McpServer? server}) async {
    final machineId = _selectedMachineId;
    if (machineId == null) return;
    final result = await context.pushNamed<McpConfigResponse>(
      'mcp-server-edit',
      extra: McpServerEditArgs(
        machineId: machineId,
        projectDir: _selectedProjectDir,
        knownProjects: _config?.projects ?? const [],
        server: server,
      ),
    );
    if (!mounted) return;
    if (result != null) {
      _applyResult(result, fallback: context.l10n.mcpSaveFailed);
    } else {
      // The editor may have been dismissed after a partial change; a cheap
      // re-read keeps the list honest.
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machines = ref.watch(machinesNotifierProvider);
    final config = _config;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mcpServersTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _isLoading ? null : () => unawaited(_load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _selectedMachineId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => unawaited(_openEditor()),
              icon: const Icon(Icons.add),
              label: Text(l10n.mcpAddServer),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
          children: [
            MachinePicker(
              machines: machines,
              selectedMachineId: _selectedMachineId,
              onChanged: _onMachineChanged,
              sectionTitle: l10n.mcpMachineSection,
            ),
            if (config != null)
              _ProjectPicker(
                projects: config.projects,
                selected: _selectedProjectDir,
                onChanged: _onProjectChanged,
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                child: AppLoadingIndicator(),
              )
            else if (_error != null && config == null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppErrorState(
                  message: _error!,
                  onRetry: () => unawaited(_load()),
                ),
              )
            else if (config != null)
              ..._buildConfigBody(context, config),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConfigBody(
    BuildContext context,
    McpConfigResponse config,
  ) {
    final l10n = context.l10n;
    if (config.servers.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.extension_outlined,
            title: l10n.mcpNoServersTitle,
            subtitle: l10n.mcpNoServersSubtitle,
          ),
        ),
      ];
    }

    // Group by scope so it is obvious which file an edit will touch.
    final grouped = <McpServerScope, List<McpServer>>{};
    for (final server in config.servers) {
      grouped.putIfAbsent(server.scope, () => []).add(server);
    }
    final orderedScopes = McpServerScope.values
        .where(grouped.containsKey)
        .toList();

    return [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: _NoticeCard(icon: Icons.error_outline, message: _error!),
        ),
      for (final warning in config.warnings)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: _NoticeCard(icon: Icons.warning_amber, message: warning),
        ),
      for (final scope in orderedScopes) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: AppSectionHeader(title: scopeLabel(context, scope)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final server in grouped[scope]!)
                  _ServerRow(
                    server: server,
                    busy: _busyIdentity == server.identity,
                    onToggle: (value) => unawaited(_toggle(server, value)),
                    onEdit: () => unawaited(_openEditor(server: server)),
                    onDelete: () => unawaited(_delete(server)),
                  ),
              ],
            ),
          ),
        ),
      ],
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _SourcePaths(config: config),
      ),
    ];
  }
}

/// Human label for a scope, including the file it maps to.
String scopeLabel(BuildContext context, McpServerScope scope) {
  final l10n = context.l10n;
  return switch (scope) {
    McpServerScope.user => l10n.mcpScopeUser,
    McpServerScope.userSettings => l10n.mcpScopeUserSettings,
    McpServerScope.local => l10n.mcpScopeLocal,
    McpServerScope.project => l10n.mcpScopeProject,
    McpServerScope.projectSettings => l10n.mcpScopeProjectSettings,
    McpServerScope.localSettings => l10n.mcpScopeLocalSettings,
  };
}

class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({
    required this.projects,
    required this.selected,
    required this.onChanged,
  });

  final List<String> projects;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A project that is not in the daemon's list (e.g. it was just removed)
    // must still render, otherwise the dropdown value has no matching item.
    final options = <String>{...projects, ?selected}.toList()..sort();

    return SettingsSection(
      title: l10n.mcpProjectSection,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: DropdownButtonFormField<String>(
            initialValue: selected ?? '',
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              helperText: l10n.mcpProjectHelper,
              helperMaxLines: 3,
            ),
            items: [
              DropdownMenuItem<String>(
                value: '',
                child: Text(l10n.mcpProjectNone),
              ),
              for (final project in options)
                DropdownMenuItem<String>(
                  value: project,
                  child: Text(project, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.server,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final McpServer server;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData get _icon => switch (server.transport) {
    McpTransport.stdio => Icons.terminal,
    McpTransport.sse => Icons.stream,
    McpTransport.http => Icons.cloud_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Opacity(
      opacity: server.enabled ? 1 : 0.6,
      child: SettingsRow(
        icon: _icon,
        title: server.name,
        subtitle: server.target.isEmpty ? server.transport.wire : server.target,
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (server.needsAuth)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: AppBadge(
                  label: l10n.mcpBadgeNeedsAuth,
                  backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                  foregroundColor: AppColors.warning,
                ),
              ),
            if (server.shadowed)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: AppBadge(
                  label: l10n.mcpBadgeShadowed,
                  backgroundColor: cs.surfaceContainerHighest,
                  foregroundColor: cs.onSurfaceVariant,
                ),
              ),
            if (server.awaitingApproval)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: AppBadge(
                  label: l10n.mcpBadgeAwaitingApproval,
                  backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                  foregroundColor: AppColors.warning,
                ),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: AppLoadingIndicator(size: AppSpacing.lg),
              )
            else
              Switch(value: server.enabled, onChanged: onToggle),
            PopupMenuButton<String>(
              tooltip: l10n.commonMore,
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text(l10n.commonEdit),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(
                    l10n.commonDelete,
                    style: TextStyle(color: cs.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePaths extends StatelessWidget {
  const _SourcePaths({required this.config});

  final McpConfigResponse config;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Text(
        '$label: $value',
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontFamily: 'monospace',
          fontSize: AppFontSize.xs,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mcpSourceFiles,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (config.claudeConfigPath != null)
          line('state', config.claudeConfigPath!),
        if (config.userSettingsPath != null)
          line('settings', config.userSettingsPath!),
        if (config.projectMcpPath != null)
          line('project', config.projectMcpPath!),
        if (config.enableAllProjectMcpServers)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              l10n.mcpApproveAllEnabled,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
