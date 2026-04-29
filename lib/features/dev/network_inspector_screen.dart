import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/http_request_logger.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/utils/datetime_extensions.dart';

/// Debug screen that shows all HTTP requests made by [ApiClient].
class NetworkInspectorScreen extends StatefulWidget {
  const NetworkInspectorScreen({super.key});

  @override
  State<NetworkInspectorScreen> createState() => _NetworkInspectorScreenState();
}

class _NetworkInspectorScreenState extends State<NetworkInspectorScreen> {
  late List<HttpRequestEntry> _entries;
  StreamSubscription<List<HttpRequestEntry>>? _sub;

  @override
  void initState() {
    super.initState();
    _entries = List.of(httpRequestLogger.entries);
    _sub = httpRequestLogger.onChanged.listen((entries) {
      if (!mounted) return;
      setState(() => _entries = List.of(entries));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _buildCopyText() {
    final requestBytes = HttpRequestEntry.formatBytes(
      httpRequestLogger.totalRequestBytes,
    );
    final responseBytes = HttpRequestEntry.formatBytes(
      httpRequestLogger.totalResponseBytes,
    );
    final buf = StringBuffer()
      ..writeln('=== HTTP Request Log ===')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln(
        'Total: ${_entries.length} requests  '
        '↑ $requestBytes  '
        '↓ $responseBytes',
      )
      ..writeln()
      ..writeln(
        '${'#'.padRight(5)}'
        '${'TIMESTAMP'.padRight(28)}'
        '${'METHOD'.padRight(8)}'
        '${'STATUS'.padRight(8)}'
        '${'↑ REQ'.padLeft(9)}'
        '${'↓ RES'.padLeft(9)}'
        '${'DUR'.padLeft(8)}'
        '  PATH',
      )
      ..writeln('-' * 90);
    for (final e in _entries) {
      final num = e.id.toString().padRight(5);
      final ts = e.timestamp.toIso8601String().padRight(28);
      final method = e.method.padRight(8);
      final status = (e.statusCode?.toString() ?? '???').padRight(8);
      final reqB = HttpRequestEntry.formatBytes(e.requestBytes).padLeft(9);
      final resB = HttpRequestEntry.formatBytes(e.responseBytes).padLeft(9);
      final dur = e.durationMs != null
          ? '${e.durationMs}ms'.padLeft(8)
          : '       -';
      buf.writeln('$num$ts$method$status$reqB$resB$dur  ${e.path}');
    }
    return buf.toString();
  }

  Future<void> _copyAll() async {
    if (_entries.isEmpty) return;
    await setClipboardTextSafely(_buildCopyText());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_entries.length} requests copied')),
      );
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.networkInspectorClearTitle),
          content: Text(l10n.networkInspectorClearConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.developerClearCacheAction),
            ),
          ],
        );
      },
    );
    if (ok ?? false) {
      httpRequestLogger.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalReqB = httpRequestLogger.totalRequestBytes;
    final totalResB = httpRequestLogger.totalResponseBytes;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkInspectorTitle(_entries.length)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.networkInspectorCopyAll,
            onPressed: _entries.isEmpty ? null : _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: l10n.commonClear,
            onPressed: _entries.isEmpty ? null : _confirmClear,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary bar ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.smd,
            ),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Wrap(
              spacing: 24,
              runSpacing: 4,
              children: [
                _SummaryChip(
                  label: l10n.networkInspectorLabelRequests,
                  value: _entries.length.toString(),
                  icon: Icons.swap_horiz,
                ),
                _SummaryChip(
                  label: l10n.networkInspectorLabelSent,
                  value: HttpRequestEntry.formatBytes(totalReqB),
                  icon: Icons.upload,
                ),
                _SummaryChip(
                  label: l10n.networkInspectorLabelReceived,
                  value: HttpRequestEntry.formatBytes(totalResB),
                  icon: Icons.download,
                ),
              ],
            ),
          ),
          // ── Copy box ────────────────────────────────────────────
          if (_entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: _CopyBox(onCopy: _copyAll),
            ),
          // ── Request list ────────────────────────────────────────
          Expanded(
            child: _entries.isEmpty
                ? AppEmptyState(
                    icon: Icons.network_check,
                    title: AppLocalizations.of(
                      context,
                    ).networkInspectorNoRequests,
                    subtitle: AppLocalizations.of(
                      context,
                    ).networkInspectorNoRequestsSubtitle,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.xxl,
                    ),
                    // newest first
                    itemCount: _entries.length,
                    itemBuilder: (ctx, i) {
                      final e = _entries[_entries.length - 1 - i];
                      return _RequestRow(entry: e, isEven: i.isEven);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CopyBox extends StatelessWidget {
  const _CopyBox({required this.onCopy});
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: AppOpacity.half),
        borderRadius: BorderRadius.circular(AppRadius.smd),
        border: Border.all(
          color: cs.outline.withValues(alpha: AppOpacity.medium),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.smd,
      ),
      child: Row(
        children: [
          Icon(Icons.share, size: AppSpacing.lg, color: cs.primary),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Text(
              AppLocalizations.of(context).networkInspectorCopyInstruction,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 16),
            label: Text(AppLocalizations.of(context).commonCopy),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              textStyle: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.entry, required this.isEven});

  final HttpRequestEntry entry;
  final bool isEven;

  Color _methodColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (entry.method.toUpperCase()) {
      case 'GET':
        return cs.primary;
      case 'POST':
        return AppColors.success;
      case 'PUT':
      case 'PATCH':
        return AppColors.warning;
      case 'DELETE':
        return cs.error;
      default:
        return cs.outline;
    }
  }

  Color _statusColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = entry.statusCode;
    if (s == null) return cs.outline;
    if (s >= 200 && s < 300) return AppColors.success;
    if (s >= 300 && s < 400) return cs.primary;
    if (s >= 400 && s < 500) return AppColors.warning;
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mColor = _methodColor(context);
    final sColor = _statusColor(context);
    final time = entry.timestamp.toIsoTimeString();

    return InkWell(
      onTap: () => _showDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        color: isEven
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerLowest,
        child: Row(
          children: [
            // Time
            SizedBox(
              width: 80,
              child: Text(
                time,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xsm),
            _Badge(label: entry.method, color: mColor, width: 50),
            const SizedBox(width: AppSpacing.xsm),
            _Badge(
              label: entry.statusCode?.toString() ?? '???',
              color: sColor,
              width: 38,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                entry.path,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              HttpRequestEntry.formatBytes(entry.responseBytes),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: AppSpacing.xsm),
            if (entry.durationMs != null)
              Text(
                '${entry.durationMs}ms',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFamily: 'monospace',
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final e = entry;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Row(
              children: [
                _Badge(
                  label: e.method,
                  color: _methodColor(context),
                  width: 56,
                ),
                const SizedBox(width: AppSpacing.sm),
                _Badge(
                  label: e.statusCode?.toString() ?? '???',
                  color: _statusColor(context),
                  width: 44,
                ),
                const Spacer(),
                Text(
                  e.timestamp.toIso8601String(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              e.path,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: AppFontSize.md,
              ),
            ),
            const Divider(height: AppSpacing.xxl),
            _DetailRow(
              label: AppLocalizations.of(ctx).networkInspectorLabelDuration,
              value: e.durationMs != null ? '${e.durationMs} ms' : '-',
            ),
            _DetailRow(
              label: AppLocalizations.of(ctx).networkInspectorLabelSentBody,
              value: HttpRequestEntry.formatBytes(e.requestBytes),
            ),
            _DetailRow(
              label: AppLocalizations.of(ctx).networkInspectorLabelReceivedBody,
              value: HttpRequestEntry.formatBytes(e.responseBytes),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(AppLocalizations.of(context).devLogsCopyEntry),
                onPressed: () async {
                  await setClipboardTextSafely(e.toFormattedString());
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          ).networkInspectorEntryCopied,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.width});

  final String label;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withValues(alpha: AppOpacity.medium)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
