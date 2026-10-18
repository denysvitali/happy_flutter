import 'package:flutter/material.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_ui_state_notifier.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import '../../../core/utils/utils.dart' show formatRelativeTime;
import '../harness_logo.dart';
import 'inline_permission_actions.dart';
import 'mission_control_types.dart';
import 'mission_heartbeat.dart';
import 'session_cards.dart';

/// A compact conversation row with independent session and menu actions.
///
/// The second line favors the latest update over workspace/host metadata.
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
    this.onArchive,
    this.onSelect,
    this.showTriageMenu = true,
    this.showInlineApproval = false,
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

  /// Archive and selection are separate from opening the conversation.
  final VoidCallback? onArchive;
  final VoidCallback? onSelect;

  /// Mission Control owns pin/snooze/read triage. Preview, selection and
  /// archive remain discoverable on grouped boards when supplied.
  final bool showTriageMenu;

  /// Renders Allow/Deny under a blocked row. Requires a [ProviderScope].
  final bool showInlineApproval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = getSessionStatus(session);
    final laneColor = missionLaneColor(context, lane);
    final activity = getSessionActivity(context, session)?.label;
    final preview = entry.lastMessagePreview?.trim();
    // The concrete update outranks the abstract activity label: most queue
    // entries are progress reports, and "Used Grep · rg foo" tells the user
    // more than another "thinking" badge.
    final requests = session.agentState?.requests;
    final approval =
        showInlineApproval &&
        !selected &&
        lane == MissionLane.blocked &&
        requests != null &&
        requests.isNotEmpty;
    // With inline approval the strip below already names the tool, so the
    // "<tool> needs approval" activity label would only repeat it.
    final activityText =
        (preview != null && preview.isNotEmpty ? preview : null) ??
        (approval ? null : activity);
    final path = session.metadata?.path;
    final workspace = path == null || path.isEmpty
        ? null
        : missionShortPath(path);
    final name = getSessionName(session);
    final workspaceEchoesName =
        workspace != null &&
        workspace.split('/').last.toLowerCase() == name.trim().toLowerCase();
    final rawHost = session.metadata?.host.trim();
    final hostName = rawHost?.split('@').last.toLowerCase();
    final host = switch (hostName) {
      null || '' || '(none)' || 'none' || 'null' || '(null)' => null,
      _ => missionShortHost(rawHost!),
    };
    final fallback = [
      if (workspace != null && !workspaceEchoesName) workspace,
      if (host != null && host.toLowerCase() != name.trim().toLowerCase()) host,
    ].join(' · ');
    final harnessName = switch (session.metadata?.flavor) {
      null || 'claude' => context.l10n.sessionsClaude,
      'codex' => context.l10n.sessionsCodex,
      'agy' || 'gemini' => context.l10n.sessionsAgy,
      'pi' => context.l10n.sessionsPi,
      'opencode' => context.l10n.sessionsOpencode,
      'grok' || 'grok-build' => context.l10n.sessionsGrok,
      'prime-agent' => 'Prime Agent',
      'har' => 'Har',
      _ => context.l10n.sessionsAgent,
    };
    final secondary = activityText?.trim().isNotEmpty == true
        ? activityText!.trim()
        : fallback.isNotEmpty
        ? fallback
        : harnessName;
    final since =
        entry.lastMessageTimestamp ?? session.lastMessageAt ?? session.activeAt;
    final nowMs = missionNowOf(context);
    // Freshness reads the shared Mission Control clock, so the pill and
    // glow age without any per-row timer.
    final freshness = streamFreshness(
      nowMs: nowMs,
      lastActivityAt: since,
      live: lane == MissionLane.live,
    );
    final showActivityAge =
        lane != MissionLane.live ||
        status.state != SessionState.thinking ||
        freshness != StreamFreshness.silent;
    final when = DateTime.fromMillisecondsSinceEpoch(since);
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    final age = now.difference(when);
    // Keep old sessions relative too. Future timestamps retain the shared
    // formatter's clock-skew handling instead of claiming "just now".
    final ageLabel = age.inDays >= 7
        ? context.l10n.relativeDaysCompact(age.inDays)
        : formatRelativeTime(when, now: now, compact: true, l10n: context.l10n);

    final showOutcome =
        !approval &&
        (lane == MissionLane.blocked ||
            lane == MissionLane.error ||
            (lane == MissionLane.unread && entry.unreadCount > 0) ||
            (lane == MissionLane.live && !showActivityAge));

    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
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
          border: Border.all(color: selected ? cs.primary : Colors.transparent),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.smd,
                vertical: AppSpacing.xs,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Larger text gets the title's full content column. The age
                  // shares the trailing action column rather than a footer.
                  final trailingAge =
                      constraints.maxWidth < 400 &&
                      MediaQuery.textScalerOf(context).scale(AppFontSize.base) >
                          AppFontSize.base * 1.3;
                  final hasMenu = !selected && _hasOverflowMenu;
                  final ageWidget = Tooltip(
                    message: when.toLocal().toString(),
                    child: Text(
                      ageLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.secondary(theme),
                    ),
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ExcludeSemantics(
                            child: _LaneTile(
                              lane: lane,
                              flavor: session.metadata?.flavor,
                              color: laneColor,
                              freshness: freshness,
                              pulse:
                                  animateActivity &&
                                  (status.isPulsing ||
                                      freshness == StreamFreshness.burst),
                              selected: selected,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xsm),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.title(theme),
                                      ),
                                    ),
                                    if (isPinned) ...[
                                      const SizedBox(width: AppSpacing.xs),
                                      Icon(
                                        Icons.push_pin_rounded,
                                        size: AppIconSize.sm,
                                        color: cs.onSurfaceVariant,
                                        semanticLabel:
                                            context.l10n.missionControlPinToTop,
                                      ),
                                    ],
                                    if (showActivityAge && !trailingAge) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: constraints.maxWidth * 0.2,
                                        ),
                                        child: ageWidget,
                                      ),
                                    ],
                                  ],
                                ),
                                if (secondary.isNotEmpty || showOutcome) ...[
                                  const SizedBox(height: AppSpacing.xxs),
                                  Row(
                                    children: [
                                      if (secondary.isNotEmpty)
                                        Expanded(
                                          child: Tooltip(
                                            message:
                                                secondary == fallback &&
                                                    host != null
                                                ? rawHost!
                                                : secondary,
                                            child: Text(
                                              secondary,
                                              maxLines:
                                                  lane == MissionLane.error
                                                  ? 2
                                                  : 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.secondary(
                                                theme,
                                                lane == MissionLane.error
                                                    ? laneColor
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (showOutcome) ...[
                                        if (secondary.isNotEmpty)
                                          const SizedBox(width: AppSpacing.xsm),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                constraints.maxWidth * 0.35,
                                          ),
                                          child: _OutcomePill(
                                            compact: constraints.maxWidth < 480,
                                            lane: lane,
                                            entry: entry,
                                            since: since,
                                            nowMs: nowMs,
                                            live:
                                                status.state ==
                                                SessionState.thinking,
                                            onMarkRead:
                                                lane == MissionLane.unread &&
                                                    !selected
                                                ? onMarkRead
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (hasMenu || (showActivityAge && trailingAge)) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showActivityAge && trailingAge)
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth * 0.2,
                                    ),
                                    child: ageWidget,
                                  ),
                                if (hasMenu)
                                  SizedBox.square(
                                    dimension: AppTouchTarget.min,
                                    child: _TriageMenu(
                                      isPinned: isPinned,
                                      isSnoozed: isSnoozed,
                                      canMarkRead:
                                          showTriageMenu &&
                                          lane == MissionLane.unread &&
                                          entry.unreadCount > 0,
                                      onMarkRead: showTriageMenu
                                          ? onMarkRead
                                          : null,
                                      onTogglePin: showTriageMenu
                                          ? onTogglePin
                                          : null,
                                      onToggleSnooze: showTriageMenu
                                          ? onToggleSnooze
                                          : null,
                                      onPeek: onPeek,
                                      onArchive: onArchive,
                                      onSelect: onSelect,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (approval)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: InlinePermissionActions(
                            sessionId: session.id,
                            requests: requests,
                            isOnline: session.presence == 'online',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasOverflowMenu =>
      onArchive != null ||
      onSelect != null ||
      onPeek != null ||
      (showTriageMenu &&
          (onTogglePin != null ||
              onToggleSnooze != null ||
              (onMarkRead != null &&
                  lane == MissionLane.unread &&
                  entry.unreadCount > 0)));
}

class _LaneTile extends StatelessWidget {
  const _LaneTile({
    required this.lane,
    required this.color,
    required this.freshness,
    required this.pulse,
    required this.selected,
    this.flavor,
  });

  final MissionLane lane;
  final String? flavor;
  final Color color;
  final StreamFreshness freshness;
  final bool pulse;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppControlSize.sm,
      height: AppControlSize.sm,
      decoration: BoxDecoration(
        // Freshness glow: the tile brightens right after an update and
        // decays as the stream goes quiet. Blocked/error keep their full
        // lane container — they need the user regardless of age.
        color: switch (lane) {
          MissionLane.blocked ||
          MissionLane.error => missionLaneContainerColor(context, lane),
          _ => Color.alphaBlend(
            color.withValues(
              alpha: switch (freshness) {
                StreamFreshness.burst => 0.18,
                StreamFreshness.fresh => 0.12,
                StreamFreshness.silent => 0.14,
                StreamFreshness.aging => 0.06,
              },
            ),
            Theme.of(context).colorScheme.surfaceContainerLow,
          ),
        },
        borderRadius: BorderRadius.circular(AppRadius.smd),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A quiet row has no state worth an icon; the harness mark tells
          // the user which agent they would be talking to.
          if (lane == MissionLane.quiet && !selected)
            Opacity(
              opacity: 0.85,
              child: HarnessLogo(
                flavor: flavor ?? 'claude',
                size: AppIconSize.md,
              ),
            )
          else
            Icon(
              selected ? Icons.check_rounded : missionLaneIcon(lane),
              size: AppIconSize.md,
              color: color,
            ),
          if (pulse)
            Positioned(
              right: AppSpacing.xxs,
              bottom: AppSpacing.xxs,
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
    required this.nowMs,
    required this.live,
    required this.compact,
    this.onMarkRead,
  });

  final MissionLane lane;
  final SessionUiEntry entry;
  final int since;
  final int nowMs;

  /// Whether the agent is still marked as working — gates the "silent"
  /// stall hint, which would be nonsense on a finished session.
  final bool live;
  final bool compact;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final color = missionLaneColor(context, lane);
    final silenceMs = nowMs - since;
    final isSilent = live && silenceMs >= missionSilentThreshold.inMilliseconds;
    final displayLane = isSilent ? MissionLane.blocked : lane;
    final label = switch (lane) {
      MissionLane.blocked => l10n.missionControlReview,
      MissionLane.unread =>
        compact
            ? l10n.missionControlNewCount(entry.unreadCount)
            : live
            ? l10n.chatSessionWorkingUnread(entry.unreadCount)
            : missionUnreadOutcome(context, entry),
      MissionLane.live =>
        isSilent
            ? l10n.missionControlSilent(formatSilenceShort(silenceMs))
            : missionLaneLabel(context, lane),
      MissionLane.error || MissionLane.quiet => missionLaneLabel(context, lane),
    };
    final pill = AppBadge(
      label: label,
      backgroundColor: missionLaneContainerColor(context, displayLane),
      foregroundColor: isSilent
          ? missionLaneColor(context, MissionLane.blocked)
          : color,
      labelStyle: AppText.badge(theme, missionLaneColor(context, displayLane)),
    );
    if (onMarkRead == null) return pill;
    return Semantics(
      button: true,
      label: '$label, ${l10n.missionControlMarkRead}',
      onTap: onMarkRead,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onMarkRead,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
            child: Center(widthFactor: 1, heightFactor: 1, child: pill),
          ),
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
    this.onArchive,
    this.onSelect,
  });

  final bool isPinned;
  final bool isSnoozed;
  final bool canMarkRead;
  final VoidCallback? onMarkRead;
  final VoidCallback? onTogglePin;
  final ValueChanged<bool>? onToggleSnooze;
  final VoidCallback? onPeek;
  final VoidCallback? onArchive;
  final VoidCallback? onSelect;

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
          case 'select':
            onSelect?.call();
          case 'archive':
            onArchive?.call();
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
        if (onSelect != null)
          PopupMenuItem(
            value: 'select',
            child: Text(l10n.sessionsSelectSession),
          ),
        if (onArchive != null)
          PopupMenuItem(value: 'archive', child: Text(l10n.sessionsArchive)),
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
                Flexible(child: Text(l10n.missionControlPeekQuickLook)),
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
