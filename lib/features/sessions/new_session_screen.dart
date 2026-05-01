import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../core/components/components.dart';
import '../../core/components/tablet/master_detail_scaffold.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/machine.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/draft_storage.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'pick_machine_screen.dart';
import 'pick_path_screen.dart';
import 'pick_profile_screen.dart';

List<Machine> sortMachinesForSessionCreation(Iterable<Machine> machines) =>
    machines.toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return b.activeAt.compareTo(a.activeAt);
      });

enum NewSessionCreateBlocker {
  missingMachine,
  offlineMachine,
  missingPath,
  creating,
  disconnected,
  syncNotReady,
}

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

/// Which picker is currently shown in the tablet detail pane.
enum _PickerMode { none, machine, path, profile }

/// Full screen for creating a new session.
class NewSessionScreen extends ConsumerStatefulWidget {
  const NewSessionScreen({super.key, this.initialMachineId, this.initialPath});

  /// Optional pre-selected machine ID (resolved against the machines
  /// provider once data is available).
  final String? initialMachineId;

  /// Optional pre-filled path.
  final String? initialPath;

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> {
  Machine? _selectedMachine;
  final _pathController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isCreating = false;
  String _selectedAgent = 'claude';
  String _sessionType = 'simple';
  String? _selectedProfileId;
  _PickerMode _pickerMode = _PickerMode.none;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _selectedAgent = settings.lastUsedAgent ?? 'claude';
    _selectedProfileId = resolveSelectedProfileIdForAgent(
      settings,
      _selectedAgent,
    );
    if (widget.initialPath != null) {
      _pathController.text = widget.initialPath!;
    }
    final initialMachineId = widget.initialMachineId;
    if (initialMachineId != null) {
      final machines = ref.read(machinesNotifierProvider);
      final preselected = machines[initialMachineId];
      if (preselected != null) _selectedMachine = preselected;
    }
    // Refresh machines so encryption keys are up-to-date before spawn.
    Future<void>.microtask(
      () => ref.read(machinesNotifierProvider.notifier).refreshFromSync(),
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  static const int _onlineThresholdMs = 120 * 1000;

  bool _isMachineOnline(Machine? machine) {
    if (machine == null || !machine.active) return false;
    final age = DateTime.now().millisecondsSinceEpoch - machine.activeAt;
    return age < _onlineThresholdMs;
  }

  bool _canCreate(
    ConnectionStatus connectionStatus,
    Machine? resolvedMachine,
  ) =>
      newSessionCreateBlocker(
        machine: resolvedMachine,
        machineOnline: _isMachineOnline(resolvedMachine),
        path: _pathController.text,
        isCreating: _isCreating,
        connectionStatus: connectionStatus,
        syncInitialized: sync.isInitialized,
      ) ==
      null;

  /// Resolve the currently selected profile display name.
  String _profileDisplayName() {
    final pid = _selectedProfileId;
    if (pid == null) return 'None';
    final settings = ref.read(settingsNotifierProvider);
    return resolveProfile(pid, settings.profiles)?.name ?? pid;
  }

  Future<void> _createSession() async {
    final machine = _selectedMachine;
    final path = _pathController.text.trim();
    if (machine == null || path.isEmpty) return;

    final settings = ref.read(settingsNotifierProvider);
    setState(() => _isCreating = true);

    try {
      await sync.applySettings({
        'lastUsedAgent': _selectedAgent,
        'lastUsedProfile': _selectedProfileId,
        'lastUsedProfilesByAgent': settings.lastUsedProfilesWithAgent(
          _selectedAgent,
          _selectedProfileId,
        ),
      });
      final sessionPath = _sessionType == 'worktree'
          ? await sync.createWorktree(machineId: machine.id, basePath: path)
          : path;
      final initialMessage = _messageController.text.trim();
      final sessionId = await sync.createSession(
        machineId: machine.id,
        path: sessionPath,
        profileId: _selectedProfileId,
        message: initialMessage.isNotEmpty ? initialMessage : null,
      );
      if (!mounted) return;
      final profile = _selectedProfileId != null
          ? resolveProfile(_selectedProfileId!, settings.profiles)
          : null;
      final permissionMode =
          profile?.defaultPermissionMode ?? settings.lastUsedPermissionMode;
      if (permissionMode != null) {
        unawaited(DraftStorage().savePermissionMode(sessionId, permissionMode));
      }
      // Use profile default, but fall back to the user's last explicit
      // selection so profile switches don't regress the model choice.
      final modelMode = profile?.defaultModelMode ?? settings.lastUsedModelMode;
      if (modelMode != null) {
        unawaited(DraftStorage().saveModelMode(sessionId, modelMode));
      }
      final pid = _selectedProfileId;
      if (pid != null) await DraftStorage().saveProfileId(sessionId, pid);
      // Persist the initial message on the server via the normal
      // sendMessage flow.  The daemon child already received the
      // message via HAPPY_INITIAL_PROMPT env var, so this is purely
      // for server-side storage.  The dedup flag in the Go CLI
      // prevents the message from being piped to Claude twice.
      if (initialMessage.isNotEmpty) {
        unawaited(
          ref
              .read(chatActionNotifierProvider.notifier)
              .sendMessage(
                sessionId,
                initialMessage,
                displayText: initialMessage,
                permissionMode: permissionMode,
                modelMode: modelMode,
                profileId: _selectedProfileId,
              ),
        );
      }
      // createSession() already called refreshSessions() internally
      // and added the session to sync._sessions (optimistic fallback).
      // Just read the in-memory state — no redundant server fetch.
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
      if (!mounted) return;
      context.goNamed('chat', pathParameters: {'sessionId': sessionId});
    } catch (e, st) {
      logger.warning('[NewSessionScreen] createSession failed: $e', e, st);
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  void _applyPickedMachine(Machine result) {
    setState(() {
      if (_selectedMachine?.id != result.id) {
        _pathController.clear();
      }
      _selectedMachine = result;
    });
  }

  void _applyPickedPath(String result) {
    setState(() {
      _pathController.text = result;
    });
  }

  void _applyPickedProfile(String? result) {
    if (!mounted) return;
    setState(() => _selectedProfileId = result);
    // Auto-adjust agent based on profile compatibility — if current
    // agent is incompatible, switch to the first compatible one.
    if (result == null) return;
    final settings = ref.read(settingsNotifierProvider);
    final profile = resolveProfile(result, settings.profiles);
    if (profile == null) return;
    final compat = profile.compatibility;
    if (_isAgentCompatible(_selectedAgent, compat)) return;
    final fallback = compat.claude
        ? 'claude'
        : compat.codex
            ? 'codex'
            : compat.gemini
                ? 'gemini'
                : null;
    if (fallback != null) setState(() => _selectedAgent = fallback);
  }

  Future<void> _pickMachine() async {
    if (MasterDetailScaffold.isWide(context)) {
      setState(() => _pickerMode = _PickerMode.machine);
      return;
    }
    final result = await context.pushNamed<Machine>('pick-machine');
    if (result != null) {
      _applyPickedMachine(result);
    }
  }

  Future<void> _pickPath() async {
    if (MasterDetailScaffold.isWide(context)) {
      setState(() => _pickerMode = _PickerMode.path);
      return;
    }
    final machineId = _selectedMachine?.id;
    final result = await context.pushNamed<String>(
      'pick-path',
      queryParameters: machineId != null ? {'machineId': machineId} : const {},
    );
    if (result != null) {
      _applyPickedPath(result);
    }
  }

  Future<void> _pickProfile() async {
    if (MasterDetailScaffold.isWide(context)) {
      setState(() => _pickerMode = _PickerMode.profile);
      return;
    }
    final result = await context.pushNamed<String?>(
      'pick-profile',
      queryParameters: {'agent': _selectedAgent},
    );
    _applyPickedProfile(result);
  }

  bool _isAgentCompatible(String agent, ProfileCompatibility compat) =>
      switch (agent) {
        'claude' => compat.claude,
        'codex' => compat.codex,
        'gemini' => compat.gemini,
        'pi' => compat.pi,
        _ => true,
      };

  /// Get the compatibility flags for the current profile.
  ProfileCompatibility? _currentProfileCompatibility() {
    final pid = _selectedProfileId;
    if (pid == null) return null;
    final settings = ref.read(settingsNotifierProvider);
    return resolveProfile(pid, settings.profiles)?.compatibility;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allMachines = ref.watch(machinesNotifierProvider);
    final machines = sortMachinesForSessionCreation(allMachines.values);
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final compat = _currentProfileCompatibility();
    // Re-resolve the selected machine from the provider so the offline
    // banner and Create button react to presence updates without requiring
    // the user to re-pick the machine.
    final resolvedSelectedMachine = _selectedMachine != null
        ? (allMachines[_selectedMachine!.id] ?? _selectedMachine)
        : null;
    final selectedMachineOffline =
        resolvedSelectedMachine != null &&
        !_isMachineOnline(resolvedSelectedMachine);
    final createBlocker = newSessionCreateBlocker(
      machine: resolvedSelectedMachine,
      machineOnline: _isMachineOnline(resolvedSelectedMachine),
      path: _pathController.text,
      isCreating: _isCreating,
      connectionStatus: connectionStatus,
      syncInitialized: sync.isInitialized,
    );

    final formList = ListView(
      padding: AppScreenPadding.standard,
      children: [
          // ── Machine ──────────────────────────────────────────────
          _SectionLabel(l10n.sessionMachine),
          const SizedBox(height: AppSpacing.sm),
          if (machines.isEmpty)
            AppCard(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.smd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.newSessionNoMachinesFound,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              onTap: _pickMachine,
              child: _MachinePickerRow(
                machine: _selectedMachine,
                hint: l10n.sessionSelectMachine,
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          // ── Path ─────────────────────────────────────────────────
          _SectionLabel(l10n.sessionPath),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: TextField(
                    controller: _pathController,
                    decoration: InputDecoration(
                      hintText: l10n.sessionPathHint,
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.folder_outlined,
                        color: _pathController.text.isNotEmpty
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_selectedMachine != null) ...[
                  Divider(height: 1, color: cs.outlineVariant),
                  AppTappable(
                    onTap: _pickPath,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppRadius.lg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.smd,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l10n.pickSelectPath,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: cs.primary.withValues(
                              alpha: AppOpacity.medium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // ── Session type ─────────────────────────────────────────
          _SectionLabel(l10n.sessionsType),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
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
          ),
          const SizedBox(height: AppSpacing.xl),
          // ── Profile ──────────────────────────────────────────────
          _SectionLabel(l10n.accountProfile),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            onTap: _pickProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.smd,
              ),
              child: Row(
                children: [
                  SettingsIconContainer(
                    icon: Icons.tune_rounded,
                    color: _selectedProfileId != null
                        ? colorForProfile(_selectedProfileId!)
                        : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _profileDisplayName(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: _selectedProfileId != null
                            ? FontWeight.w600
                            : null,
                        color: _selectedProfileId == null
                            ? cs.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: AppOpacity.medium),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // ── Agent ────────────────────────────────────────────────
          _SectionLabel(l10n.sessionsAgent),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'claude',
                  label: Text(l10n.sessionsClaude),
                  enabled: compat == null || compat.claude,
                ),
                ButtonSegment(
                  value: 'codex',
                  label: Text(l10n.sessionsCodex),
                  enabled: compat == null || compat.codex,
                ),
                ButtonSegment(
                  value: 'gemini',
                  label: Text(l10n.sessionsGemini),
                  enabled: compat == null || compat.gemini,
                ),
                ButtonSegment(
                  value: 'pi',
                  label: Text(l10n.sessionsPi),
                  enabled: compat == null || compat.pi,
                ),
              ],
              selected: {_selectedAgent},
              onSelectionChanged: (selection) {
                final agent = selection.first;
                final settings = ref.read(settingsNotifierProvider);
                setState(() {
                  _selectedAgent = agent;
                  _selectedProfileId = resolveSelectedProfileIdForAgent(
                    settings,
                    agent,
                  );
                });
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // ── Initial message (optional) ─────────────────────────
          _SectionLabel(l10n.sessionInitialMessage),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: l10n.sessionInitialMessageHint,
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.chat_bubble_outline,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          _CreateRequirementStatus(
            blocker: createBlocker,
            selectedMachineOffline: selectedMachineOffline,
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Create button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: AppTouchTarget.comfortable,
            child: FilledButton.icon(
              onPressed: _canCreate(connectionStatus, resolvedSelectedMachine)
                  ? _createSession
                  : null,
              icon: _isCreating
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.add_rounded, size: 20),
              label: Text(
                l10n.commonCreate,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
    );

    final isWide = MasterDetailScaffold.isWide(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newSessionTitle),
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      body: !isWide
          ? formList
          : MasterDetailScaffold(
              master: formList,
              detail: _buildPickerDetail(),
              hasSelection: _pickerMode != _PickerMode.none,
              emptyDetail: const TabletDetailEmpty(
                icon: Icons.add_circle_outline,
                message: 'Pick a machine, path, or profile',
              ),
            ),
    );
  }

  Widget _buildPickerDetail() {
    void close() => setState(() => _pickerMode = _PickerMode.none);
    return switch (_pickerMode) {
      _PickerMode.machine => PickMachineScreen(
        embedded: true,
        onPicked: (m) {
          _applyPickedMachine(m);
          close();
        },
        onClose: close,
      ),
      _PickerMode.path => PickPathScreen(
        machineId: _selectedMachine?.id,
        embedded: true,
        onPicked: (p) {
          _applyPickedPath(p);
          close();
        },
        onClose: close,
      ),
      _PickerMode.profile => PickProfileScreen(
        agent: _selectedAgent,
        embedded: true,
        onPicked: (id) {
          _applyPickedProfile(id);
          close();
        },
        onClose: close,
      ),
      _PickerMode.none => const SizedBox.shrink(),
    };
  }
}

class _CreateRequirementStatus extends StatelessWidget {
  const _CreateRequirementStatus({
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
    final isOffline = selectedMachineOffline ||
        blocker == NewSessionCreateBlocker.offlineMachine;
    final color = isOffline
        ? cs.error
        : isBlocked ? cs.onSurfaceVariant : AppColors.success;
    final icon = isOffline
        ? Icons.cloud_off_rounded
        : isBlocked
            ? Icons.info_outline_rounded
            : Icons.check_circle_outline_rounded;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            _createRequirementText(l10n, blocker),
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

String _createRequirementText(
  AppLocalizations l10n,
  NewSessionCreateBlocker? blocker,
) =>
    switch (blocker) {
      NewSessionCreateBlocker.missingMachine => l10n.sessionNoMachineSelected,
      NewSessionCreateBlocker.offlineMachine =>
        l10n.machineOfflineUnableToSpawn,
      NewSessionCreateBlocker.missingPath => l10n.sessionNoPathSelected,
      NewSessionCreateBlocker.creating => l10n.commonCreate,
      NewSessionCreateBlocker.disconnected => l10n.sessionNotConnectedToServer,
      NewSessionCreateBlocker.syncNotReady => l10n.authConnecting,
      null => l10n.statusConnected(''),
    };

/// Machine picker row — shows placeholder or selected machine info.
class _MachinePickerRow extends StatelessWidget {
  const _MachinePickerRow({required this.machine, required this.hint});

  final Machine? machine;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.smd,
      ),
      child: Row(
        children: [
          SettingsIconContainer(
            icon: Icons.computer_outlined,
            color: machine != null ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: machine == null
                ? Text(
                    hint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machine!.metadata?.displayName ??
                            machine!.metadata?.host ??
                            machine!.id,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (machine!.metadata?.host != null)
                        Text(
                          machine!.metadata!.host!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: cs.onSurface.withValues(alpha: AppOpacity.medium),
          ),
        ],
      ),
    );
  }
}

/// Uppercase section label above a form field.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
