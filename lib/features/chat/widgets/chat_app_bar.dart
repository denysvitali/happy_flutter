import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../../loops/loop_count_badge.dart';
import '../../sessions/session_avatar.dart';
import 'agents_list_sheet.dart';
import 'chat_app_bar_status.dart';
import 'session_header_chip.dart';

// The chip model, the chip builder and the store fallback live in a sibling
// file (see chat_app_bar_status.dart); re-exported so existing callers can
// keep importing `chat_app_bar.dart` alone.
export 'chat_app_bar_status.dart';

/// App bar for the chat screen showing session title,
/// status, model info, and action buttons.
class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const ChatAppBar({
    required this.session,
    required this.sessionTitle,
    required this.statusChips,
    required this.onMenuTap,
    required this.onInfoTap,
    required this.sessionId,
    this.avatarStyle,
    this.machineVitals,
    this.onBackTap,
    super.key,
  });

  final Session? session;
  final String sessionTitle;
  final List<ChatAppBarStatusChip> statusChips;
  final VoidCallback onMenuTap;
  final VoidCallback onInfoTap;
  final String sessionId;
  final AvatarStyle? avatarStyle;
  final ChatMachineVitals? machineVitals;
  final VoidCallback? onBackTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    // Aurora glass chrome: near-opaque surface with a hairline glass seam so
    // content scrolling beneath reads through without a hard elevation step.
    return AppBar(
      automaticallyImplyLeading: onBackTap == null,
      leading: onBackTap == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: context.l10n.commonBack,
              onPressed: onBackTap,
            ),
      titleSpacing: AppSpacing.sm,
      title: _buildTitle(context, ref),
      backgroundColor: cs.surface.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      shape: Border(
        bottom: BorderSide(color: appCs.glassBorder, width: AppBorder.hairline),
      ),
      scrolledUnderElevation: 0.5,
      actions: [
        // Loop count badge — appears only when the session has loops.
        LoopCountBadge(sessionId: sessionId),
        // Agents list button with progress
        _AgentsListButton(
          progress: AgentsListSheet.computeTaskProgress(sessionId),
          sessionId: sessionId,
        ),
        if (machineVitals != null) _VitalsButton(vitals: machineVitals!),
        _AppBarAction(
          icon: Icons.info_outline_rounded,
          tooltip: context.l10n.chatSessionSettings,
          onPressed: onInfoTap,
        ),
        _AppBarAction(
          icon: Icons.more_horiz_rounded,
          tooltip: context.l10n.chatMoreOptions,
          onPressed: onMenuTap,
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }

  Widget _buildTitle(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final currentSession = effectiveChatAppBarSession(
      ref,
      loaded: session,
      sessionId: sessionId,
    );
    if (currentSession == null) {
      return Text(
        context.l10n.chatChat,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      );
    }

    // When the chat screen hasn't loaded the session yet, the caller's
    // `sessionTitle` / `statusChips` are still placeholders, so derive both
    // from the store-resolved session instead.
    final resolvedTitle = session != null
        ? sessionTitle
        : getSessionName(currentSession);
    final resolvedChips = session != null
        ? statusChips
        : chatAppBarFallbackChips(context, currentSession);
    final flavor = currentSession.metadata?.flavor;
    final avatarId = getSessionAvatarId(currentSession);

    return GestureDetector(
      onTap: onInfoTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          // Hairline ring frames the avatar against the glass chrome.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color:
                    (Theme.of(context).extension<AppColorScheme>() ??
                            AppColorScheme.dark())
                        .glassBorder,
                width: AppBorder.hairline,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: SessionAvatar(
              id: avatarId,
              flavor: flavor,
              size: 34,
              showFlavorIcon: true,
              square: true,
              style: avatarStyle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _TitleReveal(
              sessionTitle: resolvedTitle,
              statusChips: resolvedChips,
              textTheme: textTheme,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animates the session title and status row into view with a
/// delayed parallax effect that complements the Hero avatar flight.
///
/// The title slides up from a few pixels below and fades in during
/// the second half of the route enter transition
/// (interval 0.4–1.0), so it appears to "follow" the avatar
/// landing — creating a natural parallax reveal.
class _TitleReveal extends StatefulWidget {
  const _TitleReveal({
    required this.sessionTitle,
    required this.statusChips,
    required this.textTheme,
  });

  final String sessionTitle;
  final List<ChatAppBarStatusChip> statusChips;
  final TextTheme textTheme;

  @override
  State<_TitleReveal> createState() => _TitleRevealState();
}

class _TitleRevealState extends State<_TitleReveal> {
  // Animation driven by the page route's own animation, delayed with
  // an Interval so the text appears after the Hero avatar arrives.
  Animation<double>? _reveal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reveal != null) return; // already initialised

    final routeAnim = ModalRoute.of(context)?.animation;
    if (routeAnim == null) return;

    // Wrap the route animation in a CurvedAnimation restricted to
    // the 0.35–1.0 window so the title only appears in the latter
    // 65 % of the push transition — after the Hero has landed.
    _reveal = CurvedAnimation(
      parent: routeAnim,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.0, 0.6, curve: Curves.easeInCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reveal = _reveal;

    // If no route animation is available (e.g. tablets with an inline
    // master-detail layout), show the title immediately without animation.
    if (reveal == null) {
      return _buildContent(1.0);
    }

    return AnimatedBuilder(
      animation: reveal,
      builder: (context, _) => _buildContent(reveal.value),
    );
  }

  Widget _buildContent(double t) {
    // t goes 0 → 1 over the delayed interval.
    // Slide up 6 px → 0 and fade in.
    final offset = (1.0 - t) * 6.0;

    return Transform.translate(
      offset: Offset(0, offset),
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.sessionTitle,
              style: widget.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            _StatusRow(statusChips: widget.statusChips),
          ],
        ),
      ),
    );
  }
}

class ChatMachineVitals {
  const ChatMachineVitals({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.diskPercent,
  });

  final double cpuPercent;
  final double memoryPercent;
  final double diskPercent;

  static ChatMachineVitals? fromDaemonState(Map<String, dynamic>? daemonState) {
    final raw = daemonState?['machineStats'];
    if (raw is! Map) return null;

    final cpu = raw['cpu'];
    final memory = raw['memory'];
    final disk = raw['disk'];
    if (cpu is! Map || memory is! Map || disk is! Map) return null;

    return ChatMachineVitals(
      cpuPercent: _asPercent(cpu['usagePercent']),
      memoryPercent: _asPercent(memory['usagePercent']),
      diskPercent: _asPercent(disk['usagePercent']),
    );
  }

  static double _asPercent(dynamic value) {
    if (value is! num || value.isNaN || value.isInfinite) return 0;
    return value.toDouble().clamp(0, 100).toDouble();
  }
}

class _VitalsButton extends StatelessWidget {
  const _VitalsButton({required this.vitals});

  final ChatMachineVitals vitals;

  @override
  Widget build(BuildContext context) {
    final highest = [
      vitals.cpuPercent,
      vitals.memoryPercent,
      vitals.diskPercent,
    ].reduce((a, b) => a > b ? a : b);
    final cs = Theme.of(context).colorScheme;
    final color = highest >= 90
        ? AppColors.error
        : highest >= 75
        ? AppColors.warning
        : cs.onSurfaceVariant;
    return IconButton(
      onPressed: () => _showDetails(context),
      tooltip: 'Machine health',
      icon: Icon(Icons.monitor_heart_outlined, color: color),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Machine health',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _VitalPill(
                icon: Icons.speed_outlined,
                label: 'CPU',
                percent: vitals.cpuPercent,
              ),
              const SizedBox(height: AppSpacing.md),
              _VitalPill(
                icon: Icons.memory_outlined,
                label: 'MEM',
                percent: vitals.memoryPercent,
              ),
              const SizedBox(height: AppSpacing.md),
              _VitalPill(
                icon: Icons.storage_outlined,
                label: 'DISK',
                percent: vitals.diskPercent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VitalPill extends StatelessWidget {
  const _VitalPill({
    required this.icon,
    required this.label,
    required this.percent,
  });

  final IconData icon;
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final value = percent.clamp(0, 100).toDouble();
    final color = value >= 90
        ? AppColors.error
        : value >= 75
        ? AppColors.warning
        : cs.primary;

    return Tooltip(
      message: '$label ${value.toStringAsFixed(0)}%',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 4,
                color: color,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '${value.toStringAsFixed(0)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated status row that cross-fades between chip sets.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.statusChips});

  final List<ChatAppBarStatusChip> statusChips;

  @override
  Widget build(BuildContext context) {
    final chipKey = ValueKey(
      statusChips
          .map((chip) => '${chip.text}:${chip.icon.codePoint}')
          .join('|'),
    );
    return AnimatedSwitcher(
      duration: AppDuration.normal,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: statusChips.isEmpty
          ? const SizedBox.shrink(key: ValueKey('empty-status-row'))
          : SizedBox(
              key: chipKey,
              height: 22,
              // Chips keep their intrinsic width and the row scrolls when
              // they overrun the title column, under a trailing fade that
              // marks the cut. Sharing the width with `Flexible` truncated
              // every chip at once — two short chips rendered as "On…" and
              // "Th…" on a phone-width app bar — while flexing only the
              // last one overflowed the Row once three chips were present.
              child: _FadingEdge(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final (index, chip) in statusChips.indexed) ...[
                        if (index > 0) const SizedBox(width: AppSpacing.xs),
                        SessionHeaderChip(
                          text: chip.text,
                          tooltip: chip.text,
                          leading: chip.showDot
                              ? AppStatusDot(
                                  color: chip.color,
                                  pulse: chip.pulse,
                                  size: 6,
                                )
                              : Icon(chip.icon, size: 11, color: chip.color),
                          textColor: chip.color,
                          backgroundColor: chip.color.withValues(alpha: 0.08),
                          borderColor: chip.color.withValues(alpha: 0.16),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

}

/// Fades out the trailing edge of a horizontally scrollable strip so a chip
/// cut off by the app bar's width reads as "there is more", not as a
/// rendering glitch.
class _FadingEdge extends StatelessWidget {
  const _FadingEdge({required this.child});

  static const double _fadeWidth = 16;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= _fadeWidth * 2) return child;
        final solid = 1 - _fadeWidth / width;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [Colors.white, Colors.white, Colors.transparent],
            stops: [0, solid, 1],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// Compact action button for the app bar.
class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon),
      iconSize: 20,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: cs.onSurfaceVariant,
        padding: const EdgeInsets.all(AppSpacing.sm),
        minimumSize: const Size.square(AppTouchTarget.min),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
    );
  }
}

/// Agents list button with a compact task-progress badge.
///
/// The badge sits at the top-right of the icon and changes colour/shape
/// to communicate overall progress at a glance:
/// - Red circle with running count  → tasks are still active
/// - Green check circle             → all tasks finished successfully
/// - No badge                       → no tasks in this session
class _AgentsListButton extends StatelessWidget {
  const _AgentsListButton({required this.progress, required this.sessionId});

  final TaskProgress progress;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final running = progress.running;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.rocket_launch_outlined),
          iconSize: 20,
          tooltip: l10n.agentsListTitle,
          style: IconButton.styleFrom(
            foregroundColor: cs.onSurfaceVariant,
            padding: const EdgeInsets.all(AppSpacing.sm),
            minimumSize: const Size.square(AppTouchTarget.min),
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: cs.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              builder: (sheetContext) => AgentsListSheet(
                sessionId: sessionId,
                onAgentTap: (agent, navigationId) {
                  Navigator.of(sheetContext).pop();
                  context.push(
                    '/chat/$sessionId/agent/$navigationId',
                    extra: agent,
                  );
                },
              ),
            );
          },
        ),
        // Progress badge: red circle with count while running,
        // green check when everything is done.
        if (progress.hasTasks)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: running > 0 ? cs.error : AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: running > 0
                  ? Text(
                      running > 9 ? '9+' : '$running',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : const Icon(
                      Icons.check_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
            ),
          ),
      ],
    );
  }
}

