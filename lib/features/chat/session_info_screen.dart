import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/session_utils.dart';

// Minimum CLI version required for full compatibility.
const _minimumCliVersion = '0.10.0';

/// Compares two semver strings.
/// Returns -1, 0, or 1 (like compareTo).
int _compareVersions(String v1, String v2) {
  String clean(String v) => v.split('-')[0];
  final p1 = clean(v1).split('.').map(int.tryParse).toList();
  final p2 = clean(v2).split('.').map(int.tryParse).toList();
  final len = p1.length > p2.length ? p1.length : p2.length;
  for (var i = 0; i < len; i++) {
    final a = i < p1.length ? (p1[i] ?? 0) : 0;
    final b = i < p2.length ? (p2[i] ?? 0) : 0;
    if (a > b) return 1;
    if (a < b) return -1;
  }
  return 0;
}

/// Returns true if [version] >= [minimum].
bool _isVersionSupported(String version) {
  try {
    return _compareVersions(version, _minimumCliVersion) >= 0;
  } catch (_) {
    return false;
  }
}

/// Screen that shows detailed info about a specific session.
class SessionInfoScreen extends ConsumerWidget {
  /// Creates a [SessionInfoScreen] for the given [sessionId].
  const SessionInfoScreen({required this.sessionId, super.key});

  /// The session ID to display info for.
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final session = sessions[sessionId];

    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.sessionInfoTitle),
        ),
        body: Center(child: Text(context.l10n.sessionInfoNotFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sessionInfoTitle)),
      body: _SessionInfoBody(session: session),
    );
  }
}

class _SessionInfoBody extends ConsumerStatefulWidget {
  const _SessionInfoBody({required this.session});

  final Session session;

  @override
  ConsumerState<_SessionInfoBody> createState() => _SessionInfoBodyState();
}

class _SessionInfoBodyState extends ConsumerState<_SessionInfoBody> {
  bool _isArchiving = false;
  bool _isDeleting = false;

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatFlavor(String? flavor, AppLocalizations l10n) {
    if (flavor == null) return l10n.commonUnknown;
    if (flavor == 'claude') return 'Claude';
    if (flavor == 'gpt' || flavor == 'openai') return 'Codex';
    if (flavor == 'gemini') return 'Gemini';
    return flavor;
  }

