import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Floating pill above the chat input shown when the agent is
/// running tools silently — [isThinking] is true but no text
/// bubble is streaming yet.
///
/// Only appears after [_kShowDelay] (4 s) to avoid flashing on
/// fast tool calls. Fades in and out smoothly.
///
/// Displays:
/// - A pulsing green dot (alive signal)
/// - The most recent tool name (humanized), or "Working…"
/// - An elapsed timer counting up from when thinking started
class ThinkingPill extends StatefulWidget {
  const ThinkingPill({
    required this.isThinking,
    required this.isTextStreaming,
    super.key,
    this.lastToolName,
    this.thinkingAt,
    this.subAgentToolName,
    this.subAgentStartedAt,
    this.onStop,
  });

  /// Whether the agent is currently in the thinking state.
  final bool isThinking;

  /// True when a text bubble is already streaming — the pill
  /// should hide because content is already visible.
  final bool isTextStreaming;

  /// Name of the most recently executing tool call.
  final String? lastToolName;

  /// Unix-ms timestamp of when thinking started.
  final int? thinkingAt;

  /// Name of the tool the most-recent sub-agent is running, if any.
  ///
  /// Distinct from [lastToolName] (which is the most recent main-agent
  /// tool). When set, the pill stays visible even after the main agent
  /// finishes "thinking" — because in dynamic-workflow dispatches the
  /// CLI only emits `task_progress` meta events for sub-agents, so the
  /// wire never reports a main-agent tool call while the workflow runs.
  final String? subAgentToolName;

  /// Unix-ms timestamp of when the current sub-agent activity started.
  /// Drives the elapsed counter when the pill is showing sub-agent work.
  final int? subAgentStartedAt;

  /// Optional stop/abort action shown on the pill so the user does
  /// not have to open the session menu mid-run.
  final VoidCallback? onStop;

  @override
  State<ThinkingPill> createState() => _ThinkingPillState();
}

class _ThinkingPillState extends State<ThinkingPill>
    with SingleTickerProviderStateMixin {
  static const _kShowDelay = Duration(seconds: 4);

  late final AnimationController _dotCtrl;
  late final Animation<double> _dotPulse;

  Timer? _showTimer;
  Timer? _elapsedTimer;
  bool _visible = false;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _dotPulse = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut),
    );
    _syncState();
  }

  @override
  void didUpdateWidget(ThinkingPill old) {
    super.didUpdateWidget(old);
    if (widget.isThinking != old.isThinking ||
        widget.isTextStreaming != old.isTextStreaming ||
        widget.subAgentToolName != old.subAgentToolName) {
      _syncState();
    }
  }

  bool get _shouldShow {
    if (widget.isTextStreaming) return false;
    if (widget.isThinking) return true;
    final sub = widget.subAgentToolName;
    return sub != null && sub.isNotEmpty;
  }

  void _syncState() {
    if (_shouldShow) {
      _showTimer ??= Timer(_kShowDelay, () {
        if (!mounted || !_shouldShow) return;
        setState(() => _visible = true);
        _startElapsedTimer();
      });
    } else {
      _showTimer?.cancel();
      _showTimer = null;
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      if (_visible) setState(() => _visible = false);
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedSeconds = _currentElapsed();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds = _currentElapsed());
    });
  }

  int _currentElapsed() {
    final at = widget.isThinking
        ? widget.thinkingAt
        : widget.subAgentStartedAt;
    if (at == null) return 0;
    return ((DateTime.now().millisecondsSinceEpoch - at) / 1000)
        .floor()
        .clamp(0, 9999);
  }

  String _formatElapsed(int s) {
    if (s < 60) return '${s}s';
    return '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
  }

  String _label() {
    final tool = widget.subAgentToolName ?? widget.lastToolName;
    if (tool == null || tool.isEmpty) return 'Working…';
    // CamelCase → spaced words, then capitalise first letter.
    final spaced = tool
        .replaceAllMapped(
          RegExp(r'(?<=[a-z])(?=[A-Z])'),
          (_) => ' ',
        )
        .replaceAll('_', ' ')
        .trim();
    if (spaced.isEmpty) return '$tool…';
    final s = spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
    return '$s…';
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _showTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: AppDuration.slow,
      curve: AppCurve.standard,
      child: IgnorePointer(
        ignoring: !_visible,
        child: _visible ? _buildContent(context) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xsm,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHigh
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              width: AppBorder.hairline,
            ),
            boxShadow: AppShadow.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _dotPulse,
                builder: (context, child) => Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(
                      alpha: _dotPulse.value,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(
                          alpha: _dotPulse.value * 0.45,
                        ),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  _label(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_elapsedSeconds > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _formatElapsed(_elapsedSeconds),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              if (widget.onStop != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Semantics(
                  button: true,
                  label: 'Stop agent',
                  child: InkWell(
                    onTap: widget.onStop,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: AppTouchTarget.min,
                        minHeight: AppTouchTarget.min,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.stop_rounded,
                          size: 16,
                          color: cs.error,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
