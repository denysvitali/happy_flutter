import 'package:flutter/material.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_ui_state_notifier.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import 'mission_control_types.dart';
import 'mission_heartbeat.dart';
import 'session_cards.dart';
import 'workspace_identity.dart';

/// Two-line operational tile used by Mission Control.
///
/// The title owns the full first line. Workspace and the last message or
/// tool call share the second line, while the lane-specific outcome stays
/// in a trailing pill. The pill doubles as a mark-read button for unread
/// rows; an overflow menu exposes pin and snooze triage actions.
class MissionActionRow extends StatelessWidget {
  const MissionActionRow({
    required this.session,
    required this.entry,
    required this.lane,
    required this.onTap,
    required this.onLongPress,
    super.key,
    this.animateActivity = true,
    this.selected = false,
    this.highlighted = false,
    this.isPinned = false,
    this.isSnoozed = false,
    this.onMarkRead,
    this.onTogglePin,
    this.onToggleSnooze,
    this.onPeek,
  });

  final Session session;
  final SessionUiEntry entry;
  final MissionLane lane;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool animateActivity;

  /// Selection-mode check state.
  final bool selected;

  /// True when the session became actionable since the user last saw it
  /// quiet — renders as a subtle tint instead of reordering the row.
  final bool highlighted;

  final bool isPinned;
  final bool isSnoozed;
  final VoidCallback? onMarkRead;
  final VoidCallback? onTogglePin;
  final ValueChanged<bool>? onToggleSnooze;

  /// Opens the glanceable peek sheet without navigating into the chat.
  final VoidCallback? onPeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = getSessionStatus(session);
    final laneColor = missionLaneColor(context, lane);
    final laneLabel = missionLaneLabel(context, lane);
    final activity = getSessionActivity(context, session)?.label;
    final preview = entry.lastMessagePreview;
    // The concrete update outranks the abstract activity label: most queue
    // entries are progress reports, and "Used Grep · rg foo" tells the user
    // more than another "thinking" badge.
    final activityText =
        (preview != null && preview.isNotEmpty ? preview : null) ??
        activity ??
        laneLabel;
    final path = session.metadata?.path;
    final workspace = path == null || path.isEmpty
        ? null
        : missionShortPath(path);
    final detail = workspace == null
        ? activityText
        : '$workspace  ·  $activityText';
    final since =
        entry.lastMessageTimestamp ?? session.lastMessageAt ?? session.activeAt;
    // Freshness reads the shared Mission Control clock, so the pill and
    // glow age without any per-row timer.
    final freshness = streamFreshness(
      nowMs: missionNowOf(context),
      lastActivityAt: since,
      live: lane == MissionLane.live,
    );
    final silenceMs = missionNowOf(context) - since;
    final isSilent =
        lane == MissionLane.live &&
        silenceMs >= missionSilentThreshold.inMilliseconds;
    final semanticOutcome = switch (lane) {
      MissionLane.blocked => context.l10n.missionControlReview,
      MissionLane.error => laneLabel,
      MissionLane.unread => context.l10n.missionControlNewCount(
        entry.unreadCount,
      ),
      MissionLane.live => isSilent
          ? context.l10n.missionControlSilent(formatSilenceShort(silenceMs))
          : formatElapsedShort(silenceMs),
      MissionLane.quiet => laneLabel,
    };
    final name = getSessionName(session);
    final detailStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: AppFontSize.xs,
      color: lane == MissionLane.error ? laneColor : cs.onSurfaceVariant,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $laneLabel, $detail, $semanticOutcome',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppDuration.fast),
          curve: AppCurve.standard,
          constraints: const BoxConstraints(
            minHeight: AppTouchTarget.comfortable,
          ),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.1)
                : highlighted
                ? laneColor.withValues(alpha: 0.06)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
              ),
              top: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
              ),
              right: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
              ),
              bottom: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.smd,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    _LaneTile(
                      lane: lane,
                      color: laneColor,
                      freshness: freshness,
                      // Blocked/error are at-rest lanes: their full
                      // container color and outcome pill already demand
                      // attention, so only real agent activity and the
                      // brief post-update burst animate.
                      pulse:
                          animateActivity &&
                          (status.isPulsing ||
                              freshness == StreamFreshness.burst),
                      selected: selected,
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Row(
                            children: [
                              if (workspace != null) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: workspaceIdentityColor(
                                      context,
                                      sessionFolderKey(session),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                              ],
                              Expanded(
                                child: Text(
                                  detail,
                                  // The error reason is why the user is
                                  // looking — one extra line beats an
                                  // elided diagnosis.
                                  maxLines:
                                      lane == MissionLane.error ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: detailStyle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (isPinned) ...[
                      Icon(
                        Icons.push_pin_rounded,
                        size: AppIconSize.sm,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    _OutcomePill(
                      lane: lane,
                      entry: entry,
                      since: since,
                      live: lane == MissionLane.live,
                      onMarkRead: lane == MissionLane.unread && !selected
                          ? onMarkRead
                          : null,
                    ),
                    if (_hasOverflowMenu) ...[
                      _TriageMenu(
                        isPinned: isPinned,
                        isSnoozed: isSnoozed,
                        canMarkRead:
                            lane == MissionLane.unread && entry.unreadCount > 0,
                        onMarkRead: onMarkRead,
                        onTogglePin: onTogglePin,
                        onToggleSnooze: onToggleSnooze,
                        onPeek: onPeek,
                      ),
                    ] else ...[
                      const SizedBox(width: AppSpacing.xxs),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: AppIconSize.md,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasOverflowMenu =>
      onTogglePin != null ||
      onToggleSnooze != null ||
      onMarkRead != null ||
      onPeek != null;
}

class _LaneTile extends StatelessWidget {
  const _LaneTile({
    required this.lane,
    required this.color,
    required this.freshness,
    required this.pulse,
    required this.selected,
  });

  final MissionLane lane;
  final Color color;
  final StreamFreshness freshness;
  final bool pulse;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        // Freshness glow: the tile brightens right after an update and
        // decays as the stream goes quiet. Blocked/error keep their full
        // lane container — they need the user regardless of age.
        color: switch (lane) {
          MissionLane.blocked ||
          MissionLane.error => missionLaneContainerColor(context, lane),
          _ => Color.alphaBlend(
            color.withValues(alpha: switch (freshness) {
              StreamFreshness.burst => 0.18,
              StreamFreshness.fresh => 0.12,
              StreamFreshness.silent => 0.14,
              StreamFreshness.aging => 0.06,
            }),
            Theme.of(context).colorScheme.surfaceContainerLow,
          ),
        },
        borderRadius: BorderRadius.circular(AppRadius.smd),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            selected ? Icons.check_rounded : missionLaneIcon(lane),
            size: AppIconSize.lg,
            color: color,
          ),
          if (pulse)
            Positioned(
              right: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: AppStatusDot(color: color, pulse: true, size: 4),
            ),
        ],
      ),
    );
  }
}

class _OutcomePill extends StatelessWidget {
  const _OutcomePill({
    required this.lane,
    required this.entry,
    required this.since,
    required this.live,
    this.onMarkRead,
  });

  final MissionLane lane;
  final SessionUiEntry entry;
  final int since;

  /// Whether the agent is still marked as working — gates the "silent"
  /// stall hint, which would be nonsense on a finished session.
  final bool live;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final color = missionLaneColor(context, lane);

    // Live pills read the shared clock: silence age normally, and an
    // amber "N m silent" stall hint once the stream stops updating while
    // still claiming to work (threshold aligned with StuckAgentSentinel).
    final silenceMs = missionNowOf(context) - since;
    final isSilent =
        live && silenceMs >= missionSilentThreshold.inMilliseconds;
    final pillColor = isSilent
        ? missionLaneColor(context, MissionLane.blocked)
        : color;
    final pillBg = isSilent
        ? missionLaneContainerColor(context, MissionLane.blocked)
        : missionLaneContainerColor(context, lane);
    final child = switch (lane) {
      MissionLane.blocked => Text(l10n.missionControlReview),
      MissionLane.error => Text(missionLaneLabel(context, lane)),
      MissionLane.unread => Text(
        l10n.missionControlNewCount(entry.unreadCount),
      ),
      MissionLane.live => Text(
        isSilent
            ? l10n.missionControlSilent(formatSilenceShort(silenceMs))
            : formatElapsedShort(silenceMs),
      ),
      MissionLane.quiet => Text(missionLaneLabel(context, lane)),
    };
    final pill = Container(
      width: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: DefaultTextStyle(
        style: theme.textTheme.labelSmall!.copyWith(
          color: pillColor,
          fontWeight: FontWeight.w700,
          fontSize: AppFontSize.xs,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        textAlign: TextAlign.center,
        child: child,
      ),
    );
    if (onMarkRead == null) return pill;
    return Semantics(
      button: true,
      label: l10n.missionControlMarkRead,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onMarkRead,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: pill,
        ),
      ),
    );
  }
}

