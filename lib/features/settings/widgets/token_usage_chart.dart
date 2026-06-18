import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/claude_local_usage.dart';
import '../../../core/theme/app_tokens.dart';

/// Normalised daily token total used by the chart painter.
typedef _DayPoint = ({String date, int tokens});

/// A small interactive bar chart that visualises daily token usage over time.
///
/// Renders up to [maxDays] of daily totals as vertical bars, with a smooth
/// trend-line overlay and a tap tooltip.
class TokenUsageChart extends StatefulWidget {
  /// Creates a token usage chart.
  const TokenUsageChart({
    required this.dailyModelTokens,
    this.maxDays = 30,
    this.height = 220,
    super.key,
  });

  /// Per-model token totals per day.
  final List<ClaudeDailyModelTokens> dailyModelTokens;

  /// Maximum number of days to display.
  final int maxDays;

  /// Height of the chart area.
  final double height;

  @override
  State<TokenUsageChart> createState() => _TokenUsageChartState();
}

class _TokenUsageChartState extends State<TokenUsageChart> {
  int? _selectedIndex;

  List<_DayPoint> get _points {
    final slice = widget.dailyModelTokens.length > widget.maxDays
        ? widget.dailyModelTokens.sublist(
            widget.dailyModelTokens.length - widget.maxDays,
          )
        : widget.dailyModelTokens;
    return slice.map((d) {
      final total = d.tokensByModel.values.fold<int>(0, (a, b) => a + b);
      return (date: d.date, tokens: total);
    }).toList();
  }

  void _onTapDown(TapDownDetails details, BoxConstraints constraints) {
    final points = _points;
    if (points.isEmpty) return;

    final chartWidth = constraints.maxWidth - _TokenUsagePainter._marginLeft -
        _TokenUsagePainter._marginRight;
    final x = details.localPosition.dx - _TokenUsagePainter._marginLeft;
    final index = ((x / chartWidth) * points.length)
        .round()
        .clamp(0, points.length - 1);

    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (points.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (d) => _onTapDown(d, constraints),
          onTapUp: (_) => setState(() => _selectedIndex = null),
          onTapCancel: () => setState(() => _selectedIndex = null),
          child: CustomPaint(
            size: Size(constraints.maxWidth, widget.height),
            painter: _TokenUsagePainter(
              points: points,
              selectedIndex: _selectedIndex,
              colorScheme: Theme.of(context).colorScheme,
              textScale: MediaQuery.textScalerOf(context).scale(1),
            ),
          ),
        );
      },
    );
  }
}

/// Metrics row showing messages, sessions, and tool calls.
class TokenUsageMetrics extends StatelessWidget {
  /// Creates a metrics row.
  const TokenUsageMetrics({
    required this.usage,
    super.key,
  });

