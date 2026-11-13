import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/built_in_profiles.dart';
import '../../../core/models/default_mcp_servers.dart';
import '../../../core/models/favorite_model.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/models/settings.dart' show AIBackendProfile;
import '../../../core/providers/app_providers.dart';
import '../../../core/services/draft_storage.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/repo_history_storage.dart';
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
import 'kubernetes_mcp_section.dart';
import 'kubernetes_repository_section.dart';
import 'new_session_form_group.dart';

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
  repositoryRefNotFound,
  creating,
  disconnected,
  syncNotReady,
}

/// Below this width the dialog takes the whole screen.
const _fullscreenBreakpoint = 600.0;

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
  bool repositoryRefNotFound = false,
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
  if (enforceKubernetes && repositoryRefNotFound) {
    return NewSessionCreateBlocker.repositoryRefNotFound;
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
  final rejected = parseRejectedRepoRef(errorText);
  if (rejected != null) {
    final repo = RegExp(
      r'does not exist in (\S+?)(?:;|$|\s)',
    ).firstMatch(errorText);
    return l10n.newSessionBranchNotFound(rejected.ref, repo?.group(1) ?? '');
  }
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
  List<String> _additionalRepos = const [];
  Set<String> _mcpServers = {...kDefaultMcpServerIds};

  /// GitHub (asked through the machine) says the branch does not exist.
  bool _repoRefMissing = false;

  /// The machine refused the last spawn for this ref.
  RejectedRepoRef? _rejectedRepoRef;
  String? _selectedMachine;
  bool _isCreating = false;
  String? _creationPhase;
  String? _createError;
  String _selectedAgent = 'claude';
  String _sessionType = 'simple';

  /// Machine ('local') or Kubernetes; chosen at the top of the dialog and
  /// limits the machine list to daemons that support it.
  String _spawnMode = 'local';
  bool _spawnModeTouched = false;

  /// Optional first instruction; saved as the new chat's draft.

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
    final allMachinesSorted = allMachines.values.toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(machineSortNow, a, b));

    final selectedMachineRaw = _selectedMachine != null
        ? allMachines[_selectedMachine]
        : null;
    final spawnMode = _spawnModeTouched
        ? _spawnMode
        : _initialSpawnModeForMachine(selectedMachineRaw);
    final isKubernetes = spawnMode == 'kubernetes';
    final machines = allMachinesSorted
        .where((machine) => _machineSupportsSpawnMode(machine, spawnMode))
        .toList(growable: false);
    // A selection the current mode cannot use is treated as no selection so
    // the dropdown and the create guard agree.
    final selectedMachineObj =
        selectedMachineRaw != null &&
            _machineSupportsSpawnMode(selectedMachineRaw, spawnMode)
        ? selectedMachineRaw
        : null;
    final selectedMachineId = selectedMachineObj?.id;
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
      repositoryRefNotFound: _repoRefMissing,
    );
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Mirrors _AgentPicker's two-column threshold.
    final largeText =
        MediaQuery.textScalerOf(context).scale(AppFontSize.base) > 20;
    // Phones get the whole screen: a dialog card inside a phone leaves the
    // form a sliver between its title and its buttons.
    final fullscreen = MediaQuery.sizeOf(context).width < _fullscreenBreakpoint;
    final offlineWarning =
        selectedMachineOffline ||
        createBlocker == NewSessionCreateBlocker.offlineMachine;

    void selectMachine(String? value) {
      if (value != null) {
        final m = allMachines[value];
        if (m != null && !m.isOnlineAt(machineSortNow)) return;
      }
      setState(() {
        if (_selectedMachine != value) {
          _selectedPath = null;
          _selectedRepoUrl = null;
        }
        // Keep the mode the list was filtered by.
        _spawnMode = spawnMode;
        _spawnModeTouched = true;
        _selectedMachine = value;
      });
    }

    void selectPath(String value) => setState(() {
      _selectedPath = value;
      _createError = null;
    });

    const groupGap = SizedBox(height: AppSpacing.xxl);

    final body = <Widget>[
      _SpawnBackendPicker(
        backends: const ['local', 'kubernetes'],
        selectedBackend: spawnMode,
        onSelected: (mode) =>
            _selectSpawnMode(mode, allMachinesSorted, machineSortNow),
      ),
      groupGap,
      Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          bottom: AppSpacing.sm,
        ),
        child: NewSessionGroupHeader(text: l10n.sessionsAgent),
      ),
      if (largeText)
        _AgentPicker(
          selectedAgent: _selectedAgent,
          onSelected: (agent) => setState(() => _selectedAgent = agent),
        )
      else
        _AgentGrid(
          selectedAgent: _selectedAgent,
          onSelected: (agent) => setState(() => _selectedAgent = agent),
        ),
      if (_selectedAgent == 'har')
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Host execution · approvals disabled. The model can be '
                'changed during the conversation. Requires an installed '
                'har binary and a local daemon with Boxy explicitly '
                'disabled.',
                style: AppText.secondary(theme, cs.onSurfaceVariant),
              ),
              if (isKubernetes)
                Text(
                  'Har runs on a machine, not in Kubernetes. Select '
                  'Machine to start it.',
                  style: AppText.secondary(theme, cs.error),
                ),
            ],
          ),
        ),
      groupGap,
      NewSessionGroup(
        header: l10n.polishNewSessionWhere,
        footer: offlineWarning ? Text(l10n.machineOfflineHelp) : null,
        children: [
          if (machines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Text(
                isKubernetes && allMachinesSorted.isNotEmpty
                    ? l10n.newSessionNoKubernetesMachines
                    : l10n.newSessionNoMachinesFound,
                style: AppText.secondary(theme, cs.onSurfaceVariant),
              ),
            )
          else
            _MachineDropdown(
              key: ValueKey(
                'new-session-machine-$spawnMode-$selectedMachineId',
              ),
              machines: machines,
              selectedMachineId: selectedMachineId,
              isKubernetes: isKubernetes,
              nowMs: machineSortNow,
              onChanged: selectMachine,
            ),
          if (!isKubernetes)
            _PathField(
              machineId: selectedMachineId,
              selectedPath: _selectedPath,
              onChanged: selectPath,
              onSelected: selectPath,
            ),
          // Large text: the expandable list wraps long paths better than
          // the one-tap rows.
          if (!isKubernetes && largeText)
            _RecentWorkspacePicker(
              machineId: selectedMachineId,
              selectedPath: _selectedPath,
              onSelected: selectPath,
            ),
        ],
      ),
      if (!isKubernetes) ...[
        if (!largeText)
          _RecentWorkspaceCards(
            machineId: selectedMachineId,
            machineLabel: selectedMachineObj?.displayLabel,
            selectedPath: _selectedPath,
            onSelected: selectPath,
          ),
        groupGap,
        NewSessionGroup(
          children: [
            _NewSessionAdvancedOptions(
              sessionType: _sessionType,
              onSessionTypeChanged: (value) =>
                  setState(() => _sessionType = value),
            ),
          ],
        ),
      ],
      if (isKubernetes) ...[
        groupGap,
        KubernetesRepositorySection(
          key: ValueKey('k8s-repos-$selectedMachineId'),
          initialRepoUrl: widget.initialRepositoryUrl,
          initialRepoRef: widget.initialRepositoryRef,
          suggestedRepoUrls: _repositoryUrlsForMachine(
            ref.watch(sessionsNotifierProvider),
            selectedMachineId,
          ),
          enabled: !_isCreating,
          rejectedRef: _rejectedRepoRef,
          lookupBranches: selectedMachineId == null
              ? null
              : (repoUrl, ref) => sync.machineRepoBranches(
                  machineId: selectedMachineId,
                  repoUrl: repoUrl,
                  ref: ref,
                ),
          onChanged: (selection) {
            if (!mounted) return;
            setState(() {
              _selectedRepoUrl = selection.repoUrl;
              _selectedRepoRef = selection.repoRef;
              _additionalRepos = selection.additionalRepos;
              _repoRefMissing = selection.refMissing;
              _createError = null;
            });
          },
          extraOptions: [
            if (supportsDefaultMcpServers(_selectedAgent))
              KubernetesMcpSection(
                selected: _mcpServers,
                enabled: !_isCreating,
                onChanged: (selected) => setState(() => _mcpServers = selected),
              ),
          ],
        ),
      ],
    ];

    final footer = _NewSessionFooter(
      blocker: createBlocker,
      offlineWarning: offlineWarning,
      error: _createError,
      creationPhase: _isCreating ? _creationPhase : null,
      createButton: FilledButtonTheme(
        data: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            minimumSize: const Size.fromHeight(52),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child: _CreateButton(
          isCreating: _isCreating,
          onPressed: createBlocker == null
              ? () => _createSession(context)
              : null,
          label: l10n.commonCreate,
          tooltip: createBlocker == null
              ? null
              : _dialogRequirementText(l10n, createBlocker),
        ),
      ),
    );

    final scrollingBody = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: body,
      ),
    );

    final layout = Column(
      mainAxisSize: fullscreen ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NewSessionHeading(
          title: l10n.newSessionTitle,
          cancel: TextButton(
            onPressed: _isCreating ? null : () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
        ),
        if (fullscreen)
          Expanded(child: scrollingBody)
        else
          Flexible(child: scrollingBody),
        Divider(
          height: AppBorder.hairline,
          thickness: AppBorder.hairline,
          color: cs.outlineVariant.withValues(alpha: AppOpacity.strong),
        ),
        footer,
      ],
    );

    return PopScope(
      canPop: !_isCreating,
      child: fullscreen
          ? Dialog.fullscreen(
              backgroundColor: cs.surface,
              child: SafeArea(child: layout),
            )
          : Dialog(
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xxxl),
              ),
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight:
                      (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom) *
                      0.9,
                ),
                child: layout,
              ),
            ),
    );
  }

  /// Switches between Machine and Kubernetes. A selected machine that cannot
  /// run the new mode is replaced by the first online one that can.
  void _selectSpawnMode(String mode, List<Machine> sortedMachines, int nowMs) {
    final current = _selectedMachine != null
        ? ref.read(machinesNotifierProvider)[_selectedMachine]
        : null;
    setState(() {
      _spawnMode = mode;
      _spawnModeTouched = true;
      _createError = null;
      if (current != null && _machineSupportsSpawnMode(current, mode)) return;
      final replacement = sortedMachines
          .where(
            (machine) =>
                machine.isOnlineAt(nowMs) &&
                _machineSupportsSpawnMode(machine, mode),
          )
          .firstOrNull;
      if (replacement?.id != _selectedMachine) {
        _selectedPath = null;
        _selectedRepoUrl = null;
      }
      _selectedMachine = replacement?.id;
    });
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
        _spawnModeTouched ? _spawnMode : _initialSpawnModeForMachine(machine),
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
        additionalRepos: isKubernetes ? _additionalRepos : const [],
        mcpServers: isKubernetes && supportsDefaultMcpServers(_selectedAgent)
            ? mcpServersForSpawn(_mcpServers)
            : null,
      );
      if (!_canUseRef) return;
      if (isKubernetes) {
        ref
            .read(repoHistoryProvider.notifier)
            .recordUse(
              repoUrl: repoUrl!,
              repoRef: repoRef!,
              additionalRepos: _additionalRepos,
            );
      }
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
        // The machine refused the branch before creating a pod: hand the
        // repository fields its suggestion so the fix is one tap.
        _rejectedRepoRef =
            parseRejectedRepoRef(e is StateError ? e.message : e.toString()) ??
            _rejectedRepoRef;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Inset grouped layout: mode, agent, location, then folded options.