/// Overflow triage menu for one action row: quick look, mark read, pin,
/// snooze.
class _TriageMenu extends StatelessWidget {
  const _TriageMenu({
    required this.isPinned,
    required this.isSnoozed,
    required this.canMarkRead,
    this.onMarkRead,
    this.onTogglePin,
    this.onToggleSnooze,
    this.onPeek,
  });

  final bool isPinned;
  final bool isSnoozed;
  final bool canMarkRead;
  final VoidCallback? onMarkRead;
  final VoidCallback? onTogglePin;
  final ValueChanged<bool>? onToggleSnooze;
  final VoidCallback? onPeek;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: AppIconSize.md,
        color: cs.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: AppTouchTarget.min),
      tooltip: l10n.missionControlTriage,
      onSelected: (action) {
        switch (action) {
          case 'peek':
            onPeek?.call();
          case 'read':
            onMarkRead?.call();
          case 'pin':
            onTogglePin?.call();
          case 'snooze':
            onToggleSnooze?.call(true);
          case 'unsnooze':
            onToggleSnooze?.call(false);
        }
      },
      itemBuilder: (context) => [
        if (onPeek != null)
          PopupMenuItem(
            value: 'peek',
            child: Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: AppIconSize.sm,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.missionControlPeekQuickLook),
              ],
            ),
          ),
        if (canMarkRead && onMarkRead != null)
          PopupMenuItem(
            value: 'read',
            child: Text(l10n.missionControlMarkRead),
          ),
        if (onTogglePin != null)
          PopupMenuItem(
            value: 'pin',
            child: Text(
              isPinned ? l10n.missionControlUnpin : l10n.missionControlPinToTop,
            ),
          ),
        if (onToggleSnooze != null)
          PopupMenuItem(
            value: isSnoozed ? 'unsnooze' : 'snooze',
            child: Text(
              isSnoozed
                  ? l10n.missionControlUnsnooze
                  : l10n.missionControlSnooze,
            ),
          ),
      ],
    );
  }
}
