import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/built_in_profiles.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/models/settings.dart' show AIBackendProfile;
import '../../../core/providers/app_providers.dart';
import '../../../core/services/draft_storage.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../chat/model_selection_resolver.dart'
    show profileOwnsRawCodexModel, profileUsesThirdPartyAnthropicBaseUrl;
import '../../chat/widgets/model_mode.dart';

enum NewSessionCreateBlocker {
  missingMachine,
  offlineMachine,
  missingPath,
  kubernetesUnavailable,
  missingRepository,
  missingRepositoryRef,
  creating,
  disconnected,
  syncNotReady,
}

const _agentIds = ['claude', 'codex', 'gemini', 'pi', 'opencode', 'grok'];

NewSessionCreateBlocker? newSessionCreateBlocker({
  required Machine? machine,
  required bool machineOnline,
  required bool isCreating,
  required ConnectionStatus connectionStatus,
  required bool syncInitialized,
  String repositoryUrl = '',
  String repositoryRef = '',
  String? path,
  bool repositoryRequired = false,
  bool enforceKubernetes = false,
}) {
  if (machine == null) return NewSessionCreateBlocker.missingMachine;
  if (!machineOnline) return NewSessionCreateBlocker.offlineMachine;
  if (path != null && path.trim().isEmpty) {
    return NewSessionCreateBlocker.missingPath;
  }
  if (enforceKubernetes && !_machineSupportsKubernetes(machine)) {
    return NewSessionCreateBlocker.kubernetesUnavailable;
  }
  if ((enforceKubernetes || repositoryRequired) &&
      repositoryUrl.trim().isEmpty) {
    return NewSessionCreateBlocker.missingRepository;
  }
  if (enforceKubernetes && repositoryRef.trim().isEmpty) {
    return NewSessionCreateBlocker.missingRepositoryRef;
  }
  if (isCreating) return NewSessionCreateBlocker.creating;
  if (connectionStatus != ConnectionStatus.connected) {
    return NewSessionCreateBlocker.disconnected;
  }
  return syncInitialized ? null : NewSessionCreateBlocker.syncNotReady;
}

String newSessionCreateErrorMessage({
  required AppLocalizations l10n,
  required Object error,
}) {
  final errorText = error is StateError ? error.message : error.toString();
  if (errorText.contains('Machine is unreachable') ||
      errorText.contains('Machine is offline')) {
    return l10n.newSessionMachineUnreachable;
  }
  if (errorText.contains('deadline exceeded') ||
      errorText.contains('context deadline')) {
    // Daemon-side timeouts (e.g. spawn-happy-session RPC context deadline)
    // are transient and already logged; show a generic user-facing message
    // instead of the raw technical error string.
    return l10n.newSessionCouldNotStartSession;
  }
  if (errorText.contains('unknown agent') ||
      errorText.contains('daemon too old') ||
      errorText.contains('daemon outdated')) {
    return l10n.newSessionDaemonOutdated;
  }
  return l10n.newSessionCouldNotStartSession;
}

/// Opens a new-session dialog with one explicit dismissal control.
///
/// The modal barrier is intentionally not dismissible: once creation starts,
/// [NewSessionDialog] disables Cancel and blocks system back until the async
/// operation has either succeeded or returned an error.
Future<String?> showNewSessionDialog(
  BuildContext context, {
  String? initialMachineId,
  String? initialPath,
  String? initialRepositoryUrl,
  String? initialRepositoryRef,
  bool useRootNavigator = true,
}) {
  return showDialog<String>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: false,
    builder: (_) => NewSessionDialog(
      initialMachineId: initialMachineId,
      initialPath: initialPath,
      initialRepositoryUrl: initialRepositoryUrl,
      initialRepositoryRef: initialRepositoryRef,
    ),
  );
}

/// New session dialog.
class NewSessionDialog extends ConsumerStatefulWidget {
  const NewSessionDialog({
    super.key,
    this.initialMachineId,
    this.initialPath,
    this.initialRepositoryUrl,
    this.initialRepositoryRef,
  });

  /// Optional pre-selected machine ID.
  final String? initialMachineId;

  /// Optional pre-selected path.
  final String? initialPath;
  final String? initialRepositoryUrl;
  final String? initialRepositoryRef;

