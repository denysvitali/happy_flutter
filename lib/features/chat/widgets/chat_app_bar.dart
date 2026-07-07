import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../../loops/loop_count_badge.dart';
import '../../sessions/session_avatar.dart';
import 'agents_list_sheet.dart';
import 'model_mode.dart';
import 'session_header_chip.dart';

/// App bar for the chat screen showing session title,
/// status, model info, and action buttons.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
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
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (machineVitals == null ? 0 : _VitalsStrip.height),
  );

  @override
  Widget build(BuildContext context) {
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
      title: _buildTitle(context),
      scrolledUnderElevation: 0.5,
      bottom: machineVitals == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(_VitalsStrip.height),
              child: _VitalsStrip(vitals: machineVitals!),
            ),
      actions: [
        // Loop count badge — appears only when the session has loops.
        LoopCountBadge(sessionId: sessionId),
        // Agents list button with progress
        _AgentsListButton(
          progress: AgentsListSheet.computeTaskProgress(sessionId),
          sessionId: sessionId,
        ),
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

  Widget _buildTitle(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (session == null) {
      return Text(
        context.l10n.chatChat,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      );
    }

    final currentSession = session!;
    final flavor = currentSession.metadata?.flavor;
    final avatarId = getSessionAvatarId(currentSession);

    return GestureDetector(
      onTap: onInfoTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SessionAvatar(
            id: avatarId,
            flavor: flavor,
            size: 34,
            showFlavorIcon: true,
            square: true,
            style: avatarStyle,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _TitleReveal(
              sessionTitle: sessionTitle,
              statusChips: statusChips,
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

class _VitalsStrip extends StatelessWidget {
  const _VitalsStrip({required this.vitals});

  static const double height = 34;

  final ChatMachineVitals vitals;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
      ),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: _VitalPill(
                  icon: Icons.speed_outlined,
                  label: 'CPU',
                  percent: vitals.cpuPercent,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _VitalPill(
                  icon: Icons.memory_outlined,
                  label: 'MEM',
                  percent: vitals.memoryPercent,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _VitalPill(
                  icon: Icons.storage_outlined,
                  label: 'DISK',
                  percent: vitals.diskPercent,
                ),
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
              child: ClipRect(
                child: Row(
                  children: [
                    for (final (index, chip) in statusChips.indexed) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        fit: FlexFit.loose,
                        flex: chip.text.length > 18 ? 2 : 1,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1,
                          child: SessionHeaderChip(
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

class ChatAppBarStatusChip {
  const ChatAppBarStatusChip({
    required this.text,
    required this.color,
    this.icon = Icons.circle,
    this.showDot = false,
    this.pulse = false,
  });

  final String text;
  final Color color;
  final IconData icon;
  final bool showDot;
  final bool pulse;
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
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            minimumSize: const Size(36, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// Formats a "last seen N ago" label for the offline chip, picking
/// the closest l10n bucket (just-now / minutes / hours / days).
///
/// Pure function — takes a BuildContext for l10n and an epoch-ms
/// activeAt timestamp. Extracted from _ChatScreenState so the chip
/// logic can live next to the [ChatAppBar] data classes.
String formatLastSeenLabel(BuildContext context, int activeAt) {
  final l10n = context.l10n;
  final lastSeen = DateTime.fromMillisecondsSinceEpoch(activeAt);
  final diff = DateTime.now().difference(lastSeen);
  if (diff.inMinutes < 1) return l10n.chatLastSeenJustNow;
  if (diff.inMinutes < 60) {
    return l10n.chatLastSeenMinutes(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l10n.chatLastSeenHours(diff.inHours);
  }
  return l10n.chatLastSeenDays(diff.inDays);
}

/// Inputs the [ChatAppBar] needs from the chat screen's reactive
/// state to render the status chips. The chat screen watches each
/// of these and passes the latest values in.
///
/// Splitting the input as a typed record (vs. a long parameter
/// list) keeps the call site readable and makes the contract
/// explicit — adding a new chip only touches this record, not the
/// helper signature.
class ChatStatusChipsInputs {
  const ChatStatusChipsInputs({
    required this.session,
    required this.isReady,
    required this.hasRequests,
    required this.sendIssue,
    required this.latestUserMessage,
    required this.lastVisibleNonSidechainCreatedAt,
    required this.debugMaxSeq,
    required this.modelMode,
    this.lastMessageStreamActivityAt = 0,
  });

  final Session session;
  final bool isReady;
  final bool hasRequests;

  /// A pre-resolved lifecycle-error issue, or `null` if the session
  /// has no lifecycle error. The chat screen builds the issue from
  /// session metadata before calling the helper.
  final SendIssue? sendIssue;

  /// The most recent user message map (or `null` if no messages
  /// sent). The helper reads `sendStatus` from this map.
  final Map<String, dynamic>? latestUserMessage;

  /// Timestamp (ms since epoch) of the last visible (non-sidechain)
  /// message. Used to detect when the agent is in a "working on
  /// sub-tasks" state.
  final int lastVisibleNonSidechainCreatedAt;

  /// Debug-only seq watermark. -1 hides the chip.
  final int debugMaxSeq;

  /// Local timestamp (ms since epoch) of the last time this session's
  /// message stream changed — including sidechain children merging into
  /// collapsed Task rows, which produce no new visible message. Lets the
  /// chips surface "Working on sub-tasks" even when the `thinking` flag
  /// has gone stale during a long turn. 0 means no change observed yet.
  final int lastMessageStreamActivityAt;

  /// Current model selection. `ChatModelMode.defaultModel` hides
  /// the chip.
  final ChatModelMode modelMode;
}

/// Lightweight view of a session lifecycle error that the chat
/// screen can hand to the chip builder. The chat screen's own
/// `_SessionSendIssue` is library-private; the chip builder only
/// needs the two facts it renders.
class SendIssue {
  const SendIssue({
    required this.title,
    required this.message,
    required this.blocksSend,
  });
  final String title;
  final String message;
  final bool blocksSend;
}

/// Builds the list of [ChatAppBarStatusChip]s shown in the app bar.
///
/// Pure function: takes the chat screen's reactive state as
/// [inputs] and returns the chip list. No `ref.watch`, no
/// `Theme.of(context)` — callers pass in `colorScheme` and
/// `BuildContext` for l10n. The chat screen stays in control of
/// rebuild scope.
List<ChatAppBarStatusChip> buildChatStatusChips({
  required BuildContext context,
  required ColorScheme colorScheme,
  required ChatStatusChipsInputs inputs,
}) {
  final session = inputs.session;
  final chips = <ChatAppBarStatusChip>[];
  final hasRequests = inputs.hasRequests;
  final sendIssue = inputs.sendIssue;
  final lifecycleState = session.effectiveLifecycleState;
  final lifecycleSince = session.metadata?.lifecycleStateSince;
  final lifecycleIsRecent =
      lifecycleSince != null &&
      DateTime.now().millisecondsSinceEpoch - lifecycleSince < 120000;
  final isConnecting =
      !inputs.isReady &&
      lifecycleIsRecent &&
      (lifecycleState == 'starting' || lifecycleState == 'running');

  if (sendIssue != null) {
    chips.add(
      ChatAppBarStatusChip(
        text: sendIssue.blocksSend ? 'Agent failed' : 'Will restart',
        color: sendIssue.blocksSend ? AppColors.error : AppColors.warning,
        icon: sendIssue.blocksSend
            ? Icons.error_outline_rounded
            : Icons.restart_alt_rounded,
      ),
    );
  } else if (inputs.isReady) {
    chips.add(
      const ChatAppBarStatusChip(
        text: 'Online',
        color: AppColors.success,
        showDot: true,
        pulse: true,
      ),
    );
  } else if (isConnecting) {
    chips.add(
      ChatAppBarStatusChip(
        text: 'Connecting',
        color: colorScheme.primary,
        icon: Icons.sync_rounded,
      ),
    );
  } else {
    chips
      ..add(
        ChatAppBarStatusChip(
          text: 'Offline',
          color: colorScheme.outline,
          icon: Icons.cloud_off_rounded,
        ),
      )
      ..add(
        ChatAppBarStatusChip(
          text: formatLastSeenLabel(context, session.activeAt),
          color: colorScheme.onSurfaceVariant,
          icon: Icons.schedule_rounded,
        ),
      );
  }

  if (hasRequests) {
    chips.add(
      const ChatAppBarStatusChip(
        text: 'Approval needed',
        color: AppColors.warning,
        icon: Icons.shield_outlined,
      ),
    );
  } else {
    // When the agent has been "thinking" for a while with no new
    // visible (non-sidechain) message, surface that the work is
    // likely happening inside sub-tasks. Without this signal the
    // chat looks paused — see the long-running session diagnosis
    // on c8400ba… where 2000+ server messages produced almost no
    // visible bubbles.
    const subTaskSwitchMs = 30000;
    final lastVisibleCreatedAt = inputs.lastVisibleNonSidechainCreatedAt;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final stale =
        lastVisibleCreatedAt > 0 &&
        nowMs - lastVisibleCreatedAt > subTaskSwitchMs;
    if (session.thinking) {
      chips.add(
        ChatAppBarStatusChip(
          text: stale ? 'Working on sub-tasks' : 'Thinking',
          color: colorScheme.primary,
          showDot: !stale,
          icon: Icons.account_tree_outlined,
        ),
      );
    } else {
      // The thinking flag is set once at turn start and can go stale
      // during a long turn, while sub-agent traffic keeps merging into
      // collapsed Task rows — no new visible message, chat looks dead
      // even though the session is hard at work (session c04ffa4d…).
      // Fall back to message-stream activity: fresh changes with a
      // stale visible tail means hidden sub-task work.
      const hiddenActivityWindowMs = 60000;
      final lastStreamActivity = inputs.lastMessageStreamActivityAt;
      final hiddenActivity =
          lastStreamActivity > 0 &&
          nowMs - lastStreamActivity <= hiddenActivityWindowMs &&
          stale;
      if (hiddenActivity) {
        chips.add(
          ChatAppBarStatusChip(
            text: 'Working on sub-tasks',
            color: colorScheme.primary,
            icon: Icons.account_tree_outlined,
          ),
        );
      }
    }
  }

  // Debug-only seq watermark — proves the session is alive when
  // the visible chat looks idle. Highest seq we have decrypted
  // (incl. sidechain). The user requested this after observing
  // seq=2000+ with few visible messages.
  if (kDebugMode) {
    final maxSeq = inputs.debugMaxSeq;
    if (maxSeq >= 0) {
      chips.add(
        ChatAppBarStatusChip(
          text: 'seq=$maxSeq',
          color: colorScheme.outline,
          icon: Icons.bug_report_outlined,
        ),
      );
    }
  }

  final sendStatus = inputs.latestUserMessage?['sendStatus'] as String?;
  if (sendStatus != null) {
    switch (sendStatus) {
      case 'sending':
        chips.add(
          ChatAppBarStatusChip(
            text: 'Sending',
            color: colorScheme.onSurfaceVariant,
            icon: Icons.arrow_upward_rounded,
          ),
        );
        break;
      case 'pending':
        chips.add(
          const ChatAppBarStatusChip(
            text: 'Retry queued',
            color: AppColors.warning,
            icon: Icons.schedule_rounded,
          ),
        );
        break;
      case 'failed':
        chips.add(
          const ChatAppBarStatusChip(
            text: 'Not delivered',
            color: AppColors.error,
            icon: Icons.error_outline_rounded,
          ),
        );
        break;
    }
  }

  if (inputs.modelMode != ChatModelMode.defaultModel) {
    chips.add(
      ChatAppBarStatusChip(
        text: inputs.modelMode.label,
        color: colorScheme.onSurfaceVariant,
        icon: Icons.tune_rounded,
      ),
    );
  }

  return chips;
}
