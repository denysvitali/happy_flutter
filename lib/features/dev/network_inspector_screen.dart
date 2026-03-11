import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/http_request_logger.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/datetime_extensions.dart';

/// Debug screen that shows all HTTP requests made by [ApiClient].
class NetworkInspectorScreen extends StatefulWidget {
  const NetworkInspectorScreen({super.key});

  @override
  State<NetworkInspectorScreen> createState() =>
      _NetworkInspectorScreenState();
}

class _NetworkInspectorScreenState
    extends State<NetworkInspectorScreen> {
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
    final buf = StringBuffer()
      ..writeln('=== HTTP Request Log ===')
      ..writeln(
        'Generated: ${DateTime.now().toIso8601String()}',
      )
      ..writeln(
        'Total: ${_entries.length} requests  '
        '↑ ${HttpRequestEntry.formatBytes(
          httpRequestLogger.totalRequestBytes,
        )}  '
        '↓ ${HttpRequestEntry.formatBytes(
          httpRequestLogger.totalResponseBytes,
        )}',
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
      final status =
          (e.statusCode?.toString() ?? '???').padRight(8);
      final reqB =
          HttpRequestEntry.formatBytes(e.requestBytes).padLeft(9);
      final resB =
          HttpRequestEntry.formatBytes(e.responseBytes).padLeft(9);
      final dur = e.durationMs != null
          ? '${e.durationMs}ms'.padLeft(8)
          : '       -';
      buf.writeln(
        '$num$ts$method$status$reqB$resB$dur  ${e.path}',
      );
    }
    return buf.toString();
  }

  Future<void> _copyAll() async {
    if (_entries.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _buildCopyText()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_entries.length} requests copied'),
        ),
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
                foregroundColor:
                    Theme.of(context).colorScheme.error,
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
              horizontal: 16,
              vertical: 10,
            ),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
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
                  value:
                      HttpRequestEntry.formatBytes(totalResB),
                  icon: Icons.download,
                ),
              ],
            ),
          ),
          // ── Copy box ────────────────────────────────────────────
          if (_entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _CopyBox(onCopy: _copyAll),
            ),
          // ── Request list ────────────────────────────────────────
          Expanded(
            child: _entries.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      top: 8,
                      bottom: 24,
                    ),
                    // newest first
                    itemCount: _entries.length,
                    itemBuilder: (ctx, i) {
                      final e = _entries[
                          _entries.length - 1 - i];
                      return _RequestRow(
                        entry: e,
                        isEven: i.isEven,
                      );
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Row(
        children: [
          Icon(
            Icons.share,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context).networkInspectorCopyInstruction,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 16),
            label: Text(AppLocalizations.of(context).commonCopy),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              textStyle:
                  theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.network_check,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).networkInspectorNoRequests,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)
                .networkInspectorNoRequestsSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.entry,
    required this.isEven,
  });

  final HttpRequestEntry entry;
  final bool isEven;

  Color _methodColor(BuildContext context) {
    switch (entry.method.toUpperCase()) {
      case 'GET':
        return Colors.blue;
      case 'POST':
        return Colors.green;
      case 'PUT':
      case 'PATCH':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  Color _statusColor(BuildContext context) {
    final s = entry.statusCode;
    if (s == null) return Theme.of(context).colorScheme.outline;
    if (s >= 200 && s < 300) return Colors.green;
    if (s >= 300 && s < 400) return Colors.blue;
    if (s >= 400 && s < 500) return Colors.orange;
    return Colors.red;
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
          horizontal: 12,
          vertical: 8,
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
            const SizedBox(width: 6),
            // Method badge
            _Badge(
              label: entry.method,
              color: mColor,
              width: 50,
            ),
            const SizedBox(width: 6),
            // Status badge
            _Badge(
              label: entry.statusCode?.toString() ?? '???',
              color: sColor,
              width: 38,
            ),
            const SizedBox(width: 8),
            // Path
            Expanded(
              child: Text(
                entry.path,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Response bytes
            Text(
              HttpRequestEntry.formatBytes(
                entry.responseBytes,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 6),
            // Duration
            if (entry.durationMs != null)
              Text(
                '${entry.durationMs}ms',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFamily: 'monospace',
                ),
              ),
            const SizedBox(width: 4),
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
            // ── Header ──────────────────────────────────────────
            Row(
              children: [
                _Badge(
                  label: e.method,
                  color: _methodColor(context),
                  width: 56,
                ),
                const SizedBox(width: 8),
                _Badge(
                  label:
                      e.statusCode?.toString() ?? '???',
                  color: _statusColor(context),
                  width: 44,
                ),
                const Spacer(),
                Text(
                  e.timestamp.toIso8601String(),
                  style:
                      Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              e.path,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
            ),
            const Divider(height: 24),
            // ── Metrics ─────────────────────────────────────────
            _DetailRow(
              label:
                  AppLocalizations.of(ctx).networkInspectorLabelDuration,
              value: e.durationMs != null
                  ? '${e.durationMs} ms'
                  : '-',
            ),
            _DetailRow(
              label: AppLocalizations.of(ctx).networkInspectorLabelSentBody,
              value: HttpRequestEntry.formatBytes(
                e.requestBytes,
              ),
            ),
            _DetailRow(
              label: AppLocalizations.of(ctx)
                  .networkInspectorLabelReceivedBody,
              value: HttpRequestEntry.formatBytes(
                e.responseBytes,
              ),
            ),
            const SizedBox(height: 20),
            // ── Copy button ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(
                  AppLocalizations.of(context).devLogsCopyEntry,
                ),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: e.toFormattedString(),
                    ),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
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
  const _Badge({
    required this.label,
    required this.color,
    required this.width,
  });

  final String label;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
