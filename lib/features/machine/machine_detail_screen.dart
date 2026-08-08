import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/components/app_card.dart';
import '../../core/components/app_section_header.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/components/app_tappable.dart';
import '../../core/components/settings_section.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart'
    show AppFontSize, AppRadius, AppSpacing, AppTouchTarget;
import '../../core/routing/safe_pop.dart';
import '../../core/sync/sync_subscription_mixin.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/snack.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/utils/version_utils.dart';

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
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.commonDelete,
      content: context.l10n.machineRemoveConfirm(machineName),
      confirmLabel: context.l10n.commonDelete,
      isDestructive: true,
    );

    if (confirmed) {
      final response = await ApiClient().delete('/v1/machines/$machineId');
      if (!context.mounted) return;
      if (ApiClient().isSuccess(response)) {
        ref.read(machinesNotifierProvider.notifier).remove(machineId);
        sync.machinesSync.invalidate();
        safePop<void>(context);
      } else {
        context.showSnack(
          context.l10n.machineDeleteFailed(response.statusCode ?? 0),
        );
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
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
            // ── Status hero ──
            _StatusBanner(
              isOnline: isOnline,
              lastSeen: _formatTimestamp(machine.activeAt),
            ),
            if (cliOutdated) ...[
              const SizedBox(height: AppSpacing.md),
              Card(
                color: cs.tertiaryContainer,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () async {
                    await setClipboardTextSafely(
                      'npm install -g happy-coder@latest',
                    );
                    if (context.mounted) {
                      context.showSnack(
                        context.l10n.machineCompatibilityCopied,
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          Icons.system_update_alt_rounded,
                          color: cs.onTertiaryContainer,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.machineCompatibilityTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: cs.onTertiaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                context.l10n.machineCompatibilityMessage(
                                  cliVersion,
                                  minimumCliVersion,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onTertiaryContainer,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                context.l10n.machineCompatibilityAction,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: cs.onTertiaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),

            if (stats != null) ...[
              AppSectionHeader(title: 'Resources'),
              const SizedBox(height: AppSpacing.xs),
              _ResourceStatsList(stats: stats),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // ── Machine info ──
            AppSectionHeader(title: context.l10n.machineInfo),
            const SizedBox(height: AppSpacing.xs),
            _GroupedList(
              hasIcons: true,
              children: [
                if (metadata?.host != null)
                  _GroupedRow(
                    icon: Icons.dns_outlined,
                    label: context.l10n.machineHost,
                    value: metadata!.host!,
                  ),
                if (metadata?.username != null)
                  _GroupedRow(
                    icon: Icons.person_outline,
                    label: context.l10n.machineUsername,
                    value: metadata!.username!,
                  ),
                if (metadata?.platform != null)
                  _GroupedRow(
                    icon: Icons.computer_outlined,
                    label: context.l10n.machinePlatform,
                    value: metadata!.platform!,
                  ),
                if (metadata?.arch != null)
                  _GroupedRow(
                    icon: Icons.memory_outlined,
                    label: context.l10n.machineArchitecture,
                    value: metadata!.arch!,
                  ),
                if (metadata?.happyCliVersion != null)
                  _GroupedRow(
                    icon: Icons.code_outlined,
                    label: context.l10n.machineCliVersion,
                    value: metadata!.happyCliVersion!,
                    mono: true,
                  ),
                if (metadata?.homeDir != null)
                  _GroupedRow(
                    icon: Icons.folder_outlined,
                    label: context.l10n.machineHomeDir,
                    value: metadata!.homeDir!,
                    mono: true,
                  ),
                _GroupedRow(
                  icon: Icons.fingerprint,
                  label: context.l10n.machineMachineId,
                  value: widget.machineId,
                  mono: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── Daemon status ──
            AppSectionHeader(title: context.l10n.machineDaemon),
            const SizedBox(height: AppSpacing.xs),
            _GroupedList(
              hasIcons: true,
              children: [
                _GroupedRow(
                  icon: Icons.circle_outlined,
                  iconColor: isOnline ? AppColors.success : cs.onSurfaceVariant,
                  label: context.l10n.machineStatus,
                  value: isOnline
                      ? context.l10n.machineRunning
                      : context.l10n.machineStopped,
                  trailing: AppStatusDot(
                    color: isOnline ? AppColors.success : cs.onSurfaceVariant,
                    size: 8,
                    pulse: isOnline,
                  ),
                ),
                if (metadata?.daemonLastKnownStatus != null)
                  _GroupedRow(
                    icon: Icons.info_outline,
                    label: context.l10n.machineLastKnownStatus,
                    value: metadata!.daemonLastKnownStatus!,
                  ),
                if (metadata?.daemonLastKnownPid != null)
                  _GroupedRow(
                    icon: Icons.tag,
                    label: context.l10n.machineLastKnownPid,
                    value: metadata!.daemonLastKnownPid.toString(),
                    mono: true,
                  ),
              ],
            ),

            // ── Sessions ──
            if (machineSessions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              AppSectionHeader(
                title: context.l10n.machineSessions(machineSessions.length),
              ),
              const SizedBox(height: AppSpacing.xs),
              _GroupedList(
                children: [
                  for (int i = 0; i < machineSessions.length && i < 5; i++)
                    _SessionRow(
                      name: _getSessionName(machineSessions[i]),
                      subtitle: _getSessionSubtitle(machineSessions[i]),
                      isOnline: machineSessions[i].isPresenceOnline,
                      onTap: () =>
                          context.push('/chat/${machineSessions[i].id}'),
                    ),
                  if (machineSessions.length > 5)
                    _GroupedRow(
                      label: '',
                      value: '+ ${machineSessions.length - 5} more',
                      valueColor: cs.onSurfaceVariant,
                    ),
                ],
              ),
            ],

            // ── Delete button ──
            const SizedBox(height: AppSpacing.xxxl),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    _confirmDelete(context, widget.machineId, machineName),
                icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                label: Text(
                  context.l10n.machineRemoveMachine,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: cs.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status banner — prominent online/offline hero
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.isOnline, required this.lastSeen});

  final bool isOnline;
  final String lastSeen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = isOnline ? AppColors.success : cs.onSurfaceVariant;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          AppStatusDot(color: statusColor, size: 10, pulse: isOnline),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline
                      ? context.l10n.machineOnline
                      : context.l10n.machineOffline,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  isOnline
                      ? context.l10n.machineConnectedNow
                      : context.l10n.machineLastSeenAt(lastSeen),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _ResourceStatsList extends StatelessWidget {
  const _ResourceStatsList({required this.stats});

  final _MachineStats stats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ResourceRow(
            icon: Icons.speed_outlined,
            label: 'CPU',
            value: _formatPercent(stats.cpuPercent),
            percent: stats.cpuPercent,
          ),
          _ResourceDivider(),
          _ResourceRow(
            icon: Icons.memory_outlined,
            label: 'Memory',
            value:
                '${_formatPercent(stats.memoryPercent)}  '
                '${formatBytes(stats.memoryUsedBytes, adaptivePrecision: true)} / '
                '${formatBytes(stats.memoryTotalBytes, adaptivePrecision: true)}',
            percent: stats.memoryPercent,
          ),
          _ResourceDivider(),
          _ResourceRow(
            icon: Icons.storage_outlined,
            label: 'Disk',
            value:
                '${_formatPercent(stats.diskPercent)}  '
                '${formatBytes(stats.diskUsedBytes, adaptivePrecision: true)} / '
                '${formatBytes(stats.diskTotalBytes, adaptivePrecision: true)}',
            subtitle: stats.diskPath,
            percent: stats.diskPercent,
          ),
        ],
      ),
    );
  }
}

class _ResourceDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      indent: AppSpacing.lg + 36 + AppSpacing.md,
      color: cs.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.percent,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final double percent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final normalized = (percent / 100).clamp(0.0, 1.0).toDouble();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            SettingsIconContainer(icon: icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: normalized,
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPercent(double value) {
  if (value.isNaN || value.isInfinite) return '0%';
  return '${value.clamp(0, 100).toStringAsFixed(0)}%';
}

// ─────────────────────────────────────────────────────────────────────────────
// Card container for grouped rows
// ─────────────────────────────────────────────────────────────────────────────

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.children, this.hasIcons = false});

  final List<Widget> children;
  final bool hasIcons;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final indent = hasIcons
        ? AppSpacing.lg + 36 + AppSpacing.md
        : AppSpacing.lg;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: indent,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Key–value row inside a grouped list
// ─────────────────────────────────────────────────────────────────────────────

class _GroupedRow extends StatelessWidget {
  const _GroupedRow({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.mono = false,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final bool mono;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              SettingsIconContainer(icon: icon!, color: iconColor),
              const SizedBox(width: AppSpacing.md),
            ],
            if (label.isNotEmpty)
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            if (label.isNotEmpty) const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: mono ? 'monospace' : null,
                  fontSize: mono ? AppFontSize.md : null,
                  color: valueColor,
                  fontWeight: mono ? FontWeight.w500 : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session row inside a grouped list
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppTappable(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isOnline)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: AppStatusDot(
                    color: AppColors.success,
                    size: 7,
                    pulse: true,
                  ),
                ),
              Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