  @override
  ConsumerState<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends ConsumerState<NewSessionDialog> {
  String? _selectedPath;
  String? _selectedRepoUrl;
  String _selectedRepoRef = 'main';
  String? _selectedMachine;
  bool _isCreating = false;
  String? _creationPhase;
  String? _createError;
  String _selectedAgent = 'claude';
  String _sessionType = 'simple';
  String? _selectedSpawnBackend;
  bool _spawnBackendTouched = false;

  /// Whether Riverpod's [ref] (and `setState`) may still be touched.
  ///
  /// `State.mounted` only flips to `false` once `dispose()` has run, but a
  /// `ConsumerState`'s `ref` starts throwing as soon as its *element* is
  /// deactivated — the window a dismissed dialog spends between
  /// `Navigator.pop` and the end of the frame. Production landed exactly in
  /// that window: `[NewSessionDialog] createSession failed: Bad state: Using
  /// "ref" when a widget is about to or has been unmounted is unsafe`.
  /// `context.mounted` reads the element lifecycle, so it closes the gap that
  /// a bare `mounted` check leaves open. Every post-await `ref`/`setState`
  /// touch in this state goes through here.
  bool get _canUseRef => mounted && context.mounted;

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
    _selectedRepoUrl = widget.initialRepositoryUrl;
    _selectedRepoRef = widget.initialRepositoryRef ?? 'main';
    Future<void>.microtask(_refreshMachinesAndResolveSelection);
  }

