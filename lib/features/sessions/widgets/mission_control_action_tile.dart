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
import 'mission_control_triage_menu.dart';
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
    this.inbox = false,
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

  /// Gives inbox previews more room while retaining compact grouped rows.
  final bool inbox;

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
    final inboxHost = switch (hostName) {
      'localhost' || '127.0.0.1' || '::1' => null,
      _ => host,
    };
    final inboxWorkspace = switch (workspace?.trim().toLowerCase()) {
      '' || '(none)' || 'none' || 'null' || '(null)' => null,
      _ => workspace,
    };
    final inboxFallback = [
      harnessName,
      if (inboxWorkspace != null && !workspaceEchoesName) inboxWorkspace,
      if (inboxHost != null &&
          inboxHost.toLowerCase() != name.trim().toLowerCase() &&
          inboxHost.toLowerCase() !=
              inboxWorkspace?.split('/').last.toLowerCase())
        inboxHost,
    ].join(' · ');
    final workspaceContext =
        inbox &&
            preview?.isNotEmpty == true &&
            inboxWorkspace != null &&
            !workspaceEchoesName
        ? inboxWorkspace
        : null;
    final secondary = activityText?.trim().isNotEmpty == true
        ? activityText!.trim()
        : inbox
        ? inboxFallback
        : fallback.isNotEmpty
        ? fallback
        : harnessName;
    final secondaryTooltip =
        secondary == (inbox ? inboxFallback : fallback) &&
            (inbox ? inboxHost : host) != null
        ? rawHost!
        : secondary;
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
        constraints: BoxConstraints(
          minHeight: inbox
              ? AppTouchTarget.comfortable + AppSpacing.lg
              : AppTouchTarget.comfortable,
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
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.smd,
                vertical: inbox ? AppSpacing.sm : AppSpacing.xs,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Phone-width rows give the title its full content column.
                  // The age shares the trailing action column rather than
                  // the title row, where it clipped long names.
                  final trailingAge = constraints.maxWidth < 400;
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(AppFontSize.base) >
                      AppFontSize.base * 1.3;
                  final hasMenu = !selected && _hasOverflowMenu;
                  // Large text needs the entire preview column. Put the
                  // outcome underneath instead of squeezing the update.
                  final stackOutcome = inbox && trailingAge && largeText;
                  final ageWidget = Tooltip(
                    message: when.toLocal().toString(),
                    child: Text(
                      ageLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.secondary(theme),
                    ),
                  );
                  final menu = Transform.translate(
                    // more_vert's dots sit inside the glyph box, so nudge the
                    // button until the dots (not the box) mirror the tile's
                    // left inset.
                    offset: const Offset(_menuGlyphInset, 0),
                    child: SizedBox.square(
                      dimension: AppTouchTarget.min,
                      child: MissionTriageMenu(
                        isPinned: isPinned,
                        isSnoozed: isSnoozed,
                        canMarkRead:
                            showTriageMenu &&
                            lane == MissionLane.unread &&
                            entry.unreadCount > 0,
                        onMarkRead: showTriageMenu ? onMarkRead : null,
                        onTogglePin: showTriageMenu ? onTogglePin : null,
                        onToggleSnooze: showTriageMenu ? onToggleSnooze : null,
                        onPeek: onPeek,
                        onArchive: onArchive,
                        onSelect: onSelect,
                      ),
                    ),
                  );
                  // The age normally ends the title line so it shares the
                  // right edge with the outcome pill below it. Only large
                  // text that would crush the title below the readable
                  // minimum the pinned narrow tests enforce stacks the age
                  // above the menu instead.
                  final ageTextWidth = showActivityAge && trailingAge
                      ? (TextPainter(
                          text: TextSpan(
                            text: ageLabel,
                            style: AppText.secondary(theme),
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout(maxWidth: constraints.maxWidth * 0.2)).width
                      : 0.0;
                  final inlineAge =
                      !trailingAge ||
                      !largeText ||
                      constraints.maxWidth -
                              AppSpacing.smd * 2 -
                              AppControlSize.sm -
                              missionRowTextGap -
                              ageTextWidth -
                              AppSpacing.xs -
                              AppTouchTarget.min -
                              AppSpacing.xxs >=
                          180;
                  // Phone rows keep the title and update lines tight and center
                  // the menu on that block like a list tile; every update line
                  // is at least the pill's tap height so rows share a rhythm.
                  final phoneRow = trailingAge && inlineAge;

                  final outcome = _OutcomePill(
                    compact: constraints.maxWidth < 480,
                    tapHeight: phoneRow ? _pillTapHeight : AppTouchTarget.min,
                    lane: lane,
                    entry: entry,
                    since: since,
                    nowMs: nowMs,
                    live: status.state == SessionState.thinking,
                    onMarkRead: lane == MissionLane.unread && !selected
                        ? onMarkRead
                        : null,
                  );
                  return Padding(
                    // The title's glyphs start below its line box; balance it
                    // so the ink has the same gap above as the update below.
                    padding: EdgeInsets.only(
                      top: phoneRow ? _titleInkInset : 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            // Stretch so the trailing age/menu column pins to
                            // the row top; centered, it drifted per row height.
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                // Pin the mark's top edge to the title's glyph
                                // top: centered, it drifts onto the preview
                                // paragraph and reads as its icon.
                                alignment: Alignment.topLeft,
                                widthFactor: 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: _titleInkInset,
                                  ),
                                  child: ExcludeSemantics(
                                    child: _LaneTile(
                                      lane: lane,
                                      flavor: session.metadata?.flavor,
                                      color: laneColor,
                                      freshness: freshness,
                                      pulse:
                                          animateActivity &&
                                          (status.isPulsing ||
                                              freshness ==
                                                  StreamFreshness.burst),
                                      selected: selected,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: missionRowTextGap),
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
                                            semanticLabel: context
                                                .l10n
                                                .missionControlPinToTop,
                                          ),
                                        ],
                                        if (showActivityAge && inlineAge) ...[
                                          const SizedBox(width: AppSpacing.sm),
                                          ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth:
                                                  constraints.maxWidth * 0.2,
                                            ),
                                            child: ageWidget,
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (workspaceContext != null) ...[
                                      const SizedBox(height: AppSpacing.xxs),
                                      Tooltip(
                                        message: path!,
                                        excludeFromSemantics: true,
                                        child: Text(
                                          workspaceContext,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.secondary(theme),
                                        ),
                                      ),
                                    ],
                                    if (secondary.isNotEmpty ||
                                        showOutcome) ...[
                                      const SizedBox(height: AppSpacing.xxs),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: phoneRow
                                              ? _pillTapHeight
                                              : 0,
                                        ),
                                        child: Row(
                                          children: [
                                            if (secondary.isNotEmpty)
                                              Expanded(
                                                child: Tooltip(
                                                  message: secondaryTooltip,
                                                  excludeFromSemantics: true,
                                                  child: Text(
                                                    secondary,
                                                    maxLines:
                                                        inbox ||
                                                            (trailingAge &&
                                                                !largeText) ||
                                                            lane ==
                                                                MissionLane
                                                                    .error
                                                        ? 2
                                                        : 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppText.secondary(
                                                      theme,
                                                      lane == MissionLane.error
                                                          ? laneColor
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (showOutcome &&
                                                !stackOutcome) ...[
                                              if (secondary.isNotEmpty)
                                                const SizedBox(
                                                  width: AppSpacing.xsm,
                                                ),
                                              ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxWidth:
                                                      constraints.maxWidth *
                                                      0.35,
                                                ),
                                                child: outcome,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (showOutcome && stackOutcome) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      outcome,
                                    ],
                                  ],
                                ),
                              ),
                              if (hasMenu ||
                                  (showActivityAge && !inlineAge)) ...[
                                const SizedBox(width: AppSpacing.xxs),
                                // Only the stacked large-text layout pins the
                                // trailing column to the row top; every other
                                // row centers it like a list tile.
                                Align(
                                  alignment: trailingAge && !phoneRow
                                      ? Alignment.topRight
                                      : Alignment.centerRight,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (showActivityAge && !inlineAge)
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                constraints.maxWidth * 0.2,
                                          ),
                                          child: ageWidget,
                                        ),
                                      if (hasMenu) menu,
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                    ),
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

/// Gap between the more_vert glyph box and its dots: the dots are 4/24 wide
/// and centered, so at [AppIconSize.md] each side holds 10/24 of the box.
const double _menuGlyphInset = AppIconSize.md * 10 / 24;

/// Distance from the title's line box to the top of its glyphs.
const double _titleInkInset = 3;

/// Tap height of the unread pill on phone rows. WCAG 2.2 (2.5.8) asks for
/// 24dp; the taller 44dp target used to double the update line's height.
const double _pillTapHeight = 24;

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
    required this.tapHeight,
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

  /// Minimum tap-target height; it also sets the height of the line the pill
  /// sits on, so phone rows pass their band height to keep padding even.
  final double tapHeight;
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
            constraints: BoxConstraints(minHeight: tapHeight),
            child: Center(widthFactor: 1, heightFactor: 1, child: pill),
          ),
        ),
      ),
    );
  }
}