  /// The aggregated local usage.
  final ClaudeLocalUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.chat_bubble_outline,
              label: l10n.claudeLocalUsageMessages,
              value: ClaudeLocalUsage.formatTokenCount(usage.totalMessages),
              color: cs.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _MetricCard(
              icon: Icons.terminal_outlined,
              label: l10n.claudeLocalUsageSessions,
              value: ClaudeLocalUsage.formatTokenCount(usage.totalSessions),
              color: cs.tertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _MetricCard(
              icon: Icons.build_outlined,
              label: l10n.claudeLocalUsageToolCalls,
              value: ClaudeLocalUsage.formatTokenCount(usage.totalToolCalls),
              color: cs.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TokenUsagePainter extends CustomPainter {
  _TokenUsagePainter({
    required this.points,
    required this.colorScheme,
    this.selectedIndex,
    this.textScale = 1,
  });

  final List<_DayPoint> points;
  final ColorScheme colorScheme;
  final int? selectedIndex;
  final double textScale;

  static const double _marginLeft = 44;
  static const double _marginRight = 8;
  static const double _marginTop = 16;
  static const double _marginBottom = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTRB(
      _marginLeft,
      _marginTop,
      size.width - _marginRight,
      size.height - _marginBottom,
    );

    final maxTokens = points.map((p) => p.tokens).fold<int>(0, math.max);
    final yMax = maxTokens <= 0 ? 1 : maxTokens;

    _drawGridAndYAxis(canvas, chartRect, yMax);
    _drawBars(canvas, chartRect, yMax);
    _drawTrendLine(canvas, chartRect, yMax);
    _drawXAxis(canvas, chartRect);

    if (selectedIndex != null) {
      _drawSelection(canvas, chartRect, yMax, selectedIndex!);
    }
  }

  void _drawGridAndYAxis(Canvas canvas, Rect chartRect, int yMax) {
    final gridPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final labelStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.right,
      fontSize: 10 * textScale,
    );

    final steps = 3;
    for (var i = 0; i <= steps; i++) {
      final fraction = i / steps;
      final y = chartRect.bottom - fraction * chartRect.height;

      // Grid line.
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      // Y-axis label.
      final value = (yMax * fraction).round();
      final builder = ui.ParagraphBuilder(labelStyle)
        ..pushStyle(
          ui.TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10 * textScale,
          ),
        )
        ..addText(ClaudeLocalUsage.formatTokenCount(value));
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: _marginLeft - 8));
      canvas.drawParagraph(
        paragraph,
        Offset(0, y - paragraph.height / 2),
      );
    }
  }

  void _drawBars(Canvas canvas, Rect chartRect, int yMax) {
    final barWidth = chartRect.width / points.length;
    final gap = math.max(1.0, barWidth * 0.25);
    final fillWidth = math.max(2.0, barWidth - gap);

    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = chartRect.left + i * barWidth + gap / 2;
      final barHeight = (point.tokens / yMax) * chartRect.height;
      final top = chartRect.bottom - barHeight;

      final intensity = point.tokens == 0 ? 0.0 : point.tokens / yMax;
      basePaint.color = colorScheme.primary.withValues(
        alpha: 0.25 + (intensity * 0.55),
      );

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          top,
          fillWidth,
          math.max(0, barHeight),
        ),
        const Radius.circular(AppRadius.xs),
      );
      canvas.drawRRect(rect, basePaint);
    }
  }

  void _drawTrendLine(Canvas canvas, Rect chartRect, int yMax) {
    if (points.length < 2) return;

    final smoothed = _movingAverage(points, math.min(7, points.length));
    final path = Path();
    final barWidth = chartRect.width / points.length;

    for (var i = 0; i < smoothed.length; i++) {
      final x = chartRect.left + (i + (points.length - smoothed.length) / 2) *
          barWidth +
          barWidth / 2;
      final y = chartRect.bottom - (smoothed[i] / yMax) * chartRect.height;
      final point = Offset(x, y);

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        final prevX = chartRect.left +
            (i - 1 + (points.length - smoothed.length) / 2) * barWidth +
            barWidth / 2;
        final prevY = chartRect.bottom -
            (smoothed[i - 1] / yMax) * chartRect.height;
        final prev = Offset(prevX, prevY);
        final cp = Offset((prev.dx + point.dx) / 2, (prev.dy + point.dy) / 2);
        path
          ..quadraticBezierTo(prev.dx, prev.dy, cp.dx, cp.dy)
          ..lineTo(point.dx, point.dy);
      }
    }

    final linePaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  List<double> _movingAverage(List<_DayPoint> data, int window) {
    if (window <= 1) {
      return data.map((p) => p.tokens.toDouble()).toList();
    }
    final result = <double>[];
    for (var i = 0; i < data.length; i++) {
      final start = math.max(0, i - window + 1);
      var sum = 0;
      for (var j = start; j <= i; j++) {
        sum += data[j].tokens;
      }
      result.add(sum / (i - start + 1));
    }
    return result;
  }

  void _drawXAxis(Canvas canvas, Rect chartRect) {
    if (points.isEmpty) return;

    final labelStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: 10 * textScale,
    );

    final indices = <int>{
      0,
      points.length ~/ 2,
      points.length - 1,
    }.toList()..sort();

    final barWidth = chartRect.width / points.length;

    for (final i in indices) {
      final date = _formatDate(points[i].date);
      final x = chartRect.left + i * barWidth + barWidth / 2;

      final builder = ui.ParagraphBuilder(labelStyle)
        ..pushStyle(
          ui.TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10 * textScale,
          ),
        )
        ..addText(date);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: barWidth));
      canvas.drawParagraph(
        paragraph,
        Offset(x - paragraph.width / 2, chartRect.bottom + 6),
      );
    }
  }

  String _formatDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[1]}/${parts[2]}';
  }

  void _drawSelection(Canvas canvas, Rect chartRect, int yMax, int index) {
    final barWidth = chartRect.width / points.length;
    final x = chartRect.left + index * barWidth + barWidth / 2;
    final point = points[index];
    final y = chartRect.bottom - (point.tokens / yMax) * chartRect.height;

    // Highlight bar.
    final highlightPaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final gap = math.max(1.0, barWidth * 0.25);
    final fillWidth = math.max(2.0, barWidth - gap);
    final barHeight = (point.tokens / yMax) * chartRect.height;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        chartRect.left + index * barWidth + gap / 2,
        chartRect.bottom - barHeight,
        fillWidth,
        math.max(0, barHeight),
      ),
      const Radius.circular(AppRadius.xs),
    );
    canvas.drawRRect(rect, highlightPaint);

    // Tooltip text.
    final tooltipText = '${_formatDate(point.date)} · '
        '${ClaudeLocalUsage.formatTokenCount(point.tokens)}';
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: 11 * textScale,
    );
    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(
        ui.TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 11 * textScale,
          fontWeight: FontWeight.w600,
        ),
      )
      ..addText(tooltipText);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 120));

    final tooltipWidth = paragraph.width + 12;
    final tooltipHeight = paragraph.height + 8;
    var tooltipLeft = x - tooltipWidth / 2;
    tooltipLeft = tooltipLeft.clamp(4.0, chartRect.right - tooltipWidth - 4);
    final tooltipTop = (y - tooltipHeight - 10).clamp(
      chartRect.top + 4,
      chartRect.bottom - tooltipHeight - 4,
    );

    final tooltipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipLeft, tooltipTop, tooltipWidth, tooltipHeight),
      const Radius.circular(AppRadius.sm),
    );

    final bgPaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.fill;
    canvas
      ..drawRRect(tooltipRect, bgPaint)
      ..drawParagraph(
        paragraph,
        Offset(
          tooltipLeft + (tooltipWidth - paragraph.width) / 2,
          tooltipTop + (tooltipHeight - paragraph.height) / 2,
        ),
      );
  }

  @override
  bool shouldRepaint(covariant _TokenUsagePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.textScale != textScale;
  }
}
