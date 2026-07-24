import 'package:flutter/material.dart';

import '../../core/services/http_request_logger.dart';
import '../../core/services/power_diagnostics_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/utils/snack.dart';

class PowerDiagnosticsScreen extends StatefulWidget {
  const PowerDiagnosticsScreen({super.key});

  @override
  State<PowerDiagnosticsScreen> createState() => _PowerDiagnosticsScreenState();
}

class _PowerDiagnosticsScreenState extends State<PowerDiagnosticsScreen> {
  final PowerDiagnosticsService _diagnostics = powerDiagnostics;

  @override
  void initState() {
    super.initState();
    _diagnostics.addListener(_onDiagnosticsChanged);
  }

  @override
  void dispose() {
    _diagnostics.removeListener(_onDiagnosticsChanged);
    super.dispose();
  }

  void _onDiagnosticsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _copyReport() async {
    await setClipboardTextSafely(_diagnostics.exportText());
    if (!mounted) return;
    context.showSnack('Power diagnostics copied');
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reset diagnostics?'),
          content: const Text(
            'This clears counters and recent diagnostic events.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (ok ?? false) {
      _diagnostics.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _diagnostics.snapshot();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy report',
            onPressed: _copyReport,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: ListView(
        padding: AppScreenPadding.settings,
        children: [
          _SummaryHeader(snapshot: snapshot),
          const SizedBox(height: AppSpacing.lg),
          _ActivityChartCard(snapshot: snapshot),
          const SizedBox(height: AppSpacing.lg),
          _MetricSection(
            title: 'Lifecycle',
            metrics: [
              _Metric('Runtime', snapshot.runtimeLabel),
              _Metric('Transitions', snapshot.lifecycleTransitions.toString()),
              _Metric('Resumes', snapshot.resumeCount.toString()),
              _Metric('Suspends', snapshot.suspendCount.toString()),
              _Metric(
                'Rapid cycles',
                snapshot.rapidLifecycleWarnings.toString(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _MetricSection(
            title: 'Socket',
            metrics: [
              _Metric('Connects', snapshot.socketConnects.toString()),
              _Metric('Disconnects', snapshot.socketDisconnects.toString()),
              _Metric('Errors', snapshot.socketErrors.toString()),
              _Metric('Inbound events', snapshot.socketEvents.toString()),
              _Metric('Sends', snapshot.socketSends.toString()),
              _Metric('Ack calls', snapshot.socketAckCalls.toString()),
            ],
          ),
          if (snapshot.socketEventCounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _CountBreakdownSection(
              title: 'Socket Event Types',
              counts: snapshot.socketEventCounts,
            ),
          ],
          if (snapshot.socketUpdateTypeCounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _CountBreakdownSection(
              title: 'Socket Update Types',
              counts: snapshot.socketUpdateTypeCounts,
            ),
          ],
          if (snapshot.socketAckCounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _CountBreakdownSection(
              title: 'Socket Ack Calls',
              counts: snapshot.socketAckCounts,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _MetricSection(
            title: 'HTTP',
            metrics: [
              _Metric('Requests', snapshot.httpRequests.toString()),
              _Metric('Failures', snapshot.httpFailures.toString()),
              _Metric('Slow requests', snapshot.httpSlowRequests.toString()),
              _Metric(
                'Sent',
                HttpRequestEntry.formatBytes(snapshot.httpRequestBytes),
              ),
              _Metric(
                'Received',
                HttpRequestEntry.formatBytes(snapshot.httpResponseBytes),
              ),
            ],
          ),
          if (snapshot.httpEndpointStats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _HttpEndpointSection(stats: snapshot.httpEndpointStats),
          ],
          const SizedBox(height: AppSpacing.lg),
          _MetricSection(
            title: 'Sync and Outbox',
            metrics: [
              _Metric(
                'Sync invalidations',
                snapshot.syncInvalidations.toString(),
              ),
              _Metric(
                'Global invalidations',
                snapshot.globalSyncInvalidations.toString(),
              ),
              _Metric(
                'Background skips',
                snapshot.syncBackgroundSkips.toString(),
              ),
              _Metric('Outbox schedules', snapshot.outboxSchedules.toString()),
              _Metric('Outbox attempts', snapshot.outboxAttempts.toString()),
              _Metric('Outbox failures', snapshot.outboxFailures.toString()),
            ],
          ),
          if (snapshot.syncInvalidationCounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _CountBreakdownSection(
              title: 'Sync Invalidations',
              counts: snapshot.syncInvalidationCounts,
            ),
          ],
          if (snapshot.syncBackgroundSkipCounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _CountBreakdownSection(
              title: 'Sync Background Skips',
              counts: snapshot.syncBackgroundSkipCounts,
            ),
          ],
          if (snapshot.lifecycleStateCounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _CountBreakdownSection(
              title: 'Lifecycle States',
              counts: snapshot.lifecycleStateCounts,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _EventsSection(events: snapshot.recentEvents),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _CountBreakdownSection extends StatelessWidget {
  const _CountBreakdownSection({required this.title, required this.counts});

  final String title;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return _MetricSection(
      title: title,
      metrics: [
        for (final entry in sorted.take(8))
          _Metric(entry.key, entry.value.toString()),
      ],
    );
  }
}

class _HttpEndpointSection extends StatelessWidget {
  const _HttpEndpointSection({required this.stats});

  final Map<String, PowerDiagnosticHttpEndpointStats> stats;

  @override
  Widget build(BuildContext context) {
    final sorted = stats.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.count.compareTo(a.value.count);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return _MetricSection(
      title: 'HTTP Endpoints',
      metrics: [
        for (final entry in sorted.take(8))
          _Metric(
            entry.key,
            'n=${entry.value.count} '
            'avg=${entry.value.averageDurationMs}ms '
            'slow=${entry.value.slowRequests}',
          ),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.snapshot});

  final PowerDiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final busyScore =
        snapshot.httpRequests +
        snapshot.socketEvents +
        snapshot.syncInvalidations +
        snapshot.outboxAttempts;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagnostic window',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${snapshot.runtimeLabel} since '
            '${snapshot.startedAt.toLocal()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Pill(label: 'Busy signals', value: busyScore.toString()),
              _Pill(
                label: 'Socket errors',
                value: snapshot.socketErrors.toString(),
              ),
              _Pill(
                label: 'HTTP failures',
                value: snapshot.httpFailures.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityChartCard extends StatelessWidget {
  const _ActivityChartCard({required this.snapshot});

  final PowerDiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final samples = snapshot.activitySeries;
    final peak = samples.fold<int>(0, (m, s) => s.total > m ? s.total : m);
    final minutes = snapshot.runtime.inMinutes;
    final ratePerMin = minutes == 0
        ? 0.0
        : samples.fold<int>(0, (m, s) => m + s.total) / minutes;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity over time',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Radio wakeups per 2-min bucket. Bars, not bytes — '
                        'mobile power scales with request count and tail '
                        'duration, so a tall red spike drains more than a '
                        'long one of any color.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Pill(label: 'Peak/bucket', value: peak.toString()),
                    if (minutes > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _Pill(
                        label: 'Avg/min',
                        value: ratePerMin.toStringAsFixed(1),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _legendDot(context, cs.primary, 'Socket'),
                _legendDot(context, cs.error, 'RPC'),
                _legendDot(context, cs.tertiary, 'HTTP'),
                _legendDot(context, cs.secondary, 'Sync'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (samples.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'Collecting activity… check back after a minute of use.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              )
            else
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ActivityPainter(
                    samples: samples,
                    startMs: snapshot.startedAt.millisecondsSinceEpoch,
                    endMs: snapshot.generatedAt.millisecondsSinceEpoch,
                    bucketMs: PowerDiagnosticsSnapshot.activityBucketMs,
                    socketColor: cs.primary,
                    rpcColor: cs.error,
                    httpColor: cs.tertiary,
                    syncColor: cs.secondary,
                    baseline: cs.outlineVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ActivityPainter extends CustomPainter {
  const _ActivityPainter({
    required this.samples,
    required this.startMs,
    required this.endMs,
    required this.bucketMs,
    required this.socketColor,
    required this.rpcColor,
    required this.httpColor,
    required this.syncColor,
    required this.baseline,
  });

  final List<PowerDiagnosticSample> samples;
  final int startMs;
  final int endMs;
  final int bucketMs;
  final Color socketColor;
  final Color rpcColor;
  final Color httpColor;
  final Color syncColor;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final span = (endMs - startMs).clamp(1, 1 << 40);
    final peak = samples.fold<int>(1, (m, s) => s.total > m ? s.total : m);
    final pxPerMs = size.width / span;
    final barWidthPx = (bucketMs * pxPerMs).clamp(1.0, size.width);
    final baseY = size.height - 1;

    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    final paint = Paint()..style = PaintingStyle.fill;
    final usableHeight = size.height - 2;

    for (final s in samples) {
      final frac = ((s.bucketStartMs - startMs) / span).clamp(0.0, 1.0);
      final x = frac * size.width;
      var y = baseY;
      void bar(int value, Color color) {
        if (value == 0) return;
        final h = (value / peak) * usableHeight;
        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(x, y - h, barWidthPx, h), paint);
        y -= h;
      }

      // Stack bottom -> top: socket, http, rpc, sync.
      bar(s.socket, socketColor);
      bar(s.http, httpColor);
      bar(s.rpc, rpcColor);
      bar(s.sync, syncColor);
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityPainter old) {
    return old.endMs != endMs ||
        old.startMs != startMs ||
        old.samples.length != samples.length ||
        (old.samples.isNotEmpty &&
            old.samples.last.bucketStartMs != samples.last.bucketStartMs);
  }
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({required this.title, required this.metrics});

  final String title;
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final metric in metrics) _MetricRow(metric: metric),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              metric.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            metric.value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsSection extends StatelessWidget {
  const _EventsSection({required this.events});

  final List<PowerDiagnosticEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final latestEvents = events.reversed.take(80).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Events',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (latestEvents.isEmpty)
              Text(
                'No diagnostic events recorded yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            else
              for (final event in latestEvents) _EventRow(event: event),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final PowerDiagnosticEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final time = event.timestamp.toLocal();
    final timestamp =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
    final route = event.route == null ? '' : '  ${event.route}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$timestamp ${event.type.name}$route',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(event.message, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          '$label: $value',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}