  Future<void> _refreshMachinesAndResolveSelection() async {
    if (!_canUseRef) return;
    final machinesNotifier = ref.read(machinesNotifierProvider.notifier);
    await machinesNotifier.refreshFromSync();
    if (!_canUseRef) return;

    final resolved = resolveAvailableMachineId(
      _selectedMachine,
      ref.read(machinesNotifierProvider),
    );
    if (resolved == _selectedMachine) return;

    setState(() {
      _selectedMachine = resolved;
      _createError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final allMachines = ref.watch(machinesNotifierProvider);
    // Sort machines: online first, then offline. Show all so users can see
    // (and understand) which machines are unavailable rather than silently
    // hiding them.
    final machineSortNow = DateTime.now().millisecondsSinceEpoch;
    final machines = allMachines.values.toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(machineSortNow, a, b));

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
    final isKubernetes = selectedSpawnBackend == 'kubernetes';
    final selectedMachineOffline =
        selectedMachineObj != null &&
        !selectedMachineObj.isOnlineAt(machineSortNow);
    final createBlocker = newSessionCreateBlocker(
      machine: selectedMachineObj,
      machineOnline: selectedMachineObj != null && !selectedMachineOffline,
      isCreating: _isCreating,
      connectionStatus: connectionStatus,
      syncInitialized: sync.isInitialized,
      repositoryUrl: _selectedRepoUrl ?? '',
      repositoryRef: _selectedRepoRef,
      path: isKubernetes ? null : (_selectedPath ?? ''),
      enforceKubernetes: isKubernetes,
    );
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: !_isCreating,
      child: AlertDialog(
        title: Text(l10n.newSessionTitle),
        content: SingleChildScrollView(
          child: Column(
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
                        machine.displayLabel,
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
                      final online = machine.isOnlineAt(machineSortNow);
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
                                machine.displayLabel,
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
                      if (m != null && !m.isOnlineAt(machineSortNow)) {
                        return;
                      }
                    }
                    setState(() {
                      if (_selectedMachine != value) {
                        _selectedPath = null;
                        _selectedRepoUrl = null;
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
              if (!isKubernetes) ...[
                _PathField(
                  machineId: _selectedMachine,
                  selectedPath: _selectedPath,
                  onChanged: (value) => setState(() {
                    _selectedPath = value;
                    _createError = null;
                  }),
                  onSelected: (value) => setState(() {
                    _selectedPath = value;
                    _createError = null;
                  }),
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
                  onSelectionChanged: (selection) =>
                      setState(() => _sessionType = selection.first),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (spawnBackends.length > 1) ...[
                _SpawnBackendPicker(
                  backends: spawnBackends,
                  selectedBackend: selectedSpawnBackend,
                  onSelected: (backend) => setState(() {
                    _selectedSpawnBackend = backend;
                    _spawnBackendTouched = true;
                    _createError = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (isKubernetes) ...[
                _RepositoryUrlField(
                  machineId: _selectedMachine,
                  selectedRepoUrl: _selectedRepoUrl,
                  onChanged: (value) {
                    setState(() {
                      _selectedRepoUrl = value;
                      _createError = null;
                    });
                  },
                  onSelected: (value) {
                    setState(() {
                      _selectedRepoUrl = value;
                      _createError = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  initialValue: _selectedRepoRef,
                  decoration: InputDecoration(
                    labelText: l10n.newSessionGitRef,
                    hintText: l10n.newSessionGitRefHint,
                    prefixIcon: const Icon(Icons.account_tree_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (value) => setState(() {
                    _selectedRepoRef = value;
                    _createError = null;
                  }),
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
                    createBlocker ==
                        NewSessionCreateBlocker.offlineMachine) ...[
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
              if (_isCreating && _creationPhase != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: AppSpacing.lg,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(_creationPhase!)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : () => Navigator.pop(context),
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
      ),
    );
  }

  Future<void> _createSession(BuildContext context) async {
    final l10n = context.l10n;
    final selectedMachineId = _selectedMachine;
    if (selectedMachineId == null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (!_canUseRef) return;
    // Resolve every notifier up-front, while `ref` is provably usable. Each
    // one is a stable object, so holding it across the awaits below removes
    // three `ref` touches from the async tail entirely.
    final machinesNotifier = ref.read(machinesNotifierProvider.notifier);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
    final sessionsNotifier = ref.read(sessionsNotifierProvider.notifier);

    setState(() {
      _isCreating = true;
      _creationPhase = l10n.newSessionPhaseCheckingMachine;
      _createError = null;
    });

    try {
      // The dialog may have been open while the daemon disconnected. Refresh
      // authoritative presence immediately before doing any settings,
      // worktree, or spawn work, then migrate stale registrations for the
      // same host when a newer online daemon registration exists.
      await machinesNotifier.refreshFromSync();
      if (!_canUseRef) return;
      final machines = ref.read(machinesNotifierProvider);
      final availableMachineId = resolveAvailableMachineId(
        selectedMachineId,
        machines,
      );
      if (availableMachineId == null) {
        throw StateError('Machine is offline');
      }
      final machineId = await resolveReachableMachineId(
        availableMachineId,
        machines,
        probe: sync.ensureMachineReachable,
      );
      if (!_canUseRef) return;
      final machine = machines[machineId];
      final now = DateTime.now().millisecondsSinceEpoch;
      if (machine == null || !machine.isOnlineAt(now)) {
        throw StateError('Machine is offline');
      }
      if (machineId != _selectedMachine) {
        setState(() => _selectedMachine = machineId);
      }
      final spawnBackend = _spawnBackendRequestValueForMachine(
        machine,
        _spawnBackendTouched
            ? _selectedSpawnBackend
            : _defaultSpawnBackendForMachine(machine),
      );
      final isKubernetes = spawnBackend == 'kubernetes';
      if (isKubernetes && !_machineSupportsKubernetes(machine)) {
        throw StateError('Kubernetes spawning is unavailable');
      }
      final repoUrl = isKubernetes ? _selectedRepoUrl?.trim() : null;
      final repoRef = isKubernetes ? _selectedRepoRef.trim() : null;
      if (isKubernetes &&
          (repoUrl == null ||
              repoUrl.isEmpty ||
              repoRef == null ||
              repoRef.isEmpty)) {
        throw StateError('Repository and branch/ref are required');
      }
      final localPath = _selectedPath?.trim();
      if (!isKubernetes && (localPath == null || localPath.isEmpty)) {
        throw StateError('Path is required');
      }

      setState(() {
        _creationPhase = l10n.newSessionPhaseSavingPreferences;
      });

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
      await settingsNotifier.applySettings({
        'lastUsedAgent': _selectedAgent,
        'lastUsedProfile': profileId,
        'lastUsedProfilesByAgent': settings.lastUsedProfilesWithAgent(
          _selectedAgent,
          profileId,
        ),
      });
      if (!_canUseRef) return;
      final updatedSettings = ref.read(settingsNotifierProvider);
      String? modelMode;
      AIBackendProfile? selectedProfile;
      if (profileId != null) {
        selectedProfile = updatedSettings.profiles
            .where((p) => p.id == profileId)
            .firstOrNull;
        selectedProfile ??= getBuiltInProfile(profileId);
        modelMode ??= selectedProfile?.defaultModelMode;
      }
      // Fall back to the user's last explicit model selection so profile
      // switches don't regress the model choice — but never re-apply a
      // Claude model onto a third-party Anthropic-compatible gateway
      // (Grok proxy / MiniMax / etc.), which the daemon aborts as
      // provider_model_mismatch.
      final lastUsedModelMode = updatedSettings.lastUsedModelMode;
      if (lastUsedModelMode != null) {
        final candidate = ChatModelMode.normalizeRawForFlavor(
          lastUsedModelMode,
          _selectedAgent,
          preserveProviderOwned:
              (_selectedAgent == 'codex' &&
                  profileOwnsRawCodexModel(selectedProfile)) ||
              (_selectedAgent == 'claude' &&
                  profileUsesThirdPartyAnthropicBaseUrl(selectedProfile)),
          allowedRawModels: selectedProfile?.models,
        );
        final thirdParty =
            _selectedAgent == 'claude' &&
            profileUsesThirdPartyAnthropicBaseUrl(selectedProfile);
        final claudeCandidate = _isClaudeModelAliasForDialog(candidate);
        if (!(thirdParty && claudeCandidate)) {
          modelMode ??= candidate;
        }
      }
      if (!_canUseRef) return;
      final String sessionPath;
      if (isKubernetes) {
        sessionPath = kubernetesCheckoutPath(machine, repoUrl!);
      } else if (_sessionType == 'worktree') {
        setState(() {
          _creationPhase = l10n.newSessionPhasePreparingWorktree;
        });
        sessionPath = await sessionsNotifier.createWorktree(
          machineId: machineId,
          basePath: localPath!,
        );
      } else {
        sessionPath = localPath!;
      }
      if (!_canUseRef) return;
      setState(() {
        _creationPhase = isKubernetes
            ? l10n.newSessionPhaseSchedulingContainer
            : l10n.newSessionPhaseStartingAgent;
      });
      final sessionId = await sessionsNotifier.createSession(
        machineId: machineId,
        path: sessionPath,
        agent: _selectedAgent,
        profileId: profileId,
        modelMode: modelMode,
        spawnBackend: spawnBackend,
        repoUrl: repoUrl,
        repoRef: repoRef,
      );
      if (!_canUseRef) return;
      setState(() {
        _creationPhase = l10n.newSessionPhaseFinalizing;
      });
      // Persist the profile so auto-restore reads correct env vars.
      if (profileId != null) {
        await DraftStorage().saveProfileId(sessionId, profileId);
      }
      // Keep the model selected for this session separate from the global
      // last-used model. Without this, reopening a session after choosing a
      // model for another session could make the picker select that newer
      // global choice and unnecessarily restart the original session.
      await DraftStorage().saveModelMode(
        sessionId,
        modelMode ?? ChatModelMode.defaultModel.modeString,
      );
      // createSession() already called refreshSessions() internally
      // and added the session to sync._sessions (optimistic fallback).
      // Just read the in-memory state — no redundant server fetch.
      sessionsNotifier.loadFromSync();
      // A dialog whose element is already deactivated has been dismissed by
      // something else; popping again would unwind an unrelated route.
      if (!_canUseRef) return;
      navigator.pop(sessionId);
    } on IncompatibleProviderAndModelError catch (e, st) {
      logger.warning(
        '[NewSessionDialog] incompatible provider/model: $e',
        e,
        st,
      );
      if (!_canUseRef) return;
      setState(() {
        _isCreating = false;
        _creationPhase = null;
        _createError = e.message;
      });
    } catch (e, st) {
      logger.warning('[NewSessionDialog] createSession failed: $e', e, st);
      if (!_canUseRef) return;
      final userMessage = newSessionCreateErrorMessage(l10n: l10n, error: e);
      setState(() {
        _isCreating = false;
        _creationPhase = null;
        _createError = userMessage;
      });
    }
  }
}

/// Resolves a stale machine selection to the freshest online registration for
/// the same host.
///
/// Daemon credential resets and interrupted database updates can leave more
/// than one machine record for a host. Never fall back to an unrelated host:
/// if no matching online registration exists, preserve the stale selection so
/// the dialog's offline guard keeps Create disabled.
String? resolveAvailableMachineId(
  String? selectedMachineId,
  Map<String, Machine> machines, {
  int? nowMs,
}) {
  if (selectedMachineId == null) return null;

  final selected = machines[selectedMachineId];
  if (selected == null) return selectedMachineId;

  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  if (selected.isOnlineAt(now)) return selectedMachineId;

  final host = selected.metadata?.host?.trim();
  if (host == null || host.isEmpty) return selectedMachineId;

  final replacements =
      machines.values
          .where(
            (machine) =>
                machine.id != selectedMachineId &&
                machine.metadata?.host?.trim() == host &&
                machine.isOnlineAt(now),
          )
          .toList()
        ..sort((a, b) {
          final activeComparison = b.activeAt.compareTo(a.activeAt);
          if (activeComparison != 0) return activeComparison;
          return a.id.compareTo(b.id);
        });

  return replacements.firstOrNull?.id ?? selectedMachineId;
}

/// Probes the selected registration and then other online registrations for
/// the same host, newest first.
///
/// A daemon restart or clustered launcher can keep emitting host activity
/// under one machine ID while its RPC handlers are registered under another.
/// Presence alone therefore cannot identify the registration that can spawn.
Future<String> resolveReachableMachineId(
  String selectedMachineId,
  Map<String, Machine> machines, {
  required Future<void> Function(String machineId) probe,
  int? nowMs,
}) async {
  final selected = machines[selectedMachineId];
  if (selected == null) {
    throw StateError('Machine is offline');
  }

  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final host = selected.metadata?.host?.trim();
  final candidates = <Machine>[
    selected,
    if (host != null && host.isNotEmpty)
      ...machines.values.where(
        (machine) =>
            machine.id != selectedMachineId &&
            machine.metadata?.host?.trim() == host &&
            machine.isOnlineAt(now),
      ),
  ];
  if (candidates.length > 1) {
    candidates.setRange(
      1,
      candidates.length,
      candidates.sublist(1)..sort((a, b) {
        final activeComparison = b.activeAt.compareTo(a.activeAt);
        if (activeComparison != 0) return activeComparison;
        return a.id.compareTo(b.id);
      }),
    );
  }

  Object? lastError;
  StackTrace? lastStack;
  for (final candidate in candidates) {
    try {
      await probe(candidate.id);
      return candidate.id;
    } catch (error, stack) {
      lastError = error;
      lastStack = stack;
    }
  }
  Error.throwWithStackTrace(
    lastError ?? StateError('Machine is unreachable'),
    lastStack ?? StackTrace.current,
  );
}

bool _machineSupportsKubernetes(Machine machine) =>
    machine.metadata?.spawnBackends?.contains('kubernetes') ?? false;

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

String kubernetesCheckoutPath(Machine machine, String repositoryUrl) {
  final advertisedBase = machine.metadata?.kubernetesCheckoutBaseDir?.trim();
  final base = advertisedBase != null && advertisedBase.isNotEmpty
      ? advertisedBase
      : '/workspace';
  var slug = repositoryUrl.trim().replaceAll(RegExp(r'[/\\]+$'), '');
  final slash = slug.lastIndexOf('/');
  final colon = slug.lastIndexOf(':');
  final separator = slash > colon ? slash : colon;
  if (separator >= 0) slug = slug.substring(separator + 1);
  if (slug.toLowerCase().endsWith('.git')) {
    slug = slug.substring(0, slug.length - 4);
  }
  slug = slug
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  if (slug.isEmpty) slug = 'repository';
  return '${base.replaceAll(RegExp(r'/+$'), '')}/$slug';
}

/// Mirrors Sync._isClaudeModelAlias so the create dialog can reject
/// lastUsedModelMode values that would trip the daemon's
/// provider_model_mismatch guard.
bool _isClaudeModelAliasForDialog(String modelMode) {
  final separator = modelMode.lastIndexOf(':');
  final slug = separator > 0 ? modelMode.substring(0, separator) : modelMode;
  return slug == 'opus' ||
      slug == 'sonnet' ||
      slug == 'haiku' ||
      slug == 'fable' ||
      slug.startsWith('claude-') ||
      slug.contains('/claude-');
}

class _PathField extends ConsumerWidget {
  const _PathField({
    required this.machineId,
    required this.selectedPath,
    required this.onChanged,
    required this.onSelected,
  });

  final String? machineId;
  final String? selectedPath;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final paths =
        sessions.values
            .where((session) => session.metadata?.machineId == machineId)
            .map((session) => session.metadata?.path)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    return Autocomplete<String>(
      key: ValueKey('local-path-$machineId'),
      optionsBuilder: (value) {
        if (value.text.isEmpty) return paths;
        final query = value.text.toLowerCase();
        return paths.where((path) => path.toLowerCase().contains(query));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        final path = selectedPath;
        if (path != null && path.isNotEmpty && controller.text.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (controller.text.isEmpty) controller.text = path;
          });
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: context.l10n.sessionPath,
            hintText: context.l10n.sessionPathHint,
          ),
          onChanged: onChanged,
        );
      },
    );
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
  Widget build(BuildContext context) => SegmentedButton<String>(
    segments: backends
        .map(
          (backend) => ButtonSegment(
            value: backend,
            label: Text(backend == 'kubernetes' ? 'Kubernetes' : 'Local'),
            icon: Icon(
              backend == 'kubernetes'
                  ? Icons.cloud_queue_outlined
                  : Icons.computer_outlined,
            ),
          ),
        )
        .toList(growable: false),
    selected: {selectedBackend},
    onSelectionChanged: (selection) => onSelected(selection.first),
  );
}

class _RepositoryUrlField extends ConsumerWidget {
  const _RepositoryUrlField({
    required this.machineId,
    required this.selectedRepoUrl,
    required this.onChanged,
    required this.onSelected,
  });

  final String? machineId;
  final String? selectedRepoUrl;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final repoUrls = _repositoryUrlsForMachine(sessions, machineId);

    return Autocomplete<String>(
      key: ValueKey('repo-url-$machineId'),
      optionsBuilder: (textEditingValue) {
        if (repoUrls.isEmpty) return const <String>[];
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return repoUrls;
        return repoUrls.where((url) => url.toLowerCase().contains(query));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        final value = selectedRepoUrl;
        if (value != null && value.isNotEmpty && controller.text.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (controller.text.isEmpty) {
              controller.text = value;
            }
          });
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: context.l10n.newSessionRepositoryUrl,
            hintText: 'https://github.com/org/repo.git',
            prefixIcon: const Icon(Icons.source_outlined),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
        );
      },
    );
  }
}

List<String> _repositoryUrlsForMachine(
  Map<String, Session> sessions,
  String? machineId,
) {
  final urls = <String>{};
  for (final session in sessions.values) {
    final metadata = session.metadata;
    if (metadata == null) continue;
    if (machineId != null && metadata.machineId != machineId) continue;
    final url = metadata.repoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      urls.add(url);
    }
  }
  return urls.toList()..sort();
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
    'grok' => l10n.sessionsGrok,
    _ => l10n.sessionsClaude,
  };
}

IconData _agentIcon(String agent) {
  return switch (agent) {
    'codex' => Icons.terminal_rounded,
    'gemini' => Icons.auto_awesome_rounded,
    'pi' => Icons.memory_rounded,
    'opencode' => Icons.code_rounded,
    'grok' => Icons.rocket_launch_rounded,
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
          ? const Icon(Icons.hourglass_top_rounded, size: AppSpacing.lg)
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
    case NewSessionCreateBlocker.kubernetesUnavailable:
      return l10n.newSessionKubernetesUnavailable;
    case NewSessionCreateBlocker.missingPath:
      return l10n.sessionNoPathSelected;
    case NewSessionCreateBlocker.missingRepository:
      return l10n.newSessionRepositoryRequired;
    case NewSessionCreateBlocker.missingRepositoryRef:
      return l10n.newSessionGitRefRequired;
    case NewSessionCreateBlocker.creating:
      return l10n.commonCreate;
    case NewSessionCreateBlocker.disconnected:
      return l10n.sessionNotConnectedToServer;
    case NewSessionCreateBlocker.syncNotReady:
      return l10n.authConnecting;
    case null:
      return l10n.statusConnected;
  }
}
