import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'mission_control_types.dart';
import 'workspace_identity.dart';

/// What kind of change a [WireEvent] describes.
enum WireEventKind {
  /// New agent output arrived.
  inbound,

  /// The user sent a message (possibly from another device).
  sent,

  /// The agent raised a permission request.
  blocked,

  /// The last message is an error.
  error,

  /// A live agent stopped working.
  done,

  /// A session entered the active set.
  joined,
}

/// One line in the Live wire — a cross-session change worth surfacing.
class WireEvent {
  const WireEvent({
    required this.sessionId,
    required this.sessionName,
    required this.workspaceKey,
    required this.atMs,
    required this.kind,
    this.detail,
  });

  final String sessionId;
  final String sessionName;
  final String workspaceKey;
  final int atMs;
  final WireEventKind kind;

  /// Short text snippet (message preview, tool name). May be null when
  /// the event has no natural content; the row then shows only the
  /// localized kind label.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is WireEvent &&
      other.sessionId == sessionId &&
      other.atMs == atMs &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(sessionId, atMs, kind);
}

/// Immutable per-session observable state fed into [diffWireEvents].
class WireSessionState {
  const WireSessionState({
    required this.name,
    required this.workspaceKey,
    required this.live,
    required this.lane,
    required this.unreadCount,
    required this.lastMessageAt,
    required this.preview,
    required this.role,
    required this.isError,
  });

  final String name;
  final String workspaceKey;
  final bool live;
  final MissionLane lane;
  final int unreadCount;

  /// Timestamp of the newest message, or null when unknown.
  final int? lastMessageAt;
  final String? preview;
  final String? role;
  final bool isError;
}

typedef WireSnapshot = Map<String, WireSessionState>;

/// Derives the events that happened between two snapshots.
///
/// Pure and language-free: callers localize kind labels in the widget
/// layer. The first snapshot seeds the baseline and produces no events,
/// so opening the board never floods it with "joined" rows for every
/// existing session.
List<WireEvent> diffWireEvents({
  required WireSnapshot? previous,
  required WireSnapshot next,
  required int nowMs,
}) {
  if (previous == null) return const [];
  final events = <WireEvent>[];
  for (final entry in next.entries) {
    final id = entry.key;
    final state = entry.value;
    final prev = previous[id];
    if (prev == null) {
      events.add(
        WireEvent(
          sessionId: id,
          sessionName: state.name,
          workspaceKey: state.workspaceKey,
          atMs: nowMs,
          kind: WireEventKind.joined,
          detail: state.preview,
        ),
      );
      continue;
    }

    final advanced =
        state.lastMessageAt != null &&
        (prev.lastMessageAt == null ||
            state.lastMessageAt! > prev.lastMessageAt!);
    if (advanced) {
      final detail = _nonEmpty(state.preview);
      if (state.isError) {
        events.add(
          _event(id, state, nowMs, WireEventKind.error, detail),
        );
      } else if (state.role == 'user') {
        events.add(_event(id, state, nowMs, WireEventKind.sent, detail));
      } else {
        events.add(
          _event(id, state, nowMs, WireEventKind.inbound, detail),
        );
      }
    }

    // Lane transitions only fire when no fresher message event already
    // describes the same moment; a permission raise without a new
    // message still deserves its own line.
    if (prev.lane != MissionLane.blocked &&
        state.lane == MissionLane.blocked &&
        !advanced) {
      events.add(_event(id, state, nowMs, WireEventKind.blocked, null));
    }
    if (prev.live && !state.live && !advanced) {
      final settled =
          state.lane != MissionLane.blocked &&
          state.lane != MissionLane.error;
      if (settled) {
        events.add(_event(id, state, nowMs, WireEventKind.done, null));
      }
    }
  }
  // Newest first; ties break by name so ordering is deterministic.
  events.sort((a, b) {
    final byTime = b.atMs.compareTo(a.atMs);
    return byTime != 0 ? byTime : a.sessionName.compareTo(b.sessionName);
  });
  return events;
}

WireEvent _event(
  String id,
  WireSessionState state,
  int nowMs,
  WireEventKind kind,
  String? detail,
) => WireEvent(
  sessionId: id,
  sessionName: state.name,
  workspaceKey: state.workspaceKey,
  atMs: nowMs,
  kind: kind,
  detail: detail,
);

String? _nonEmpty(String? value) =>
    value == null || value.isEmpty ? null : value;

/// Folds fresh events into the rolling buffer shown by the Live wire.
///
/// - Coalesces an inbound burst: a stream emitting many updates within
///   two minutes replaces the buffer's newest event instead of adding
///   one row per message.
/// - Drops events older than [maxAge] and caps length at [cap].
List<WireEvent> mergeWireEvents(
  List<WireEvent> existing,
  List<WireEvent> incoming, {
  required int nowMs,
  int cap = 40,
  Duration maxAge = const Duration(hours: 2),
}) {
  final floor = nowMs - maxAge.inMilliseconds;
  final merged = existing
      .where((e) => e.atMs >= floor)
      .toList(growable: true);
  for (final event in incoming) {
    if (merged.isNotEmpty &&
        event.kind == WireEventKind.inbound &&
        merged.first.kind == WireEventKind.inbound &&
        merged.first.sessionId == event.sessionId &&
        event.atMs - merged.first.atMs <=
            const Duration(minutes: 2).inMilliseconds) {
      merged[0] = event;
      continue;
    }
    merged.insert(0, event);
  }
  merged.sort((a, b) {
    final byTime = b.atMs.compareTo(a.atMs);
    return byTime != 0 ? byTime : a.sessionName.compareTo(b.sessionName);
  });
  return merged.length > cap ? merged.sublist(0, cap) : merged;
}

