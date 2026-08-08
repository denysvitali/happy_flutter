import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_card.dart';
import '../../core/components/app_empty_state.dart';
import '../../core/components/app_error_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/settings_section.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/remote_feature_failure_localization.dart';
import '../../core/models/machine.dart';
import '../../core/models/sandbox_policy.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../settings/widgets/machine_picker.dart';

/// Per-project sandbox policy for a machine.
///
/// A sandboxed session sees its project directory and the public internet and
/// nothing else — not the home directory it was launched from, not SSH keys,
/// not the machine's other projects. That is the default, so this screen is
/// about the exceptions: granting a project the extra folder its build needs,
/// or turning the sandbox off for a project that cannot work inside one.
///
/// Everything here is read from, and written to, the selected machine's
/// daemon over encrypted RPC. Paths only mean something on that machine, so
/// the app holds no sandbox state of its own.
class SandboxScreen extends ConsumerStatefulWidget {
  const SandboxScreen({super.key, this.initialDirectory});

  /// Opens straight onto one project, for the "sandbox settings" entry point
  /// on a session or folder.
  final String? initialDirectory;

  @override
  ConsumerState<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends ConsumerState<SandboxScreen> {
  String? _selectedMachineId;
  String? _selectedDirectory;

  SandboxPolicyResponse? _machine;
  SandboxPolicyResponse? _project;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDirectory = widget.initialDirectory;
    Future<void>.microtask(_autoSelectMachine);
  }

  void _autoSelectMachine() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final machines = ref.read(machinesNotifierProvider).values.toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(now, a, b));
    final online = machines
        .where(
          (machine) =>
              machine.isOnline && (machine.metadata?.sandboxAvailable ?? false),
        )
        .toList();
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
    final list = await Sync().machineListSandboxPolicies(machineId: machineId);
    if (!mounted) return;
    if (!list.success) {
      setState(() {
        _isLoading = false;
        _error = list.failureKind.localizedRemoteFeatureFailure(context.l10n);
      });
      return;
    }
    // Default to the first configured project so the screen is not empty on a
    // machine that already has policies; with none, the user picks one.
    var directory = _selectedDirectory;
    if (directory == null && list.projects.isNotEmpty) {
      directory = list.projects.first.directory;
    }
    SandboxPolicyResponse? project;
    if (directory != null) {
      project = await Sync().machineGetSandboxPolicy(
        machineId: machineId,
        directory: directory,
      );
      if (!mounted) return;
    }
    setState(() {
      _isLoading = false;
      _machine = list;
      _selectedDirectory = directory;
      _project = project != null && project.success ? project : null;
      _error = project != null && !project.success
          ? project.failureKind.localizedRemoteFeatureFailure(context.l10n)
          : null;
    });
  }

  void _onMachineChanged(String? machineId) {
    if (machineId == null || machineId == _selectedMachineId) return;
    setState(() {
      _selectedMachineId = machineId;
      // Project directories are machine-specific.
      _selectedDirectory = null;
      _machine = null;
      _project = null;
    });
    unawaited(_load());
  }

  void _onDirectoryChanged(String? directory) {
    final normalized = (directory ?? '').isEmpty ? null : directory;
    if (normalized == _selectedDirectory) return;
    setState(() {
      _selectedDirectory = normalized;
      _project = null;
    });
    unawaited(_load());
  }

  /// Writes the whole policy. The grants list is authoritative on the wire, so
  /// every mutation sends the full set the user is looking at — that is what
  /// makes a revoked folder actually disappear.
  Future<void> _save({
    List<SandboxGrant>? grants,
    bool? enabled,
    bool clearEnabled = false,
  }) async {
    final machineId = _selectedMachineId;
    final directory = _selectedDirectory;
    final current = _project;
    if (machineId == null || directory == null || current == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final response = await Sync().machineSetSandboxPolicy(
      machineId: machineId,
      directory: directory,
      grants: grants ?? current.grants,
      enabled: clearEnabled ? null : (enabled ?? current.enabled),
      allowHosts: current.allowHosts,
    );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (response.success) {
        _project = response;
        _error = null;
      } else {
        _error = response.failureKind == null
            ? context.l10n.sandboxSaveFailed
            : response.failureKind.localizedRemoteFeatureFailure(context.l10n);
      }
    });
  }

  Future<void> _addFolder() async {
    final grant = await showDialog<SandboxGrant>(
      context: context,
      builder: (context) => const _AddFolderDialog(),
    );
    if (grant == null) return;
    final current = _project;
    if (current == null) return;
    final grants = [...current.grants.where((g) => g.path != grant.path), grant]
      ..sort((a, b) => a.path.compareTo(b.path));
    await _save(grants: grants);
  }

  Future<void> _removeFolder(SandboxGrant grant) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.sandboxRemoveFolder,
      content: l10n.sandboxRemoveFolderConfirm(grant.path),
      isDestructive: true,
    );
    if (!confirmed) return;
    final current = _project;
    if (current == null) return;
    await _save(
      grants: current.grants.where((g) => g.path != grant.path).toList(),
    );
  }

  Future<void> _setMode(SandboxGrant grant, SandboxGrantMode mode) async {
    final current = _project;
    if (current == null) return;
    await _save(
      grants: current.grants
          .map((g) => g.path == grant.path ? g.copyWith(mode: mode) : g)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machines = ref.watch(machinesNotifierProvider);
    final machine = _machine;
    final project = _project;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sandboxTitle),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => unawaited(_load()),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.commonRefresh,
          ),
        ],
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
              sectionTitle: l10n.sandboxMachineSection,
              isMachineSelectable: (machine) =>
                  machine.metadata?.sandboxAvailable ?? false,
              unavailableReason: (machine) =>
                  machine.metadata?.sandboxReason ??
                  l10n.settingsSandboxUnavailable,
            ),
            if (_selectedMachineId == null && !_isLoading)
              AppEmptyState(
                icon: Icons.shield_outlined,
                title: l10n.sandboxUnavailableTitle,
                subtitle: l10n.settingsSandboxUnavailable,
              ),
            if (machine != null) ...[
              _StatusCard(machine: machine),
              _DirectoryPicker(
                projects: machine.projects.map((p) => p.directory).toList(),
                selected: _selectedDirectory,
                onChanged: _onDirectoryChanged,
              ),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                child: AppLoadingIndicator(),
              )
            else if (_error != null && project == null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppErrorState(
                  message: _error!,
                  onRetry: () => unawaited(_load()),
                ),
              )
            else if (project != null)
              ..._buildProjectBody(context, project),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProjectBody(
    BuildContext context,
    SandboxPolicyResponse project,
  ) {
    final l10n = context.l10n;
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
      SettingsSection(
        title: l10n.sandboxProjectSection,
        children: [
          SwitchListTile(
            value: project.effectiveEnabled,
            onChanged: _isSaving
                ? null
                : (value) => unawaited(_save(enabled: value)),
            title: Text(l10n.sandboxEnabledForProject),
            subtitle: Text(
              project.enabled == null
                  ? l10n.sandboxFollowsMachine
                  : l10n.sandboxExplainer,
            ),
            isThreeLine: project.enabled != null,
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.sandboxFoldersSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: _isSaving ? null : () => unawaited(_addFolder()),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(l10n.sandboxAddFolder),
            ),
          ],
        ),
      ),
      if (project.grants.isEmpty)
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.folder_off_outlined,
            title: l10n.sandboxNoFolders,
            subtitle: l10n.sandboxNoFoldersSubtitle,
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final grant in project.grants)
                  _GrantRow(
                    grant: grant,
                    busy: _isSaving,
                    onModeChanged: (mode) => unawaited(_setMode(grant, mode)),
                    onRemove: () => unawaited(_removeFolder(grant)),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// What the machine itself can do. A machine without boxy runs sessions
/// unsandboxed whatever the policy says, and saying so is more useful than
/// offering switches with no effect.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.machine});

  final SandboxPolicyResponse machine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!machine.available) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        child: _NoticeCard(
          icon: Icons.gpp_maybe_outlined,
          message: machine.reason == null
              ? l10n.sandboxUnavailableTitle
              : '${l10n.sandboxUnavailableTitle} — ${machine.reason}',
        ),
      );
    }
    if (!machine.machineEnabled) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        child: _NoticeCard(
          icon: Icons.lock_open_outlined,
          message: l10n.sandboxMachineDisabled,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: _NoticeCard(
        icon: Icons.shield_outlined,
        message: '${l10n.sandboxExplainer}\n${_networkLine(context)}',
      ),
    );
  }

  String _networkLine(BuildContext context) {
    final l10n = context.l10n;
    return switch (machine.network) {
      'allowlist' => l10n.sandboxNetworkAllowlist,
      'none' => l10n.sandboxNetworkNone,
      _ => l10n.sandboxNetworkPublic,
    };
  }
}