  void _copyToClipboard(String text, {String? message}) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? l10n.sessionInfoCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: cs.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleArchiveSession() async {
    final failedArchiveMsg = context.l10n.sessionsFailedToArchive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.sessionsArchiveSession),
          content: Text(l10n.sessionsArchiveConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.sessionsArchive),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isArchiving = true);
    try {
      await sync.killSession(widget.session.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _showError(failedArchiveMsg);
    } finally {
      if (mounted) setState(() => _isArchiving = false);
    }
  }

  Future<void> _handleDeleteSession() async {
    final failedDeleteMsg = context.l10n.sessionsFailedToDelete;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.chatDeleteSession),
          content: Text(l10n.sessionsDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    setState(() => _isDeleting = true);
    try {
      final deleted = await sync.deleteSession(widget.session.id);
      if (!mounted) return;
      if (deleted) {
        Navigator.of(context).pop();
      } else {
        _showError(failedDeleteMsg);
      }
    } catch (e) {
      _showError(failedDeleteMsg);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final session = widget.session;
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final meta = session.metadata;

    final isOnline = session.presence == 'online';
    final isCliOutdated = meta?.version != null &&
        !_isVersionSupported(meta!.version!);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.computer_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  sessionName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  sessionSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                _StatusChip(isActive: session.isOnline),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // CLI Version Outdated Warning
        if (isCliOutdated) ...[
          Card(
            elevation: 0,
            color: theme.colorScheme.tertiaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.tertiary,
                width: 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _copyToClipboard(
                'npm install -g happy-coder@latest',
                message: l10n.sessionInfoUpdateCommandCopied,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: theme.colorScheme.onTertiaryContainer,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.sessionInfoCliOutdated,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme
                                  .onTertiaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Run: npm install -g happy-coder@latest',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme
                                  .onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.copy_outlined,
                      color: theme.colorScheme.onTertiaryContainer,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Session details section
        _SectionTitle(title: l10n.sessionInfoSectionDetails),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.fingerprint,
                label: l10n.sessionInfoLabelSessionId,
                value: session.id.length > 16
                    ? '${session.id.substring(0, 8)}...'
                        '${session.id.substring(session.id.length - 8)}'
                    : session.id,
                onTap: () => _copyToClipboard(session.id),
              ),
              const Divider(height: 1, indent: 52),
              _InfoRow(
                icon: Icons.access_time,
                label: l10n.sessionInfoLabelCreated,
                value: _formatDate(session.createdAt),
              ),
              const Divider(height: 1, indent: 52),
              _InfoRow(
                icon: Icons.update,
                label: l10n.sessionInfoLabelLastUpdated,
                value: _formatDate(session.updatedAt),
              ),
              const Divider(height: 1, indent: 52),
              _InfoRow(
                icon: Icons.tag,
                label: l10n.sessionInfoLabelSequence,
                value: session.seq.toString(),
              ),
            ],
          ),
        ),

        // Quick Actions section
        const SizedBox(height: 16),
        _SectionTitle(title: l10n.sessionInfoSectionQuickActions),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (meta?.machineId != null) ...[
                _ActionRow(
                  icon: Icons.dns_outlined,
                  label: l10n.sessionInfoActionViewMachine,
                  color: theme.colorScheme.primary,
                  onTap: () =>
                      context.push('/machine/${meta!.machineId}'),
                ),
              ],
              if (meta?.machineId != null && (isOnline || !session.active))
                const Divider(height: 1, indent: 52),
              if (isOnline)
                _ActionRow(
                  icon: Icons.archive_outlined,
                  label: l10n.sessionInfoActionArchive,
                  color: theme.colorScheme.error,
                  isLoading: _isArchiving,
                  onTap: _isArchiving ? null : _handleArchiveSession,
                ),
              if (isOnline && !session.active)
                const Divider(height: 1, indent: 52),
              if (!session.active)
                _ActionRow(
                  icon: Icons.delete_outline,
                  label: l10n.sessionInfoActionDelete,
                  color: theme.colorScheme.error,
                  isLoading: _isDeleting,
                  onTap: _isDeleting ? null : _handleDeleteSession,
                ),
            ],
          ),
        ),

        // Metadata section
        if (meta != null) ...[
          const SizedBox(height: 16),
          _SectionTitle(title: l10n.sessionInfoSectionMetadata),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.computer,
                  label: l10n.sessionInfoLabelHost,
                  value: meta.host,
                ),
                if (meta.path != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.folder_outlined,
                    label: l10n.sessionInfoLabelPath,
                    value: formatPathRelativeToHome(
                      meta.path!,
                      homeDir: meta.homeDir,
                    ),
                  ),
                ],
                if (meta.machineId != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.dns_outlined,
                    label: l10n.sessionInfoLabelMachineId,
                    value: meta.machineId!,
                    onTap: () =>
                        _copyToClipboard(meta.machineId!),
                  ),
                ],
                if (meta.os != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.memory,
                    label: l10n.sessionInfoLabelOs,
                    value: formatOSPlatform(meta.os),
                  ),
                ],
                if (meta.version != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: isCliOutdated
                        ? Icons.warning_amber_outlined
                        : Icons.verified_outlined,
                    label: l10n.sessionInfoLabelCliVersion,
                    value: meta.version!,
                    iconColor: isCliOutdated
                        ? theme.colorScheme.tertiary
                        : null,
                  ),
                ],
                if (meta.flavor != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.auto_awesome,
                    label: l10n.sessionInfoLabelAiProvider,
                    value: _formatFlavor(meta.flavor, l10n),
                  ),
                ],
                if (meta.claudeSessionId != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.code_outlined,
                    label: l10n.sessionInfoLabelClaudeSessionId,
                    value: () {
                      final id = meta.claudeSessionId!;
                      return '${id.substring(0, 8)}...'
                          '${id.substring(id.length - 8)}';
                    }(),
                    onTap: () =>
                        _copyToClipboard(meta.claudeSessionId!),
                  ),
                ],
                if (meta.hostPid != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.terminal,
                    label: l10n.sessionInfoLabelProcessId,
                    value: meta.hostPid!.toString(),
                  ),
                ],
                if (meta.happyHomeDir != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.home_outlined,
                    label: l10n.sessionInfoLabelHappyHome,
                    value: formatPathRelativeToHome(
                      meta.happyHomeDir!,
                      homeDir: meta.homeDir,
                    ),
                  ),
                ],
                const Divider(height: 1, indent: 52),
                _ActionRow(
                  icon: Icons.copy_outlined,
                  label: l10n.sessionInfoActionCopyMetadata,
                  color: theme.colorScheme.primary,
                  onTap: () {
                    _copyToClipboard(
                      jsonEncode(meta.toJson()),
                      message: l10n.sessionInfoMetadataCopied,
                    );
                  },
                ),
              ],
            ),
          ),
        ],

        // Agent State section
        if (session.agentState != null) ...[
          const SizedBox(height: 16),
          _SectionTitle(title: l10n.sessionInfoSectionAgentState),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  label: l10n.sessionInfoLabelControlledByUser,
                  value: (session.agentState!.controlledByUser ?? false)
                      ? l10n.commonYes
                      : l10n.commonNo,
                ),
                if (session.agentState!.requests != null &&
                    session.agentState!.requests!.isNotEmpty) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.hourglass_empty_outlined,
                    label: l10n.sessionInfoLabelPendingRequests,
                    value:
                        session.agentState!.requests!.length.toString(),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Activity section
        const SizedBox(height: 16),
        _SectionTitle(title: l10n.sessionInfoSectionActivity),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.lightbulb_outline,
                label: l10n.sessionInfoLabelThinking,
                value: session.thinking ? l10n.commonYes : l10n.commonNo,
                iconColor: session.thinking
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              if (session.thinking &&
                  session.thinkingAt != null) ...[
                const Divider(height: 1, indent: 52),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  label: l10n.sessionInfoLabelThinkingSince,
                  value: _formatDate(session.thinkingAt!),
                  iconColor: theme.colorScheme.tertiary,
                ),
              ],
            ],
          ),
        ),

        // Tools section
        if (meta?.tools != null && meta!.tools!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle(title: l10n.sessionInfoSectionTools),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: meta.tools!.map((tool) {
                  return Chip(
                    label: Text(
                      tool,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = cs.primary;
    final inactiveColor = cs.onSurfaceVariant;
    final chipColor = isActive ? activeColor : inactiveColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: chipColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive
                ? AppLocalizations.of(context).sessionInfoActive
                : AppLocalizations.of(context).sessionInfoInactive,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.copy,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// A tappable action row used in Quick Actions and Copy Metadata.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 18,
                color: color.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }
}