/// Compact three-dot typing indicator for the app bar
/// subtitle. Shows bouncing dots alongside a label.
class _AppBarTypingIndicator extends StatefulWidget {
  const _AppBarTypingIndicator({required this.color});

  final Color color;

  @override
  State<_AppBarTypingIndicator> createState() => _AppBarTypingIndicatorState();
}

class _AppBarTypingIndicatorState extends State<_AppBarTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final phase = (_ctrl.value + i * 0.2) % 1.0;
                final y = -2.0 * (phase < 0.5 ? phase * 2 : 2.0 - phase * 2);
                return Transform.translate(offset: Offset(0, y), child: child);
              },
              child: Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: widget.color.withAlpha(200),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Resolves the [ChatMachineVitals] for the current session, returning
/// `null` if the session has no machine id or the machine is not
/// present in [machines].
///
/// The caller is expected to have already resolved the live machine
/// (typically via `ref.watch(machinesNotifierProvider.select(...))`).
/// Keeping the `ref.watch` in the caller lets the chat screen remain
/// in control of rebuild scope — this helper is a pure resolver.
///
/// [daemonStateOf] extracts the daemon-state map from the machine
/// type without coupling the helper to the `Machine` model — the
/// caller passes a closure that knows how to read its own type.
ChatMachineVitals? buildChatMachineVitals({
  required String? machineId,
  required Map<String, dynamic>? daemonState,
}) {
  if (machineId == null || machineId.isEmpty) return null;
  return ChatMachineVitals.fromDaemonState(daemonState);
}