/// Collapsible cross-session activity ticker.
///
/// The Live wire answers "what just changed anywhere" without opening a
/// single chat — the many-streams-at-a-glance complement to the focus
/// queue's "what needs me".
class StreamWallSection extends StatefulWidget {
  const StreamWallSection({
    required this.events,
    required this.streamCount,
    required this.onOpenSession,
    required this.onPeekSession,
    super.key,
  });

  final List<WireEvent> events;

  /// Number of streams being watched — used by the empty-state hint.
  final int streamCount;
  final void Function(String sessionId) onOpenSession;
  final void Function(String sessionId) onPeekSession;

  @override
  State<StreamWallSection> createState() => _StreamWallSectionState();
}

class _StreamWallSectionState extends State<StreamWallSection> {
  static const _previewCount = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final accent = cs.tertiary;
    final children = <Widget>[];
    if (widget.events.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.smd,
            AppSpacing.md,
            AppSpacing.smd,
          ),
          child: Row(
            children: [
              Icon(
                Icons.wifi_tethering_rounded,
                size: AppIconSize.sm,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.missionControlLiveWireEmpty(widget.streamCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppFontSize.xs,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final shown = _expanded
          ? widget.events
          : widget.events.take(_previewCount).toList(growable: false);
      for (var i = 0; i < shown.length; i++) {
        children.add(
          _WireRow(
            event: shown[i],
            onOpen: () => widget.onOpenSession(shown[i].sessionId),
            onPeek: () => widget.onPeekSession(shown[i].sessionId),
          ),
        );
      }
      final hidden = widget.events.length - shown.length;
      if (hidden > 0) {
        children.add(
          _DisclosureRow(
            label: l10n.missionControlMoreActions(hidden),
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.radar_rounded,
                size: AppIconSize.sm,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.missionControlLiveWire,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.events.isNotEmpty)
                Text(
                  '${widget.events.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length;i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 58,
                    color: cs.outlineVariant,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WireRow extends StatelessWidget {
  const _WireRow({
    required this.event,
    required this.onOpen,
    required this.onPeek,
  });

  final WireEvent event;
  final VoidCallback onOpen;
  final VoidCallback onPeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final visual = _kindVisual(context, event.kind);
    final detail = event.detail ?? visual.label(l10n);
    final semantics =
        '${event.sessionName}, ${visual.label(l10n)}, $detail';

    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onOpen,
          onLongPress: onPeek,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.comfortable,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: workspaceIdentityColor(
                            context,
                            event.workspaceKey,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(visual.icon, size: AppIconSize.sm, color: visual.color),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: event.sessionName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: AppFontSize.xs,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: '  $detail',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: AppFontSize.xs,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _timeLabel(event.atMs),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: AppFontSize.xxs,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _timeLabel(int atMs) {
    final time = DateTime.fromMillisecondsSinceEpoch(atMs);
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Disclosure row matching the focus queue's "+N more" pattern.
class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.min,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: AppMotion.duration(context, AppDuration.normal),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: AppIconSize.md,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KindVisual {
  const _KindVisual(this.icon, this.color, this._label);

  final IconData icon;
  final Color color;
  final String Function(AppLocalizations) _label;

  String label(AppLocalizations l10n) => _label(l10n);
}

_KindVisual _kindVisual(BuildContext context, WireEventKind kind) {
  final cs = Theme.of(context).colorScheme;
  return switch (kind) {
    WireEventKind.inbound => _KindVisual(
      Icons.subdirectory_arrow_left_rounded,
      cs.primary,
      (l10n) => l10n.missionControlStatUnread,
    ),
    WireEventKind.sent => _KindVisual(
      Icons.subdirectory_arrow_right_rounded,
      cs.onSurfaceVariant,
      (l10n) => l10n.missionControlWireSent,
    ),
    WireEventKind.blocked => _KindVisual(
      missionLaneIcon(MissionLane.blocked),
      missionLaneColor(context, MissionLane.blocked),
      (l10n) => l10n.missionControlStatBlocked,
    ),
    WireEventKind.error => _KindVisual(
      missionLaneIcon(MissionLane.error),
      missionLaneColor(context, MissionLane.error),
      (l10n) => l10n.missionControlStatError,
    ),
    WireEventKind.done => _KindVisual(
      Icons.check_circle_outline_rounded,
      cs.tertiary,
      (l10n) => l10n.missionControlWireDone,
    ),
    WireEventKind.joined => _KindVisual(
      Icons.fiber_new_rounded,
      cs.onSurfaceVariant,
      (l10n) => l10n.missionControlWireJoined,
    ),
  };
}
