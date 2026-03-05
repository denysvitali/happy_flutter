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
import '../../core/services/sync_service.dart';
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
      final sessionId = await sync.createSession(
        machineId: machine.id,
        path: sessionPath,
      );
      if (!mounted) return;
      // Use refreshFromSync to ensure we fetch the latest
      // session data from server.
      // This matches React Native's flow which calls sync.refreshSessions()
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
      if (!mounted) return;
      context.goNamed('chat', pathParameters: {'sessionId': sessionId});
    } catch (e) {
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
    final result = await context.pushNamed<String?>('pick-profile');
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
    final compat = _currentProfileCompatibility();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newSessionTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Machine selector
          _FieldLabel(l10n.sessionMachine),
          const SizedBox(height: AppSpacing.sm),
          if (machines.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.newSessionNoMachinesFound,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              onTap: _pickMachine,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.computer_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _selectedMachine == null
                          ? Text(
                              l10n.sessionSelectMachine,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedMachine!.metadata?.displayName ??
                                      _selectedMachine!.metadata?.host ??
                                      _selectedMachine!.id,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_selectedMachine!.metadata?.host != null)
                                  Text(
                                    _selectedMachine!.metadata!.host!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),

          // Path input
          _FieldLabel(l10n.sessionPath),
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
                      prefixIcon: const Icon(Icons.folder_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_selectedMachine != null) ...[
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  AppTappable(
                    onTap: _pickPath,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppRadius.lg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l10n.pickSelectPath,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
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

          // Session type selector
          // TODO(l10n): Add 'Type' to localizations
          _FieldLabel('Type'),
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.xl),

          // Profile selector
          // TODO(l10n): Add 'Profile' to localizations
          _FieldLabel('Profile'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            onTap: _pickProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.tune, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _profileDisplayName(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: _selectedProfileId != null
                            ? FontWeight.w600
                            : null,
                        color: _selectedProfileId == null
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Agent selector
          // TODO(l10n): Add 'Agent' to localizations
          _FieldLabel('Agent'),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
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
          const SizedBox(height: AppSpacing.xxxl),

          // Connection status hint when not yet connected
          if (connectionStatus != ConnectionStatus.connected &&
              connectionStatus != ConnectionStatus.error)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                connectionStatus == ConnectionStatus.connecting
                    ? l10n.authConnecting
                    : l10n.sidebarStatusDisconnected,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Create button
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _canCreate(connectionStatus) ? _createSession : null,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.commonCreate),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small uppercased label above a form field.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}
