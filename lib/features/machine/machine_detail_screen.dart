import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/components/app_badge.dart';
import '../../core/components/app_banner.dart';
import '../../core/components/app_icon_tile.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/components/settings_section.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/routing/safe_pop.dart';
import '../../core/services/chat_switch_metrics.dart';
import '../../core/services/sync_service.dart';
import '../../core/sync/sync_subscription_mixin.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/clipboard_feedback.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/utils/session_utils.dart' show formatOSPlatform;
import '../../core/utils/snack.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/version_utils.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import '../../core/widgets/app_linear_progress_indicator.dart';
import '../settings/widgets/machine_usage_scaffold.dart' show UsageWindowRow;
import 'widgets/agent_update_banner.dart';
import 'widgets/machine_git_identity.dart';
import 'widgets/machine_kubernetes_claude_md.dart';
import 'widgets/machine_provider_versions.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

/// Detail screen for a single machine.
///
/// Shows machine info (name, host, OS, version) and lists sessions
/// connected to this machine.
class MachineDetailScreen extends ConsumerStatefulWidget {
  const MachineDetailScreen({required this.machineId, super.key});

  final String machineId;

  @override
  ConsumerState<MachineDetailScreen> createState() =>
      _MachineDetailScreenState();
}

class _MachineDetailScreenState extends ConsumerState<MachineDetailScreen>
    with SyncSubscriptionMixin {
  bool _deletePending = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
      await ref.read(machinesNotifierProvider.notifier).refreshFromSync();
    });
    subscribeToDomains([SyncDomain.machines], () {
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
    });
  }

  String _formatTimestamp(int ms) =>
      formatRelativeTime(DateTime.fromMillisecondsSinceEpoch(ms));

  String _getSessionName(Session session) {
    final meta = session.metadata;
    if (meta?.name != null) return meta!.name!;
    if (meta?.path != null) {
      final parts = meta!.path!.split('/');
      return parts.last.isNotEmpty ? parts.last : meta.path!;
    }
    return session.id;
  }

  String _getSessionSubtitle(Session session) {
    return session.metadata?.path ?? session.metadata?.host ?? '';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String machineId,
    String machineName,
  ) async {
    if (_deletePending) return;
    final auth = ref.read(authStateNotifierProvider.notifier);
    final generation = auth.authTransitionGeneration;
    bool isCurrent() =>
        mounted &&
        widget.machineId == machineId &&
        identical(ref.read(authStateNotifierProvider.notifier), auth) &&
        auth.authTransitionGeneration == generation;

    setState(() => _deletePending = true);
    try {
      final confirmed = await showConfirmDialog(
        context,
        title: context.l10n.commonDelete,
        content: context.l10n.machineRemoveConfirm(machineName),
        confirmLabel: context.l10n.commonDelete,
        isDestructive: true,
      );
      if (!context.mounted || !isCurrent() || !confirmed) return;
      setState(() => _deleting = true);
      final api = ApiClient();
      final response = await api.delete('/v1/machines/$machineId');
      if (!context.mounted || !isCurrent()) return;
      if (api.isSuccess(response)) {
        ref.read(machinesNotifierProvider.notifier).remove(machineId);
        sync.machinesSync.invalidate();
        safePop<void>(context);
      } else {
        context.showSnack(
          context.l10n.machineDeleteFailed(response.statusCode ?? 0),
        );
      }
    } catch (_) {
      if (context.mounted && isCurrent()) {
        context.showSnack(context.l10n.machineDeleteFailed(0));
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletePending = false;
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final machine = ref.watch(machineByIdProvider(widget.machineId));
    final sessions = ref.watch(
      sessionsNotifierProvider.select(
        (all) => Map.fromEntries(
          all.entries.where(
            (e) => e.value.metadata?.machineId == widget.machineId,
          ),
        ),
      ),
    );
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (machine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('')),
        body: Center(
          child: Text(
            context.l10n.errorNotFound,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final metadata = machine.metadata;
    final machineName = metadata?.displayName ?? metadata?.host ?? machine.id;
    final isOnline = machine.isOnline;
    final stats = _MachineStats.fromDaemonState(machine.daemonState);
    final cliVersion = metadata?.happyCliVersion;
    final cliOutdated = cliVersion != null && !isVersionSupported(cliVersion);

    // Sessions for this machine, sorted by most recently updated.
    final machineSessions =
        sessions.values
            .where((s) => s.metadata?.machineId == widget.machineId)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          machineName,
          style: AppText.screenTitle(theme),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(machinesNotifierProvider.notifier).refreshFromSync(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            // ── Header: identity + live status ──
            _MachineHeader(
              subtitle: [
                if (metadata?.platform != null)
                  formatOSPlatform(metadata!.platform),
                if (metadata?.arch != null) metadata!.arch!,
              ].join(' · '),
              isOnline: isOnline,
              lastSeen: _formatTimestamp(machine.activeAt),
            ),
            if (cliOutdated) ...[
              const SizedBox(height: AppSpacing.md),
              AppBanner(
                tone: AppBadgeTone.warning,
                icon: Icons.system_update_alt_rounded,
                title: context.l10n.machineCompatibilityTitle,
                message: context.l10n.machineCompatibilityMessage(
                  cliVersion,
                  minimumCliVersion,
                ),
                footer: Text(
                  context.l10n.machineCompatibilityAction,
                  style: AppText.badge(
                    theme,
                    AppToneColors.of(context, AppBadgeTone.warning).foreground,
                  ),
                ),
                trailing: const Icon(Icons.copy_outlined),
                onTap: () async {
                  await setClipboardTextSafely(
                    'npm install -g happy-coder@latest',
                  );
                  if (context.mounted) {
                    context.showSnack(context.l10n.machineCompatibilityCopied);
                  }
                },
              ),
            ],
            AgentUpdateBanner(
              key: ValueKey('agent-update-banner-${widget.machineId}'),
              machineId: widget.machineId,
              machineName: machineName,
              isOnline: isOnline,
              topSpacing: AppSpacing.md,
            ),

            if (stats != null) ...[
              const SizedBox(height: _kSectionGap),
              SettingsSection(
                title: 'Resources',
                children: [
                  UsageWindowRow(
                    icon: Icons.speed_outlined,
                    title: 'CPU',
                    percent: _finitePercent(stats.cpuPercent),
                  ),
                  UsageWindowRow(
                    icon: Icons.memory_outlined,
                    title: 'Memory',
                    percent: _finitePercent(stats.memoryPercent),
                    footer: _resourceFooter(
                      context,
                      '${_bytes(stats.memoryUsedBytes)} / '
                      '${_bytes(stats.memoryTotalBytes)}',
                    ),
                  ),
                  UsageWindowRow(
                    icon: Icons.storage_outlined,
                    title: 'Disk',
                    percent: _finitePercent(stats.diskPercent),
                    footer: _resourceFooter(
                      context,
                      '${_bytes(stats.diskUsedBytes)} / '
                      '${_bytes(stats.diskTotalBytes)} · ${stats.diskPath}',
                    ),
                  ),
                ],
              ),
            ],

            // ── Coding agents ──
            const SizedBox(height: _kSectionGap),
            MachineProviderVersions(
              key: ValueKey('provider-versions-${widget.machineId}'),
              machineId: widget.machineId,
              machineName: machineName,
              isOnline: isOnline,
            ),

            // ── Git identity ──
            const SizedBox(height: _kSectionGap),
            MachineGitIdentity(
              key: ValueKey('git-identity-${widget.machineId}'),
              machineId: widget.machineId,
              isOnline: isOnline,
            ),

            if (metadata?.spawnBackends?.contains('kubernetes') == true) ...[
              const SizedBox(height: _kSectionGap),
              MachineKubernetesClaudeMd(
                key: ValueKey('kubernetes-claude-md-${widget.machineId}'),
                machineId: widget.machineId,
                isOnline: isOnline,
              ),
              const SizedBox(height: _kSectionGap),
              SettingsSection(
                title: context.l10n.claudeAuthTitle,
                children: [
                  SettingsNavRow(
                    icon: Icons.key_outlined,
                    title: context.l10n.claudeAuthSharedCredentials,
                    subtitle: context.l10n.claudeAuthSharedCredentialsHelp,
                    onTap: isOnline
                        ? () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                _ClaudeAuthDialog(machineId: widget.machineId),
                          )
                        : null,
                  ),
                ],
              ),
            ],

            // ── Sessions ──
            if (machineSessions.isNotEmpty) ...[
              const SizedBox(height: _kSectionGap),
              SettingsSection(
                title: context.l10n.machineSessions(machineSessions.length),
                children: [
                  for (int i = 0; i < machineSessions.length && i < 5; i++)
                    _SessionRow(
                      name: _getSessionName(machineSessions[i]),
                      subtitle: _getSessionSubtitle(machineSessions[i]),
                      isOnline: machineSessions[i].isPresenceOnline,
                      onTap: () {
                        final sessionId = machineSessions[i].id;
                        ChatSwitchMetrics().begin(
                          sessionId,
                          source: 'machine_detail',
                        );
                        context.push('/chat/$sessionId');
                      },
                    ),
                  if (machineSessions.length > 5)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        '+ ${machineSessions.length - 5} more',
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ],

            // ── Machine info ──
            const SizedBox(height: _kSectionGap),
            SettingsSection(
              title: context.l10n.machineInfo,
              children: [
                if (metadata?.host != null)
                  SettingsInfoRow(
                    icon: Icons.dns_outlined,
                    label: context.l10n.machineHost,
                    value: metadata!.host!,
                    stacked: true,
                  ),
                if (metadata?.username != null)
                  SettingsInfoRow(
                    icon: Icons.person_outline,
                    label: context.l10n.machineUsername,
                    value: metadata!.username!,
                  ),
                if (metadata?.platform != null)
                  SettingsInfoRow(
                    icon: Icons.computer_outlined,
                    label: context.l10n.machinePlatform,
                    value: metadata!.platform!,
                  ),
                if (metadata?.arch != null)
                  SettingsInfoRow(
                    icon: Icons.developer_board_outlined,
                    label: context.l10n.machineArchitecture,
                    value: metadata!.arch!,
                  ),
                if (metadata?.happyCliVersion != null)
                  SettingsInfoRow(
                    icon: Icons.terminal_outlined,
                    label: context.l10n.machineCliVersion,
                    value: metadata!.happyCliVersion!,
                    mono: true,
                    iconColor: cliOutdated
                        ? AppToneColors.of(
                            context,
                            AppBadgeTone.warning,
                          ).iconColor
                        : null,
                  ),
                if (metadata?.homeDir != null)
                  SettingsInfoRow(
                    icon: Icons.folder_outlined,
                    label: context.l10n.machineHomeDir,
                    value: metadata!.homeDir!,
                    mono: true,
                    stacked: true,
                  ),
                SettingsInfoRow(
                  icon: Icons.fingerprint,
                  label: context.l10n.machineMachineId,
                  value: widget.machineId,
                  mono: true,
                  stacked: true,
                  onCopy: () => _copy(context, widget.machineId),
                ),
              ],
            ),

            // ── Daemon status ──
            const SizedBox(height: _kSectionGap),
            SettingsSection(
              title: context.l10n.machineDaemon,
              children: [
                SettingsInfoRow(
                  icon: Icons.power_settings_new_rounded,
                  iconColor: isOnline ? AppColors.success : cs.onSurfaceVariant,
                  label: context.l10n.machineStatus,
                  valueWidget: AppBadge(
                    label: isOnline
                        ? context.l10n.machineRunning
                        : context.l10n.machineStopped,
                    tone: isOnline
                        ? AppBadgeTone.success
                        : AppBadgeTone.neutral,
                    showToneIcon: false,
                    leading: AppStatusDot(
                      color: isOnline ? AppColors.success : cs.onSurfaceVariant,
                      size: AppSpacing.xsm,
                    ),
                  ),
                ),
                if (metadata?.daemonLastKnownStatus != null)
                  SettingsInfoRow(
                    icon: Icons.info_outline,
                    label: context.l10n.machineLastKnownStatus,
                    value: metadata!.daemonLastKnownStatus!,
                  ),
                if (metadata?.daemonLastKnownPid != null)
                  SettingsInfoRow(
                    icon: Icons.tag,
                    label: context.l10n.machineLastKnownPid,
                    value: metadata!.daemonLastKnownPid.toString(),
                    mono: true,
                  ),
              ],
            ),

            // ── Remove ──
            const SizedBox(height: _kSectionGap),
            SettingsSection(
              danger: true,
              children: [
                SettingsRow(
                  icon: Icons.delete_outline,
                  iconColor: cs.error,
                  title: context.l10n.machineRemoveMachine,
                  onTap: _deletePending
                      ? null
                      : () => _confirmDelete(
                          context,
                          widget.machineId,
                          machineName,
                        ),
                  semanticsButton: true,
                  semanticsEnabled: !_deletePending,
                  trailing: _deleting
                      ? Semantics(
                          label: context.l10n.machineRemoveMachine,
                          liveRegion: true,
                          child: const SizedBox.square(
                            dimension: AppIconSize.md,
                            child: AppCircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value) => copyWithFeedback(
    context,
    value,
    successMessage: context.l10n.sessionInfoCopied,
  );
}

/// Gap between sections — the same rhythm the settings screens use.
const double _kSectionGap = AppSpacing.xl;

String _bytes(int value) => formatBytes(value, adaptivePrecision: true);

double _finitePercent(double value) =>
    value.isNaN || value.isInfinite ? 0 : value;

Widget _resourceFooter(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Text(
    text,
    style: AppText.secondary(theme, theme.colorScheme.onSurfaceVariant),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

class _ClaudeAuthDialog extends StatefulWidget {
  const _ClaudeAuthDialog({required this.machineId});
  final String machineId;

  @override
  State<_ClaudeAuthDialog> createState() => _ClaudeAuthDialogState();
}

class _ClaudeAuthDialogState extends State<_ClaudeAuthDialog> {
  final _responseController = TextEditingController();
  String? _flowId;
  String? _authorizationUrl;
  String? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_checkStatus);
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _busy = true);
    try {
      final response = await sync.machineClaudeAuthStatus(
        machineId: widget.machineId,
        flowId: _flowId ?? '',
      );
      if (!mounted) return;
      setState(() {
        _flowId = response.flowId.isEmpty ? _flowId : response.flowId;
        _status = response.authenticated ? 'authenticated' : response.status;
        _error = response.error.isEmpty ? null : response.error;
      });
    } catch (_) {
      // An old daemon may not implement status yet. Begin will surface a
      // useful error if the user chooses to authenticate.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _begin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await sync.machineBeginClaudeAuth(
        machineId: widget.machineId,
        force: _status == 'authenticated',
      );
      if (!mounted) return;
      setState(() {
        _flowId = response.flowId;
        _authorizationUrl = response.authorizationUrl;
        _status = response.status;
      });
      final uri = Uri.tryParse(response.authorizationUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final flowId = _flowId;
    final authResponse = _responseController.text.trim();
    if (flowId == null || authResponse.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await sync.machineCompleteClaudeAuth(
        machineId: widget.machineId,
        flowId: flowId,
        authResponse: authResponse,
      );
      if (!mounted) return;
      setState(() {
        _status = response.authenticated ? 'authenticated' : response.status;
        _error = response.error.isEmpty ? null : response.error;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authenticated = _status == 'authenticated';
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l10n.claudeAuthTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                authenticated
                    ? l10n.claudeAuthAuthenticated
                    : l10n.claudeAuthInstructions,
              ),
              if (_authorizationUrl != null) ...[
                const SizedBox(height: AppSpacing.md),
                SelectableText(_authorizationUrl!),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => launchUrl(
                          Uri.parse(_authorizationUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.claudeAuthOpenLink),
                ),
                TextField(
                  controller: _responseController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.claudeAuthResponse,
                    hintText: l10n.claudeAuthResponseHint,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: AppSpacing.md),
                const AppLinearProgressIndicator(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
          if (_authorizationUrl == null)
            FilledButton(
              onPressed: _busy ? null : _begin,
              child: Text(
                authenticated ? l10n.claudeAuthAgain : l10n.claudeAuthBegin,
              ),
            )
          else
            FilledButton(
              onPressed: _busy ? null : _complete,
              child: Text(l10n.claudeAuthComplete),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — identity and live status, on the settings card surface
// ─────────────────────────────────────────────────────────────────────────────

class _MachineHeader extends StatelessWidget {
  const _MachineHeader({
    required this.subtitle,
    required this.isOnline,
    required this.lastSeen,
  });

  final String subtitle;
  final bool isOnline;
  final String lastSeen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tone = isOnline ? AppBadgeTone.success : AppBadgeTone.neutral;
    final statusColor = AppToneColors.of(context, tone).iconColor;

    // The machine name is already the app-bar title; the header leads with
    // what changes — whether the daemon is reachable right now.
    return SettingsSection(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              AppIconTile(
                icon: isOnline
                    ? Icons.computer_outlined
                    : Icons.desktop_access_disabled_outlined,
                color: statusColor,
                size: AppControlSize.lg,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppStatusDot(color: statusColor, size: AppSpacing.sm),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          isOnline
                              ? context.l10n.machineOnline
                              : context.l10n.machineOffline,
                          style: AppText.title(theme, statusColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      isOnline
                          ? context.l10n.machineConnectedNow
                          : context.l10n.machineLastSeenAt(lastSeen),
                      style: AppText.secondary(theme, cs.onSurfaceVariant),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MachineStats {
  const _MachineStats({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.memoryUsedBytes,
    required this.memoryTotalBytes,
    required this.diskPercent,
    required this.diskUsedBytes,
    required this.diskTotalBytes,
    required this.diskPath,
    required this.sampledAt,
  });

  final double cpuPercent;
  final double memoryPercent;
  final int memoryUsedBytes;
  final int memoryTotalBytes;
  final double diskPercent;
  final int diskUsedBytes;
  final int diskTotalBytes;
  final String diskPath;
  final int sampledAt;

  static _MachineStats? fromDaemonState(Map<String, dynamic>? daemonState) {
    final raw = daemonState?['machineStats'];
    if (raw is! Map) return null;

    final cpu = raw['cpu'];
    final memory = raw['memory'];
    final disk = raw['disk'];
    if (cpu is! Map || memory is! Map || disk is! Map) return null;

    return _MachineStats(
      cpuPercent: _asDouble(cpu['usagePercent']),
      memoryPercent: _asDouble(memory['usagePercent']),
      memoryUsedBytes: _asInt(memory['usedBytes']),
      memoryTotalBytes: _asInt(memory['totalBytes']),
      diskPercent: _asDouble(disk['usagePercent']),
      diskUsedBytes: _asInt(disk['usedBytes']),
      diskTotalBytes: _asInt(disk['totalBytes']),
      diskPath: disk['path'] is String ? disk['path'] as String : '/',
      sampledAt: _asInt(raw['sampledAt']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session row
// ─────────────────────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.name,
    required this.subtitle,
    required this.isOnline,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final bool isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SettingsRow(
      icon: Icons.terminal_rounded,
      iconColor: isOnline ? AppColors.success : null,
      title: name,
      subtitle: subtitle.isEmpty ? null : subtitle,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOnline) ...[
            // Steady online state: static green dot.
            const AppStatusDot(color: AppColors.success, size: 7),
            const SizedBox(width: AppSpacing.sm),
          ],
          Icon(
            Icons.chevron_right,
            size: AppSpacing.xl,
            color: cs.onSurface.withValues(alpha: AppOpacity.medium),
          ),
        ],
      ),
    );
  }
}
