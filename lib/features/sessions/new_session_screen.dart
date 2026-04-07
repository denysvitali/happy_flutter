import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../core/components/components.dart';
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

List<Machine> sortMachinesForSessionCreation(Iterable<Machine> machines) {
  final sorted = machines.toList()
    ..sort((a, b) {
      if (a.active != b.active) {
        return a.active ? -1 : 1;
      }
      return b.activeAt.compareTo(a.activeAt);
    });
  return sorted;
}

/// Full screen for creating a new session.
class NewSessionScreen extends ConsumerStatefulWidget {
  const NewSessionScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _selectedAgent = settings.lastUsedAgent ?? 'claude';
    _selectedProfileId = settings.lastUsedProfile;
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

  bool _canCreate(ConnectionStatus connectionStatus) =>
      _selectedMachine != null &&
      _pathController.text.trim().isNotEmpty &&
      !_isCreating &&
      connectionStatus == ConnectionStatus.connected &&
      sync.isInitialized;

  /// Resolve the currently selected profile display name.
  String _profileDisplayName() {
    if (_selectedProfileId == null) return 'None';
    final settings = ref.read(settingsNotifierProvider);
    final profile = resolveProfile(_selectedProfileId!, settings.profiles);
    return profile?.name ?? _selectedProfileId!;
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
      });
      final String sessionPath;
      if (_sessionType == 'worktree') {
        sessionPath = await sync.createWorktree(
          machineId: machine.id,
          basePath: path,
        );
      } else {
        sessionPath = path;
      }
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
      final modelMode = profile?.defaultModelMode;
      if (modelMode != null) {
        unawaited(DraftStorage().saveModelMode(sessionId, modelMode));
      }
      if (_selectedProfileId != null) {
        await DraftStorage().saveProfileId(sessionId, _selectedProfileId!);
      }
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

  Future<void> _pickMachine() async {
    final result = await context.pushNamed<Machine>('pick-machine');
    if (result != null) {
      setState(() {
        _selectedMachine = result;
      });
    }
  }

  Future<void> _pickPath() async {
    final machineId = _selectedMachine?.id;
    final result = await context.pushNamed<String>(
      'pick-path',
      queryParameters: machineId != null ? {'machineId': machineId} : const {},
    );
    if (result != null) {
      setState(() {
        _pathController.text = result;
      });
    }
  }

  Future<void> _pickProfile() async {
    final result = await context.pushNamed<String?>(
      'pick-profile',
      queryParameters: {'agent': _selectedAgent},
    );
    // result is the profile ID or null for "None"
    if (!mounted) return;
    setState(() {
      _selectedProfileId = result;
    });
    // Auto-adjust agent based on profile compatibility
    if (result != null) {
      final settings = ref.read(settingsNotifierProvider);
      final profile = resolveProfile(result, settings.profiles);
      if (profile != null) {
        final compat = profile.compatibility;
        // If current agent is incompatible, switch to first
        // compatible one.
        if (!_isAgentCompatible(_selectedAgent, compat)) {
          if (compat.claude) {
            setState(() => _selectedAgent = 'claude');
          } else if (compat.codex) {
            setState(() => _selectedAgent = 'codex');
          } else if (compat.gemini) {
            setState(() => _selectedAgent = 'gemini');
          }
        }
      }
    }
  }

  bool _isAgentCompatible(String agent, ProfileCompatibility compat) {
    switch (agent) {
      case 'claude':
        return compat.claude;
      case 'codex':
        return compat.codex;
      case 'gemini':
        return compat.gemini;
      default:
        return true;
    }
  }

  /// Get the compatibility flags for the current profile.
  ProfileCompatibility? _currentProfileCompatibility() {
    if (_selectedProfileId == null) return null;
    final settings = ref.read(settingsNotifierProvider);
    final profile = resolveProfile(_selectedProfileId!, settings.profiles);
    return profile?.compatibility;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machines = sortMachinesForSessionCreation(
      ref.watch(machinesNotifierProvider).values,
    );
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final compat = _currentProfileCompatibility();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newSessionTitle),
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      body: ListView(
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
              ],
              selected: {_selectedAgent},
              onSelectionChanged: (selection) {
                setState(() => _selectedAgent = selection.first);
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

          // ── Connection status hint ────────────────────────────────
          if (connectionStatus != ConnectionStatus.connected &&
              connectionStatus != ConnectionStatus.error)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    connectionStatus == ConnectionStatus.connecting
                        ? l10n.authConnecting
                        : l10n.sidebarStatusDisconnected,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          // ── Create button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: AppTouchTarget.comfortable,
            child: FilledButton.icon(
              onPressed: _canCreate(connectionStatus) ? _createSession : null,
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
      ),
    );
  }
}

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
