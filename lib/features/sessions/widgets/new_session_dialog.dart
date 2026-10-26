import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/built_in_profiles.dart';
import '../../../core/models/favorite_model.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/models/settings.dart' show AIBackendProfile;
import '../../../core/providers/app_providers.dart';
import '../../../core/services/draft_storage.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import '../../../core/widgets/app_focus_traversal.dart';
import '../../chat/model_selection_resolver.dart'
    show profileOwnsRawCodexModel, profileUsesThirdPartyAnthropicBaseUrl;
import '../../chat/widgets/model_mode.dart';
import '../harness_logo.dart';

part 'new_session_fields.dart';
part 'new_session_resolution.dart';
part 'new_session_recent_workspace.dart';
part 'new_session_setup_sections.dart';

enum NewSessionCreateBlocker {
  missingMachine,
  offlineMachine,
  missingPath,
  kubernetesUnavailable,
  harLocalBackend,
  missingRepository,
  missingRepositoryRef,
  creating,
  disconnected,
  syncNotReady,
}

const _agentIds = [
  'claude',
  'codex',
  'agy',
  'pi',
  'opencode',
  'grok',
  'har',
  'prime-agent',
];

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
  bool harLocalBackendRequired = false,
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
  if (harLocalBackendRequired) return NewSessionCreateBlocker.harLocalBackend;
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
  String? initialAgent,
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
      initialAgent: initialAgent,
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
    this.initialAgent,
  });

  /// Optional pre-selected machine ID.
  final String? initialMachineId;

  /// Optional pre-selected path.
  final String? initialPath;
  final String? initialRepositoryUrl;
  final String? initialRepositoryRef;
  final String? initialAgent;

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

  /// Deactivation can precede State.dispose; guard both before using ref.
  bool get _canUseRef => mounted && context.mounted;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    final lastUsedAgent = widget.initialAgent ?? settings.lastUsedAgent;
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
    final machineSortNow = DateTime.now().millisecondsSinceEpoch;
    final machines = allMachines.values.toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(machineSortNow, a, b));

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
      harLocalBackendRequired: _selectedAgent == 'har' && isKubernetes,
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
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight:
              (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom) *
              0.9,
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        title: _NewSessionHeading(title: l10n.newSessionTitle),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.chatWorkspaceTitle,
                    style: AppText.label(theme, cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (machines.isEmpty)
                  Text(l10n.newSessionNoMachinesFound)
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('new-session-machine-$_selectedMachine'),
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
                                    style: AppText.secondary(
                                      theme,
                                      cs.onSurfaceVariant,
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
                          _selectedSpawnBackend =
                              _defaultSpawnBackendForMachine(
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
                  _RecentWorkspacePicker(
                    machineId: _selectedMachine,
                    selectedPath: _selectedPath,
                    onSelected: (path) => setState(() {
                      _selectedPath = path;
                      _createError = null;
                    }),
                  ),
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
                ],
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                _AgentPicker(
                  selectedAgent: _selectedAgent,
                  onSelected: (agent) => setState(() => _selectedAgent = agent),
                ),
                if (_selectedAgent == 'har') ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Host execution · approvals disabled. The model can be '
                    'changed during the conversation. Requires an installed '
                    'har binary and a local daemon with Boxy explicitly '
                    'disabled.',
                    style: AppText.secondary(theme, cs.onSurfaceVariant),
                  ),
                  if (isKubernetes)
                    Text(
                      'Har is available on the local backend. Select Local '
                      'to start it.',
                      style: AppText.secondary(theme, cs.error),
                    ),
                ],
                if (!isKubernetes || spawnBackends.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  _NewSessionAdvancedOptions(
                    isKubernetes: isKubernetes,
                    sessionType: _sessionType,
                    spawnBackends: spawnBackends,
                    selectedSpawnBackend: selectedSpawnBackend,
                    onSessionTypeChanged: (value) =>
                        setState(() => _sessionType = value),
                    onSpawnBackendSelected: (backend) => setState(() {
                      _selectedSpawnBackend = backend;
                      _spawnBackendTouched = true;
                      _createError = null;
                    }),
                  ),
                ],
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
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
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
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _createError!,
                      style: AppText.secondary(theme, cs.error),
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
                          dimension: AppIconSize.md,
                          child: AppCircularProgressIndicator(strokeWidth: 2),
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
    final navigator = Navigator.of(context);
    if (!_canUseRef) return;
    final machinesNotifier = ref.read(machinesNotifierProvider.notifier);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
    final sessionsNotifier = ref.read(sessionsNotifierProvider.notifier);

    setState(() {
      _isCreating = true;
      _creationPhase = l10n.newSessionPhaseCheckingMachine;
      _createError = null;
    });

    try {
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
      var hadGhostProfileReference = false;
      if (profileId != null) {
        selectedProfile = updatedSettings.profiles
            .where((p) => p.id == profileId)
            .firstOrNull;
        selectedProfile ??= getBuiltInProfile(profileId);
        if (selectedProfile == null) hadGhostProfileReference = true;
      }
      String? normalizeProfileCandidate(String? raw) {
        if (raw == null) return null;
        final candidate = ChatModelMode.normalizeRawForFlavor(
          raw,
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
        if (thirdParty && _isClaudeModelAliasForDialog(candidate)) {
          return null;
        }
        return candidate;
      }

      if (!hadGhostProfileReference) {
        modelMode = normalizeProfileCandidate(
          favoriteModelForProvider(
            updatedSettings.favoriteModelsByProfile,
            selectedProfile,
            _selectedAgent,
          ),
        );
        modelMode ??= selectedProfile?.defaultModelMode;
      }
      if (_selectedAgent != 'prime-agent') {
        modelMode ??= normalizeProfileCandidate(
          updatedSettings.lastUsedModelMode,
        );
      }
      if (_selectedAgent == 'opencode') modelMode = null;
      if (_selectedAgent == 'har') modelMode = null;
      if (!_canUseRef) return;
      if (modelMode != null) {
        modelMode = applyProfileContextWindowSuffix(
          raw: modelMode,
          profile: selectedProfile,
          flavor: _selectedAgent,
        );
      }
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
      if (profileId != null) {
        await DraftStorage().saveProfileId(sessionId, profileId);
      }
      await DraftStorage().saveModelMode(
        sessionId,
        modelMode ?? ChatModelMode.defaultModel.modeString,
      );
      sessionsNotifier.loadFromSync();
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
      logger.warning('[NewSessionDialog] createSession failed', e, st);
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
