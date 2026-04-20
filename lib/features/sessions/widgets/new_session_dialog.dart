import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/built_in_profiles.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/draft_storage.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_tokens.dart';

/// New session dialog.
class NewSessionDialog extends ConsumerStatefulWidget {
  const NewSessionDialog({
    super.key,
    this.initialMachineId,
    this.initialPath,
  });

  /// Optional pre-selected machine ID.
  final String? initialMachineId;

  /// Optional pre-selected path.
  final String? initialPath;

  @override
  ConsumerState<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends ConsumerState<NewSessionDialog> {
  String? _selectedPath;
  String? _selectedMachine;
  bool _isCreating = false;
  String? _createError;
  String _selectedAgent = 'claude';
  String _sessionType = 'simple';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _selectedAgent = settings.lastUsedAgent ?? 'claude';
    _selectedMachine = widget.initialMachineId;
    _selectedPath = widget.initialPath;
    Future<void>.microtask(
      () => ref.read(machinesNotifierProvider.notifier).refreshFromSync(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    const onlineThresholdMs = 120 * 1000;
    final allMachines = ref.watch(machinesNotifierProvider);
    final machines = allMachines.values
        .where((m) => m.active && now - m.activeAt < onlineThresholdMs)
        .toList();

    // Check whether the currently selected machine is still online.
    final selectedMachineObj = _selectedMachine != null
        ? allMachines[_selectedMachine]
        : null;
    final selectedMachineOffline = selectedMachineObj != null &&
        (now - selectedMachineObj.activeAt >= onlineThresholdMs ||
            !selectedMachineObj.active);

    return AlertDialog(
      title: Text(l10n.newSessionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (machines.isEmpty)
            Text(l10n.newSessionNoMachinesFound)
          else
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: l10n.sessionMachine),
              initialValue: _selectedMachine,
              isExpanded: true,
              selectedItemBuilder: (context) => [
                Text(
                  l10n.sessionSelectMachine,
                  overflow: TextOverflow.ellipsis,
                ),
                ...machines.map(
                  (machine) => Text(
                    machine.metadata?.displayName ??
                        machine.metadata?.host ??
                        machine.id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.sessionSelectMachine),
                ),
                ...machines.map(
                  (machine) => DropdownMenuItem(
                    value: machine.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.computer,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            machine.metadata?.displayName ??
                                machine.metadata?.host ??
                                machine.id,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMachine = value;
                });
              },
            ),
          const SizedBox(height: AppSpacing.lg),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (_selectedMachine == null) return const [];
              final sessions = ref.read(sessionsNotifierProvider);
              final paths = sessions.values
                  .where((s) => s.metadata?.machineId == _selectedMachine)
                  .map((s) => s.metadata?.path)
                  .whereType<String>()
                  .toSet()
                  .toList();
              if (textEditingValue.text.isEmpty) {
                return paths;
              }
              return paths.where(
                (p) => p.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                ),
              );
            },
            onSelected: (value) {
              setState(() => _selectedPath = value);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  // Pre-fill the path if provided via initialPath.
                  if (_selectedPath != null && controller.text.isEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && controller.text.isEmpty) {
                        controller.text = _selectedPath!;
                      }
                    });
                  }
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: l10n.sessionPath,
                      hintText: l10n.sessionPathHint,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedPath = value;
                        _createError = null;
                      });
                    },
                  );
                },
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'simple',
                label: Text(l10n.sessionsSimple),
                icon: const Icon(Icons.folder_outlined),
              ),
              ButtonSegment(
                value: 'worktree',
                label: Text(l10n.sessionsWorktree),
                icon: const Icon(Icons.account_tree_outlined),
              ),
            ],
            selected: {_sessionType},
            onSelectionChanged: (selection) {
              setState(() => _sessionType = selection.first);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'claude', label: Text(l10n.sessionsClaude)),
              ButtonSegment(value: 'codex', label: Text(l10n.sessionsCodex)),
              ButtonSegment(value: 'gemini', label: Text(l10n.sessionsGemini)),
            ],
            selected: {_selectedAgent},
            onSelectionChanged: (selection) {
              setState(() => _selectedAgent = selection.first);
            },
          ),
          if (selectedMachineOffline) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              // TODO(i18n): add to ARB files when l10n pipeline is updated
              'Selected machine is offline',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (_createError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _createError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed:
              !_isCreating &&
                  (_selectedPath?.isNotEmpty ?? false) &&
                  _selectedMachine != null &&
                  !selectedMachineOffline &&
                  connectionStatus == ConnectionStatus.connected &&
                  sync.isInitialized
              ? () => _createSession(context)
              : null,
          child: _isCreating
              ? const SizedBox(
                  width: AppSpacing.lg,
                  height: AppSpacing.lg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonCreate),
        ),
      ],
    );
  }

  Future<void> _createSession(BuildContext context) async {
    final machineId = _selectedMachine;
    final path = _selectedPath?.trim();
    if (machineId == null || path == null || path.isEmpty) {
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() {
      _isCreating = true;
      _createError = null;
    });

    try {
      final settings = ref.read(settingsNotifierProvider);
      final profileId = settings.lastUsedProfile;
      // Resolve defaultModelMode so the daemon always receives a model hint,
      // preventing profile env vars from being used incorrectly when
      // lastUsedProfile changes between profile switch and session creation.
      String? modelMode;
      if (profileId != null) {
        final profile = settings.profiles
            .where((p) => p.id == profileId)
            .firstOrNull;
        modelMode ??= profile?.defaultModelMode;
        modelMode ??= getBuiltInProfile(profileId)?.defaultModelMode;
      }
      await sync.applySettings({
        'lastUsedAgent': _selectedAgent,
        'lastUsedProfile': profileId,
      });
      final String sessionPath;
      if (_sessionType == 'worktree') {
        sessionPath = await sync.createWorktree(
          machineId: machineId,
          basePath: path,
        );
      } else {
        sessionPath = path;
      }
      final sessionId = await sync.createSession(
        machineId: machineId,
        path: sessionPath,
        profileId: profileId,
        modelMode: modelMode,
      );
      // Persist the profile so auto-restore reads correct env vars.
      if (profileId != null) {
        await DraftStorage().saveProfileId(sessionId, profileId);
      }
      // createSession() already called refreshSessions() internally
      // and added the session to sync._sessions (optimistic fallback).
      // Just read the in-memory state — no redundant server fetch.
      if (!mounted) return;
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
      if (!mounted) return;
      navigator.pop(sessionId);
    } catch (e, st) {
      logger.warning('[NewSessionDialog] createSession failed: $e', e, st);
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createError = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }
}
