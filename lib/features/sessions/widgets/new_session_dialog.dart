import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/built_in_profiles.dart';
import '../../../core/models/machine.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/draft_storage.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

enum NewSessionCreateBlocker {
  missingMachine,
  offlineMachine,
  missingPath,
  creating,
  disconnected,
  syncNotReady,
}

const _agentIds = ['claude', 'codex', 'gemini', 'pi', 'opencode'];

NewSessionCreateBlocker? newSessionCreateBlocker({
  required Machine? machine,
  required bool machineOnline,
  required String path,
  required bool isCreating,
  required ConnectionStatus connectionStatus,
  required bool syncInitialized,
}) {
  if (machine == null) return NewSessionCreateBlocker.missingMachine;
  if (!machineOnline) return NewSessionCreateBlocker.offlineMachine;
  if (path.trim().isEmpty) return NewSessionCreateBlocker.missingPath;
  if (isCreating) return NewSessionCreateBlocker.creating;
  if (connectionStatus != ConnectionStatus.connected) {
    return NewSessionCreateBlocker.disconnected;
  }
  return syncInitialized ? null : NewSessionCreateBlocker.syncNotReady;
}

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
  String? _selectedSpawnBackend;
  bool _spawnBackendTouched = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    final lastUsedAgent = settings.lastUsedAgent;
    _selectedAgent = _agentIds.contains(lastUsedAgent)
        ? lastUsedAgent!
        : 'claude';
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
    // Sort machines: online first, then offline. Show all so users can see
    // (and understand) which machines are unavailable rather than silently
    // hiding them.
    bool isMachineOnline(Machine m) =>
        m.active && now - m.activeAt < onlineThresholdMs;
    final machines = allMachines.values.toList()
      ..sort((a, b) {
        final aOnline = isMachineOnline(a) ? 0 : 1;
        final bOnline = isMachineOnline(b) ? 0 : 1;
        if (aOnline != bOnline) return aOnline.compareTo(bOnline);
        final aName =
            a.metadata?.displayName ?? a.metadata?.host ?? a.id;
        final bName =
            b.metadata?.displayName ?? b.metadata?.host ?? b.id;
        return aName.compareTo(bName);
      });

    // Check whether the currently selected machine is still online.
    final selectedMachineObj = _selectedMachine != null
        ? allMachines[_selectedMachine]
        : null;
    final spawnBackends = _spawnBackendsForMachine(selectedMachineObj);
    final selectedSpawnBackend = _spawnBackendTouched
        ? _selectedSpawnBackendForMachine(
            selectedMachineObj,
            _selectedSpawnBackend,
          )
        : _defaultSpawnBackendForMachine(selectedMachineObj);
    final selectedMachineOffline =
        selectedMachineObj != null && !isMachineOnline(selectedMachineObj);
    final createBlocker = newSessionCreateBlocker(
      machine: selectedMachineObj,
      machineOnline: selectedMachineObj != null && !selectedMachineOffline,
      path: _selectedPath ?? '',
      isCreating: _isCreating,
      connectionStatus: connectionStatus,
      syncInitialized: sync.isInitialized,
    );
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
                ...machines.map((machine) {
                  final online = isMachineOnline(machine);
                  // Disable offline items so the user cannot select a
                  // machine that will fail at session creation time.
                  return DropdownMenuItem(
                    value: machine.id,
                    enabled: online,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppStatusDot(
                          color: online
                              ? AppColors.success
                              : cs.onSurfaceVariant,
                          size: 8,
                          semanticLabel: online
                              ? l10n.machineOnline
                              : l10n.machineOffline,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            machine.metadata?.displayName ??
                                machine.metadata?.host ??
                                machine.id,
                            overflow: TextOverflow.ellipsis,
                            style: online
                                ? null
                                : theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                          ),
                        ),
                        if (!online) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(
                                AppRadius.xs,
                              ),
                            ),
                            child: Text(
                              l10n.machineOffline,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                // Guard against selecting an offline machine even if a
                // disabled DropdownMenuItem is somehow tapped.
                if (value != null) {
                  final m = allMachines[value];
                  if (m != null && !isMachineOnline(m)) {
                    return;
                  }
                }
                setState(() {
                  if (_selectedMachine != value) {
                    _selectedPath = null;
                    _selectedSpawnBackend = _defaultSpawnBackendForMachine(
                      allMachines[value],
                    );
                    _spawnBackendTouched = false;
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
          if (spawnBackends.length > 1) ...[
            _SpawnBackendPicker(
              backends: spawnBackends,
              selectedBackend: selectedSpawnBackend,
              onSelected: (backend) {
                setState(() {
                  _selectedSpawnBackend = backend;
                  _spawnBackendTouched = true;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _AgentPicker(
            selectedAgent: _selectedAgent,
            onSelected: (agent) => setState(() => _selectedAgent = agent),
          ),
          if (createBlocker != null) ...[
            const SizedBox(height: AppSpacing.md),
            _DialogRequirementStatus(
              blocker: createBlocker,
              selectedMachineOffline: selectedMachineOffline,
            ),
            if (selectedMachineOffline ||
                createBlocker == NewSessionCreateBlocker.offlineMachine) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xl),
                child: Text(
                  l10n.machineOfflineHelp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
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
        _CreateButton(
          isCreating: _isCreating,
          onPressed: createBlocker == null
              ? () => _createSession(context)
              : null,
          label: l10n.commonCreate,
          tooltip: createBlocker == null
              ? null
              : _dialogRequirementText(l10n, createBlocker),
        ),
      ],
    );
  }

  Future<void> _createSession(BuildContext context) async {
    final l10n = context.l10n;
    final machineId = _selectedMachine;
    final path = _selectedPath?.trim();
    if (machineId == null || path == null || path.isEmpty) {
      return;
    }
    final machine = ref.read(machinesNotifierProvider)[machineId];
    final spawnBackend = _spawnBackendRequestValueForMachine(
      machine,
      _spawnBackendTouched
          ? _selectedSpawnBackend
          : _defaultSpawnBackendForMachine(machine),
    );
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
      await ref.read(settingsNotifierProvider.notifier).applySettings({
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
      final sessionsNotifier = ref.read(sessionsNotifierProvider.notifier);
      if (_sessionType == 'worktree') {
        sessionPath = await sessionsNotifier.createWorktree(
          machineId: machineId,
          basePath: path,
        );
      } else {
        sessionPath = path;
      }
      final sessionId = await sessionsNotifier.createSession(
        machineId: machineId,
        path: sessionPath,
        agent: _selectedAgent,
        profileId: profileId,
        modelMode: modelMode,
        spawnBackend: spawnBackend,
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
    } on IncompatibleProviderAndModelError catch (e, st) {
      logger.warning(
        '[NewSessionDialog] incompatible provider/model: $e',
        e,
        st,
      );
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createError = e.message;
      });
    } catch (e, st) {
      logger.warning('[NewSessionDialog] createSession failed: $e', e, st);
      if (!mounted) return;
      final errorText = e.toString();
      String userMessage;
      if (errorText.contains('Machine is unreachable') ||
          errorText.contains('Machine is offline')) {
        userMessage = l10n.newSessionMachineUnreachable;
      } else {
        userMessage = l10n.newSessionCouldNotStartSession;
      }
      setState(() {
        _isCreating = false;
        _createError = userMessage;
      });
    }
  }
}

List<String> _spawnBackendsForMachine(Machine? machine) {
  final advertised = machine?.metadata?.spawnBackends ?? const <String>[];
  final supported = advertised
      .where((backend) => backend == 'local' || backend == 'kubernetes')
      .toList(growable: false);
  return supported.isEmpty ? const ['local'] : supported;
}

String _defaultSpawnBackendForMachine(Machine? machine) {
  final backends = _spawnBackendsForMachine(machine);
  final advertisedDefault = machine?.metadata?.defaultSpawnBackend;
  return backends.contains(advertisedDefault)
      ? advertisedDefault!
      : backends.first;
}

String _selectedSpawnBackendForMachine(Machine? machine, String? selected) {
  final backends = _spawnBackendsForMachine(machine);
  return backends.contains(selected)
      ? selected!
      : _defaultSpawnBackendForMachine(machine);
}

String? _spawnBackendRequestValueForMachine(
  Machine? machine,
  String? selected,
) {
  final advertised = machine?.metadata?.spawnBackends;
  if (advertised == null || advertised.isEmpty) return null;
  return _selectedSpawnBackendForMachine(machine, selected);
}

String _spawnBackendLabel(String backend) {
  switch (backend) {
    case 'kubernetes':
      return 'Kubernetes';
    case 'local':
    default:
      return 'Local';
  }
}

IconData _spawnBackendIcon(String backend) {
  switch (backend) {
    case 'kubernetes':
      return Icons.cloud_queue_outlined;
    case 'local':
    default:
      return Icons.computer_outlined;
  }
}

class _SpawnBackendPicker extends StatelessWidget {
  const _SpawnBackendPicker({
    required this.backends,
    required this.selectedBackend,
    required this.onSelected,
  });

  final List<String> backends;
  final String selectedBackend;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spawn on',
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          segments: backends
              .map(
                (backend) => ButtonSegment(
                  value: backend,
                  label: Text(_spawnBackendLabel(backend)),
                  icon: Icon(_spawnBackendIcon(backend)),
                ),
              )
              .toList(growable: false),
          selected: {selectedBackend},
          onSelectionChanged: (selection) => onSelected(selection.first),
        ),
      ],
    );
  }
}

class _AgentPicker extends StatelessWidget {
  const _AgentPicker({required this.selectedAgent, required this.onSelected});

  final String selectedAgent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sessionsAgent,
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: _agentIds
              .map((agent) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: agent == _agentIds.last ? 0 : AppSpacing.sm,
                    ),
                    child: _AgentOption(
                      label: _agentLabel(l10n, agent),
                      icon: _agentIcon(agent),
                      selected: agent == selectedAgent,
                      onTap: () => onSelected(agent),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _AgentOption extends StatelessWidget {
  const _AgentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final borderColor = selected ? cs.primary : cs.outlineVariant;
    final iconColor = selected ? cs.primary : cs.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer.withValues(alpha: AppOpacity.subtle)
                : cs.surface,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontSize: AppFontSize.xs,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

String _agentLabel(AppLocalizations l10n, String agent) {
  return switch (agent) {
    'codex' => l10n.sessionsCodex,
    'gemini' => l10n.sessionsGemini,
    'pi' => l10n.sessionsPi,
    'opencode' => l10n.sessionsOpencode,
    _ => l10n.sessionsClaude,
  };
}

IconData _agentIcon(String agent) {
  return switch (agent) {
    'codex' => Icons.terminal_rounded,
    'gemini' => Icons.auto_awesome_rounded,
    'pi' => Icons.memory_rounded,
    'opencode' => Icons.code_rounded,
    _ => Icons.psychology_alt_rounded,
  };
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.isCreating,
    required this.onPressed,
    required this.label,
    required this.tooltip,
  });

  final bool isCreating;
  final VoidCallback? onPressed;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      child: isCreating
          ? const SizedBox(
              width: AppSpacing.lg,
              height: AppSpacing.lg,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
    final tip = tooltip;
    if (tip == null || tip.isEmpty) return button;
    return Tooltip(message: tip, child: button);
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