class _DirectoryPicker extends StatelessWidget {
  const _DirectoryPicker({
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
    // A directory the daemon does not list yet (one being configured for the
    // first time) still has to render, or the dropdown value has no item.
    final options = <String>{...projects, ?selected}.toList()..sort();

    return SettingsSection(
      title: l10n.sandboxProjectSection,
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
            ),
            items: [
              const DropdownMenuItem<String>(value: '', child: Text('—')),
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

class _GrantRow extends StatelessWidget {
  const _GrantRow({
    required this.grant,
    required this.busy,
    required this.onModeChanged,
    required this.onRemove,
  });

  final SandboxGrant grant;
  final bool busy;
  final ValueChanged<SandboxGrantMode> onModeChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final readOnly = grant.mode == SandboxGrantMode.readOnly;
    return ListTile(
      leading: Icon(readOnly ? Icons.folder_outlined : Icons.folder_open),
      title: Text(grant.path, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        readOnly ? l10n.sandboxModeReadOnly : l10n.sandboxModeReadWrite,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: !readOnly,
            onChanged: busy
                ? null
                : (value) => onModeChanged(
                    value
                        ? SandboxGrantMode.readWrite
                        : SandboxGrantMode.readOnly,
                  ),
          ),
          IconButton(
            tooltip: l10n.sandboxRemoveFolder,
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _AddFolderDialog extends StatefulWidget {
  const _AddFolderDialog();

  @override
  State<_AddFolderDialog> createState() => _AddFolderDialogState();
}

class _AddFolderDialogState extends State<_AddFolderDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  SandboxGrantMode _mode = SandboxGrantMode.readWrite;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sandboxAddFolder),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.sandboxFolderPath,
                hintText: l10n.sandboxFolderPathHint,
              ),
              // The daemon rejects a relative path too, but catching it here
              // saves a round trip and names the rule where it is broken.
              validator: (value) {
                final path = (value ?? '').trim();
                if (!path.startsWith('/'))
                  return l10n.sandboxFolderPathRequired;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<SandboxGrantMode>(
              segments: [
                ButtonSegment(
                  value: SandboxGrantMode.readWrite,
                  label: Text(l10n.sandboxModeReadWrite),
                ),
                ButtonSegment(
                  value: SandboxGrantMode.readOnly,
                  label: Text(l10n.sandboxModeReadOnly),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
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
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(
              context,
            ).pop(SandboxGrant(path: _controller.text.trim(), mode: _mode));
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
