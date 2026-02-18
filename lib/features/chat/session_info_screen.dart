import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/session_utils.dart';

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
        appBar: AppBar(title: const Text('Session Info')),
        body: const Center(child: Text('Session not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Session Info')),
      body: _SessionInfoBody(session: session),
    );
  }
}

class _SessionInfoBody extends StatelessWidget {
  const _SessionInfoBody({required this.session});

  final Session session;

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final meta = session.metadata;

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
                _StatusChip(isActive: session.active),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Session details section
        const _SectionTitle(title: 'Session Details'),
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
                label: 'Session ID',
                value: '${session.id.substring(0, 8)}...'
                    '${session.id.substring(session.id.length - 8)}',
                onTap: () => _copyToClipboard(context, session.id),
              ),
              const Divider(height: 1, indent: 52),
              _InfoRow(
                icon: Icons.access_time,
                label: 'Created',
                value: _formatDate(session.createdAt),
              ),
              const Divider(height: 1, indent: 52),
              _InfoRow(
                icon: Icons.update,
                label: 'Last Updated',
                value: _formatDate(session.updatedAt),
              ),
              const Divider(height: 1, indent: 52),
              _InfoRow(
                icon: Icons.tag,
                label: 'Sequence',
                value: session.seq.toString(),
              ),
            ],
          ),
        ),

        // Metadata section
        if (meta != null) ...[
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Metadata'),
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
                  label: 'Host',
                  value: meta.host,
                ),
                if (meta.path != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.folder_outlined,
                    label: 'Path',
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
                    label: 'Machine ID',
                    value: meta.machineId!,
                    onTap: () => _copyToClipboard(
                      context,
                      meta.machineId!,
                    ),
                  ),
                ],
                if (meta.os != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.memory,
                    label: 'OS',
                    value: formatOSPlatform(meta.os),
                  ),
                ],
                if (meta.version != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.verified_outlined,
                    label: 'CLI Version',
                    value: meta.version!,
                  ),
                ],
                if (meta.flavor != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.auto_awesome,
                    label: 'AI Provider',
                    value: _formatFlavor(meta.flavor),
                  ),
                ],
                if (meta.hostPid != null) ...[
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.terminal,
                    label: 'Process ID',
                    value: meta.hostPid!.toString(),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Tools section
        if (meta?.tools != null && meta!.tools!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Tools'),
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
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  String _formatFlavor(String? flavor) {
    if (flavor == null) return 'Unknown';
    if (flavor == 'claude') return 'Claude';
    if (flavor == 'gpt' || flavor == 'openai') return 'Codex';
    if (flavor == 'gemini') return 'Gemini';
    return flavor;
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isActive ? Colors.green : Colors.grey,
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
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary,
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
