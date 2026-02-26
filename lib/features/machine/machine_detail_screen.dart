import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/components/app_section_header.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/components/app_tappable.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

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

class _MachineDetailScreenState
    extends ConsumerState<MachineDetailScreen> {
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(machinesNotifierProvider.notifier)
          .refreshFromSync();
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  bool _isMachineOnline(int activeAt) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const onlineThresholdMs = 60 * 1000;
    return now - activeAt < onlineThresholdMs;
  }

  String _formatTimestamp(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'just now';
  }

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.commonDelete),
        content: Text(
          'Are you sure you want to remove "$machineName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final response =
          await ApiClient().delete('/v1/machines/$machineId');
      if (!context.mounted) return;
      if (ApiClient().isSuccess(response)) {
        sync.machinesSync.invalidate();
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete machine (${response.statusCode})',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesNotifierProvider);
    final sessions = ref.watch(sessionsNotifierProvider);
    final machine = machines[widget.machineId];
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
    final machineName = metadata?.displayName ??
        metadata?.host ??
        machine.id;
    final isOnline = _isMachineOnline(machine.activeAt);

    // Sessions for this machine, sorted by most recently updated.
    final machineSessions = sessions.values
        .where((s) => s.metadata?.machineId == widget.machineId)
        .toList()
      ..sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

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
            const SizedBox(height: AppSpacing.xxl),

            // ── Machine info ──
            const AppSectionHeader(title: 'Info'),
            const SizedBox(height: AppSpacing.xs),
            _GroupedList(
              children: [
                if (metadata?.host != null)
                  _GroupedRow(
                    label: context.l10n.machineHost,
                    value: metadata!.host!,
                  ),
                if (metadata?.username != null)
                  _GroupedRow(
                    label: context.l10n.machineUsername,
                    value: metadata!.username!,
                  ),
                if (metadata?.platform != null)
                  _GroupedRow(
                    label: context.l10n.machinePlatform,
                    value: metadata!.platform,
                  ),
                if (metadata?.arch != null)
                  _GroupedRow(
                    label: context.l10n.machineArchitecture,
                    value: metadata!.arch!,
                  ),
                if (metadata?.happyCliVersion != null)
                  _GroupedRow(
                    label: context.l10n.machineCliVersion,
                    value: metadata!.happyCliVersion,
                    mono: true,
                  ),
                if (metadata?.homeDir != null)
                  _GroupedRow(
                    label: context.l10n.machineHomeDir,
                    value: metadata!.homeDir,
                    mono: true,
                  ),
                _GroupedRow(
                  label: context.l10n.machineMachineId,
                  value: widget.machineId,
                  mono: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── Daemon status ──
            const AppSectionHeader(title: 'Daemon'),
            const SizedBox(height: AppSpacing.xs),
            _GroupedList(
              children: [
                _GroupedRow(
                  label: context.l10n.machineStatus,
                  value: isOnline ? 'Running' : 'Stopped',
                  trailing: AppStatusDot(
                    color: isOnline
                        ? AppColors.success
                        : cs.onSurfaceVariant,
                    size: 8,
                    pulse: isOnline,
                  ),
                ),
                if (metadata?.daemonLastKnownStatus != null)
                  _GroupedRow(
                    label: context.l10n.machineLastKnownStatus,
                    value: metadata!.daemonLastKnownStatus!,
                  ),
                if (metadata?.daemonLastKnownPid != null)
                  _GroupedRow(
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
                title: 'Sessions (${machineSessions.length})',
              ),
              const SizedBox(height: AppSpacing.xs),
              _GroupedList(
                children: [
                  for (int i = 0;
                      i < machineSessions.length && i < 5;
                      i++)
                    _SessionRow(
                      name: _getSessionName(machineSessions[i]),
                      subtitle: _getSessionSubtitle(machineSessions[i]),
                      isOnline:
                          machineSessions[i].isPresenceOnline,
                      onTap: () => context.push(
                        '/chat/${machineSessions[i].id}',
                      ),
                    ),
                  if (machineSessions.length > 5)
                    _GroupedRow(
                      label: '',
                      value:
                          '+ ${machineSessions.length - 5} more',
                      valueColor: cs.onSurfaceVariant,
                    ),
                ],
              ),
            ],

            // ── Delete button ──
            const SizedBox(height: AppSpacing.xxxl),
            Center(
              child: TextButton(
                onPressed: () => _confirmDelete(
                  context,
                  widget.machineId,
                  machineName,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: cs.error,
                ),
                child: Text(
                  'Remove Machine',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
  const _StatusBanner({
    required this.isOnline,
    required this.lastSeen,
  });

  final bool isOnline;
  final String lastSeen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor =
        isOnline ? AppColors.success : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          AppStatusDot(
            color: statusColor,
            size: 10,
            pulse: isOnline,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  isOnline ? 'Connected now' : 'Last seen $lastSeen',
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

// ─────────────────────────────────────────────────────────────────────────────
// iOS-style grouped list container
// ─────────────────────────────────────────────────────────────────────────────

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 0.5,
                indent: AppSpacing.lg,
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
    this.mono = false,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ConstrainedBox(
      constraints:
          const BoxConstraints(minHeight: AppTouchTarget.min),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
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
            if (label.isNotEmpty)
              const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: mono ? 'monospace' : null,
                  fontSize: mono ? 13 : null,
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
        constraints:
            const BoxConstraints(minHeight: AppTouchTarget.min),
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
                        style:
                            theme.textTheme.bodySmall?.copyWith(
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
                  padding: const EdgeInsets.only(
                    right: AppSpacing.xs,
                  ),
                  child: AppStatusDot(
                    color: AppColors.success,
                    size: 7,
                    pulse: true,
                  ),
                ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