// ---------------------------------------------------------------------------

/// Up to three recent folders on the chosen machine as one-tap rows.
/// Selecting one only sets the path (never the agent or model).
class _RecentWorkspaceCards extends ConsumerWidget {
  const _RecentWorkspaceCards({
    required this.machineId,
    required this.machineLabel,
    required this.selectedPath,
    required this.onSelected,
  });

  final String? machineId;
  final String? machineLabel;
  final String? selectedPath;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machine = machineId;
    if (machine == null) return const SizedBox.shrink();
    final sessions =
        ref
            .watch(sessionsNotifierProvider)
            .values
            .where(
              (session) =>
                  session.metadata?.machineId == machine &&
                  session.metadata?.runtimeKind != 'kubernetes' &&
                  (session.metadata?.path?.trim().isNotEmpty ?? false),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final paths = sessions
        .map((session) => session.metadata!.path!)
        .toSet()
        .take(3)
        .toList();
    if (paths.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: NewSessionGroup(
        header: context.l10n.newSessionRecentWorkspace,
        children: [
          for (final path in paths)
            _WorkspaceRow(
              path: path,
              machineLabel: machineLabel,
              selected: path == selectedPath,
              onTap: () => onSelected(path),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    required this.path,
    required this.machineLabel,
    required this.selected,
    required this.onTap,
  });

  final String path;
  final String? machineLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final trimmed = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    final name = trimmed.split('/').where((p) => p.isNotEmpty).lastOrNull;
    final folder = name ?? path;
    final machine = machineLabel;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: machine == null ? path : '$path, $machine',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: kNewSessionTilePadding.add(
            const EdgeInsets.symmetric(vertical: AppSpacing.smd),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: AppIconSize.tab,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.secondary(theme, cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.check_rounded,
                  size: AppIconSize.xl,
                  color: cs.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Every agent as an evenly sized tile, four (or three) to a row, so the
/// choice reads as one tidy grid instead of a ragged run of pills.
class _AgentGrid extends StatelessWidget {
  const _AgentGrid({required this.selectedAgent, required this.onSelected});

  final String selectedAgent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FocusTraversalGroup(
      policy: AppReadingOrderTraversalPolicy(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppSpacing.sm;
          final columns = constraints.maxWidth >= 340 ? 4 : 3;
          final width = ((constraints.maxWidth - gap * (columns - 1)) / columns)
              .floorToDouble();
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final agent in _agentIds)
                SizedBox(
                  width: width,
                  child: Center(
                    child: _AgentTile(
                      agent: agent,
                      label: _agentLabel(l10n, agent),
                      width: width,
                      selected: agent == selectedAgent,
                      onTap: () => onSelected(agent),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({
    required this.agent,
    required this.label,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final String agent;
  final String label;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Chip padding and border take a few pixels; keep the label inside the
    // cell so the chip never overflows it.
    final labelWidth = (width - AppSpacing.lg).clamp(0.0, double.infinity);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      onTap: onTap,
      child: ChoiceChip(
        label: SizedBox(
          width: labelWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: HarnessLogo(flavor: agent, size: AppIconSize.tab),
              ),
              const SizedBox(height: AppSpacing.xsm),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? cs.onPrimaryContainer : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        selected: selected,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        side: BorderSide(
          width: 1.5,
          color: selected ? cs.primary : Colors.transparent,
        ),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.primaryContainer
              : cs.surfaceContainerHigh,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// The daemon that spawns the session. Offline daemons stay listed but
/// cannot be chosen.
class _MachineDropdown extends StatelessWidget {
  const _MachineDropdown({
    required this.machines,
    required this.selectedMachineId,
    required this.isKubernetes,
    required this.nowMs,
    required this.onChanged,
    super.key,
  });

  final List<Machine> machines;
  final String? selectedMachineId;
  final bool isKubernetes;
  final int nowMs;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DropdownButtonFormField<String>(
      decoration: newSessionRowDecoration(
        label: isKubernetes
            ? l10n.newSessionKubernetesDaemon
            : l10n.sessionMachine,
        icon: isKubernetes
            ? Icons.cloud_queue_outlined
            : Icons.computer_outlined,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      initialValue: selectedMachineId,
      isExpanded: true,
      selectedItemBuilder: (context) => [
        Text(l10n.sessionSelectMachine, overflow: TextOverflow.ellipsis),
        ...machines.map(
          (machine) =>
              Text(machine.displayLabel, overflow: TextOverflow.ellipsis),
        ),
      ],
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.sessionSelectMachine)),
        ...machines.map((machine) {
          final online = machine.isOnlineAt(nowMs);
          return DropdownMenuItem(
            value: machine.id,
            enabled: online,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppStatusDot(
                  color: online ? AppColors.success : cs.onSurfaceVariant,
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
                  Text(
                    l10n.machineOffline,
                    style: AppText.secondary(theme, cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}

/// Pinned below the form: what still blocks Create (or the creation
/// progress, or the last error) right above the button it explains.
class _NewSessionFooter extends StatelessWidget {
  const _NewSessionFooter({
    required this.blocker,
    required this.offlineWarning,
    required this.error,
    required this.creationPhase,
    required this.createButton,
  });

  final NewSessionCreateBlocker? blocker;
  final bool offlineWarning;
  final String? error;
  final String? creationPhase;
  final Widget createButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final phase = creationPhase;
    final failure = error;
    final Widget status;
    if (phase != null) {
      status = Semantics(
        liveRegion: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: AppIconSize.md,
              child: AppCircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(phase, style: AppText.secondary(theme, cs.onSurface)),
            ),
          ],
        ),
      );
    } else if (failure != null) {
      status = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline_rounded,
              size: AppIconSize.md,
              color: cs.error,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Semantics(
              liveRegion: true,
              child: Text(failure, style: AppText.secondary(theme, cs.error)),
            ),
          ),
        ],
      );
    } else {
      status = _DialogRequirementStatus(
        blocker: blocker,
        selectedMachineOffline: offlineWarning,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          status,
          const SizedBox(height: AppSpacing.md),
          createButton,
        ],
      ),
    );
  }
}
