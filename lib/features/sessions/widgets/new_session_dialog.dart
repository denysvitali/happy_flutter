import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/built_in_profiles.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/draft_storage.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../new_session_screen.dart';

/// New session dialog.
class NewSessionDialog extends ConsumerStatefulWidget {
  const NewSessionDialog({super.key, this.initialMachineId, this.initialPath});

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
    final selectedMachineOffline =
        selectedMachineObj != null &&
        (now - selectedMachineObj.activeAt >= onlineThresholdMs ||
            !selectedMachineObj.active);
    final createBlocker = newSessionCreateBlocker(
      machine: selectedMachineObj,
      machineOnline: selectedMachineObj != null && !selectedMachineOffline,
      path: _selectedPath ?? '',
      isCreating: _isCreating,
      connectionStatus: connectionStatus,
      syncInitialized: sync.isInitialized,
    );

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
                        AppStatusDot(
                          color: machine.active
                              ? AppColors.success
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 8,
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
                  if (_selectedMachine != value) {
                    _selectedPath = null;
                  }
                  _selectedMachine = value;
                });
              },
            ),
          const SizedBox(height: AppSpacing.lg),
          Autocomplete<String>(
            key: ValueKey(_selectedMachine),
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
              ButtonSegment(value: 'pi', label: Text(l10n.sessionsPi)),
            ],
            selected: {_selectedAgent},
            onSelectionChanged: (selection) {
              setState(() => _selectedAgent = selection.first);
            },
          ),
          if (createBlocker != null) ...[
            const SizedBox(height: AppSpacing.md),
            _DialogRequirementStatus(
              blocker: createBlocker,
              selectedMachineOffline: selectedMachineOffline,
            ),
          ],
          if (createBlocker == null) ...[
            const SizedBox(height: AppSpacing.md),
            _DialogRequirementStatus(
              blocker: null,
              selectedMachineOffline: false,
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
          onPressed: createBlocker == null
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
      final profileId = resolveSelectedProfileIdForAgent(
        settings,
        _selectedAgent,
      );
      // Resolve defaultModelMode so the daemon always receives a model hint,
      // preventing profile env vars from being used incorrectly when
      // lastUsedProfile changes between profile switch and session creation.
      // Re-read settings after applySettings so we use the current
      // lastUsedModelMode (the user's last explicit selection), not a stale
      // snapshot from initState.
      await sync.applySettings({
        'lastUsedAgent': _selectedAgent,
        'lastUsedProfile': profileId,
        'lastUsedProfilesByAgent': settings.lastUsedProfilesWithAgent(
          _selectedAgent,
          profileId,
        ),
      });
      final updatedSettings = ref.read(settingsNotifierProvider);
      String? modelMode;
      if (profileId != null) {
        final profile = updatedSettings.profiles
            .where((p) => p.id == profileId)
            .firstOrNull;
        modelMode ??= profile?.defaultModelMode;
        modelMode ??= getBuiltInProfile(profileId)?.defaultModelMode;
      }
      // Fall back to the user's last explicit model selection so profile
      // switches don't regress the model choice.
      modelMode ??= updatedSettings.lastUsedModelMode;
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

class _DialogRequirementStatus extends StatelessWidget {
  const _DialogRequirementStatus({
    required this.blocker,
    required this.selectedMachineOffline,
  });

  final NewSessionCreateBlocker? blocker;
  final bool selectedMachineOffline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isBlocked = blocker != null;
    final color =
        selectedMachineOffline ||
            blocker == NewSessionCreateBlocker.offlineMachine
        ? cs.error
        : isBlocked
        ? cs.onSurfaceVariant
        : AppColors.success;
    final icon = isBlocked
        ? selectedMachineOffline ||
                  blocker == NewSessionCreateBlocker.offlineMachine
              ? Icons.cloud_off_rounded
              : Icons.info_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            _dialogRequirementText(l10n, blocker),
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

String _dialogRequirementText(
  AppLocalizations l10n,
  NewSessionCreateBlocker? blocker,
) {
  switch (blocker) {
    case NewSessionCreateBlocker.missingMachine:
      return l10n.sessionNoMachineSelected;
    case NewSessionCreateBlocker.offlineMachine:
      return l10n.machineOfflineUnableToSpawn;
    case NewSessionCreateBlocker.missingPath:
      return l10n.sessionNoPathSelected;
    case NewSessionCreateBlocker.creating:
      return l10n.commonCreate;
    case NewSessionCreateBlocker.disconnected:
      return l10n.sessionNotConnectedToServer;
    case NewSessionCreateBlocker.syncNotReady:
      return l10n.authConnecting;
    case null:
      return l10n.statusConnected('');
  }
}
