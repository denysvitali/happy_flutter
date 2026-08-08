import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_ui_state_notifier.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import 'mission_control_types.dart';
import 'session_cards.dart';

/// Two-line operational tile used by Mission Control.
///
/// The title owns the full first line. Workspace and current activity share
/// the second line, while the lane-specific outcome stays in a trailing pill.
class MissionActionRow extends StatelessWidget {
  const MissionActionRow({
    required this.session,
    required this.entry,
    required this.lane,
    required this.onTap,
    required this.onLongPress,
    super.key,
    this.selected = false,
  });

  final Session session;
  final SessionUiEntry entry;
  final MissionLane lane;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = getSessionStatus(session);
    final laneColor = missionLaneColor(context, lane);
    final laneLabel = missionLaneLabel(context, lane);
    final activity = getSessionActivity(context, session)?.label;
    final preview = entry.lastMessagePreview;
    final activityText =
        activity ??
        (preview != null && preview.isNotEmpty ? preview : laneLabel);
    final path = session.metadata?.path;
    final workspace = path == null || path.isEmpty
        ? null
        : missionShortPath(path);
    final detail = workspace == null
        ? activityText
        : '$workspace  ·  $activityText';
    final since =
        entry.lastMessageTimestamp ?? session.lastMessageAt ?? session.activeAt;
    final semanticOutcome = switch (lane) {
      MissionLane.blocked => context.l10n.missionControlReview,
      MissionLane.unread => context.l10n.missionControlNewCount(
        entry.unreadCount,
      ),
      MissionLane.live => formatElapsedShort(
        DateTime.now().millisecondsSinceEpoch - since,
      ),
      MissionLane.quiet => laneLabel,
    };
    final name = getSessionName(session);

    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $laneLabel, $detail, $semanticOutcome',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: AppCurve.standard,
          constraints: const BoxConstraints(
            minHeight: AppTouchTarget.comfortable,
          ),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border(
              left: BorderSide(color: laneColor, width: 3),
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
                      pulse:
                          lane == MissionLane.blocked ||
                          lane == MissionLane.live ||
                          status.isPulsing,
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
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: AppFontSize.xs,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _OutcomePill(lane: lane, entry: entry, since: since),
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: AppIconSize.md,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaneTile extends StatelessWidget {
  const _LaneTile({
    required this.lane,
    required this.color,
    required this.pulse,
    required this.selected,
  });

  final MissionLane lane;
  final Color color;
  final bool pulse;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: missionLaneContainerColor(context, lane),
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
  });

  final MissionLane lane;
  final SessionUiEntry entry;
  final int since;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = missionLaneColor(context, lane);
    final child = switch (lane) {
      MissionLane.blocked => Text(context.l10n.missionControlReview),
      MissionLane.unread => Text(
        context.l10n.missionControlNewCount(entry.unreadCount),
      ),
      MissionLane.live => _LiveElapsedLabel(since: since),
      MissionLane.quiet => Text(missionLaneLabel(context, lane)),
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 36),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: missionLaneContainerColor(context, lane),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: DefaultTextStyle(
        style: theme.textTheme.labelSmall!.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: AppFontSize.xs,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        textAlign: TextAlign.center,
        child: child,
      ),
    );
  }
}

class _LiveElapsedLabel extends StatefulWidget {
  const _LiveElapsedLabel({required this.since});

  final int since;

  @override
  State<_LiveElapsedLabel> createState() => _LiveElapsedLabelState();
}

class _LiveElapsedLabelState extends State<_LiveElapsedLabel> {
  Timer? _timer;
  int _now = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now().millisecondsSinceEpoch);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(formatElapsedShort(_now - widget.since));
  }
}
