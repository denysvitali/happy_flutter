import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/models/session.dart';
import '../../../core/models/todo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';
import 'session_badges.dart';

/// Parses an avatar style string to the corresponding
/// [AvatarStyle] enum. Returns null if unknown.
AvatarStyle? parseAvatarStyle(String? style) {
  return switch (style) {
    'gradient' => AvatarStyle.gradient,
    'pixelated' => AvatarStyle.pixelated,
    'brutalist' => AvatarStyle.brutalist,
    _ => null,
  };
}

/// Computes todo progress, returning (completed, total) or
/// null if todos are empty or all completed.
({int completed, int total})? getTodoProgress(
  List<TodoItem>? todos,
) {
  if (todos == null || todos.isEmpty) return null;
  final total = todos.length;
  final completed =
      todos.where((t) => t.status == TodoState.completed).length;
  if (completed >= total) return null;
  return (completed: completed, total: total);
}

// ────────────────────────────────────────────────────────────
// Shared helpers
// ────────────────────────────────────────────────────────────

/// Builds the status text widget shown beneath the session
/// name when the session is connected and has a meaningful
/// status (thinking, permission required, etc.).
Widget? _buildStatusText(
  SessionStatus status,
  TextTheme textTheme,
) {
  if (!status.shouldShowStatus || !status.isConnected) {
    return null;
  }
  return Text(
    status.statusText,
    style: textTheme.labelSmall?.copyWith(
      color: Color(status.statusColor),
      fontWeight: FontWeight.w500,
      fontSize: 11,
    ),
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
  );
}

// ────────────────────────────────────────────────────────────
// Active session card — full-size variant
// ────────────────────────────────────────────────────────────

/// Active session card with smooth press animation and
/// clear visual hierarchy.
class ActiveSessionCard extends StatefulWidget {
  const ActiveSessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.avatarStyle,
    this.lastMessageTimestamp,
  });

  final Session session;
  final VoidCallback? onTap;
  final bool showFlavorIcon;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;

  @override
  State<ActiveSessionCard> createState() =>
      _ActiveSessionCardState();
}

class _ActiveSessionCardState extends State<ActiveSessionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(widget.session);
    final avatarId = getSessionAvatarId(widget.session);
    final sessionName = getSessionName(widget.session);
    final sessionSubtitle =
        getSessionSubtitle(widget.session);
    final sessionFlavor =
        widget.session.metadata?.flavor;
    final hasDraft = widget.session.draft != null &&
        widget.session.draft!.isNotEmpty;
    final todoProgress =
        getTodoProgress(widget.session.todos);
    final statusWidget =
        _buildStatusText(sessionStatus, theme.textTheme);

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          color: cs.primary.withValues(alpha: 0.04),
          border: Border.all(
            color:
                cs.primary.withValues(alpha: 0.12),
            width: AppBorder.hairline,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
            onTapDown: (_) =>
                setState(() => _pressed = true),
            onTapUp: (_) =>
                setState(() => _pressed = false),
            onTapCancel: () =>
                setState(() => _pressed = false),
            splashColor:
                cs.primary.withValues(alpha: 0.08),
            highlightColor:
                cs.primary.withValues(alpha: 0.04),
            borderRadius:
                BorderRadius.circular(AppRadius.md),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Color(
                        sessionStatus.statusDotColor,
                      ),
                      borderRadius:
                          const BorderRadius.only(
                        topLeft: Radius.circular(
                          AppRadius.md,
                        ),
                        bottomLeft: Radius.circular(
                          AppRadius.md,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Hero(
                            tag:
                                'session-avatar-'
                                '${widget.session.id}',
                            child: Stack(
                              clipBehavior:
                                  Clip.none,
                              children: [
                                SessionAvatar(
                                  id: avatarId,
                                  flavor:
                                      sessionFlavor,
                                  size: 44,
                                  showFlavorIcon:
                                      true,
                                  square: true,
                                  style: AvatarStyle
                                      .pixelated,
                                ),
                                if (hasDraft)
                                  const DraftBadge(),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: AppSpacing.md,
                          ),
                          // Title / subtitle / status
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                // Name row
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        sessionName,
                                        style: theme
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                        ),
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(
                                      width:
                                          AppSpacing
                                              .xsm,
                                    ),
                                    AppStatusDot(
                                      color: Color(
                                        sessionStatus
                                            .statusDotColor,
                                      ),
                                      pulse:
                                          sessionStatus
                                              .isPulsing,
                                      size: 7,
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height:
                                      AppSpacing.xxs,
                                ),
                                // Subtitle (path)
                                Text(
                                  sessionSubtitle,
                                  style: theme
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: cs
                                        .onSurfaceVariant,
                                    fontFamily:
                                        'monospace',
                                    fontSize: 11,
                                    height: 1.2,
                                  ),
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  maxLines: 1,
                                ),
                                // Status text
                                if (statusWidget !=
                                    null) ...[
                                  const SizedBox(
                                    height:
                                        AppSpacing
                                            .xxs,
                                  ),
                                  statusWidget,
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: AppSpacing.sm,
                          ),
                          // Timestamp & badges
                          Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .end,
                            children: [
                              Text(
                                formatTimestamp(
                                  widget.lastMessageTimestamp ??
                                      widget
                                          .session
                                          .updatedAt,
                                  relative: true,
                                ),
                                style: theme
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                  color: cs
                                      .onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              if (todoProgress !=
                                  null) ...[
                                const SizedBox(
                                  height:
                                      AppSpacing.xs,
                                ),
                                TodoProgressBadge(
                                  completed:
                                      todoProgress
                                          .completed,
                                  total:
                                      todoProgress
                                          .total,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
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
}

// ────────────────────────────────────────────────────────────
// Compact active session card (~56px height)
// ────────────────────────────────────────────────────────────

/// Compact active session row with press animation.
class CompactActiveSessionCard extends StatefulWidget {
  const CompactActiveSessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.avatarStyle,
    this.lastMessageTimestamp,
    this.selectionMode = false,
    this.isSelected = false,
  });

  final Session session;
  final VoidCallback? onTap;
  final bool showFlavorIcon;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final bool selectionMode;
  final bool isSelected;

  @override
  State<CompactActiveSessionCard> createState() =>
      _CompactActiveSessionCardState();
}

class _CompactActiveSessionCardState
    extends State<CompactActiveSessionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus =
        getSessionStatus(widget.session);
    final avatarId =
        getSessionAvatarId(widget.session);
    final sessionName =
        getSessionName(widget.session);
    final sessionFlavor =
        widget.session.metadata?.flavor;
    final hasDraft = widget.session.draft != null &&
        widget.session.draft!.isNotEmpty;
    final todoProgress =
        getTodoProgress(widget.session.todos);
    final statusWidget =
        _buildStatusText(sessionStatus, theme.textTheme);

    final cardColor = widget.isSelected
        ? cs.primary.withValues(alpha: 0.10)
        : cs.primary.withValues(alpha: 0.04);
    final borderColor = widget.isSelected
        ? cs.primary.withValues(alpha: 0.3)
        : cs.primary.withValues(alpha: 0.12);

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 1,
        ),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          color: cardColor,
          border: Border.all(
            color: borderColor,
            width: AppBorder.hairline,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
            onTapDown: (_) =>
                setState(() => _pressed = true),
            onTapUp: (_) =>
                setState(() => _pressed = false),
            onTapCancel: () =>
                setState(() => _pressed = false),
            splashColor:
                cs.primary.withValues(alpha: 0.08),
            highlightColor:
                cs.primary.withValues(alpha: 0.04),
            borderRadius:
                BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              height: 56,
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  if (widget.selectionMode)
                    SelectionCheckbox(
                      isSelected: widget.isSelected,
                      borderRadius:
                          BorderRadius.circular(
                        AppRadius.md,
                      ),
                    )
                  else
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: Color(
                          sessionStatus
                              .statusDotColor,
                        ),
                        borderRadius:
                            const BorderRadius.only(
                          topLeft: Radius.circular(
                            AppRadius.md,
                          ),
                          bottomLeft:
                              Radius.circular(
                            AppRadius.md,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Hero(
                            tag:
                                'session-avatar-'
                                '${widget.session.id}',
                            child: Stack(
                              clipBehavior:
                                  Clip.none,
                              children: [
                                SessionAvatar(
                                  id: avatarId,
                                  flavor:
                                      sessionFlavor,
                                  size: 36,
                                  showFlavorIcon:
                                      widget
                                          .showFlavorIcon,
                                  square: true,
                                  style: AvatarStyle
                                      .pixelated,
                                ),
                                if (hasDraft)
                                  const DraftBadge(),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: AppSpacing.sm,
                          ),
                          // Name + status
                          Expanded(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        sessionName,
                                        style: theme
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                          color: cs
                                              .onSurface,
                                        ),
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(
                                      width:
                                          AppSpacing
                                              .xsm,
                                    ),
                                    AppStatusDot(
                                      color: Color(
                                        sessionStatus
                                            .statusDotColor,
                                      ),
                                      pulse:
                                          sessionStatus
                                              .isPulsing,
                                      size: 7,
                                    ),
                                  ],
                                ),
                                if (statusWidget !=
                                    null) ...[
                                  const SizedBox(
                                    height:
                                        AppSpacing
                                            .xxs,
                                  ),
                                  statusWidget,
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: AppSpacing.sm,
                          ),
                          // Timestamp & badges
                          Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .end,
                            children: [
                              Text(
                                formatTimestamp(
                                  widget.lastMessageTimestamp ??
                                      widget
                                          .session
                                          .updatedAt,
                                  relative: true,
                                ),
                                style: theme
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                  color: cs
                                      .onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              if (todoProgress !=
                                  null) ...[
                                const SizedBox(
                                  height:
                                      AppSpacing.xxs,
                                ),
                                TodoProgressBadge(
                                  completed:
                                      todoProgress
                                          .completed,
                                  total:
                                      todoProgress
                                          .total,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
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
}

// ────────────────────────────────────────────────────────────
// Session card — archived / inactive sessions
// ────────────────────────────────────────────────────────────

/// Session card for archived/inactive sessions with
/// press animation and improved visual hierarchy.
class SessionCard extends StatefulWidget {
  const SessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.onLongPress,
    this.isFirst = false,
    this.isLast = false,
    this.isSingle = false,
    this.showDateHeader = false,
    this.compact = false,
    this.selectionMode = false,
    this.isSelected = false,
    this.avatarStyle,
    this.lastMessageTimestamp,
    this.lastMessagePreview,
  });

  final Session session;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isFirst;
  final bool isLast;
  final bool isSingle;
  final bool showDateHeader;
  final bool compact;
  final bool selectionMode;
  final bool isSelected;
  final bool showFlavorIcon;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;

  @override
  State<SessionCard> createState() =>
      _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  bool _pressed = false;

  BorderRadius _borderRadius() {
    if (widget.isSingle) {
      return BorderRadius.circular(AppRadius.md);
    }
    if (widget.isFirst) {
      return const BorderRadius.vertical(
        top: Radius.circular(AppRadius.md),
      );
    }
    if (widget.isLast) {
      return const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.md),
      );
    }
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus =
        getSessionStatus(widget.session);
    final avatarId =
        getSessionAvatarId(widget.session);
    final sessionName =
        getSessionName(widget.session);
    final sessionSubtitle =
        getSessionSubtitle(widget.session);
    final sessionFlavor =
        widget.session.metadata?.flavor;
    final hasDraft = widget.session.draft != null &&
        widget.session.draft!.isNotEmpty;
    final todoProgress =
        getTodoProgress(widget.session.todos);
    final statusWidget =
        _buildStatusText(sessionStatus, theme.textTheme);

    final borderRadius = _borderRadius();

    final titleColor = sessionStatus.isConnected
        ? cs.onSurface
        : cs.onSurfaceVariant;
    final cardColor = widget.isSelected
        ? cs.primary.withValues(alpha: 0.08)
        : cs.surface;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: widget.isSelected
                ? BorderSide(
                    color: cs.primary.withValues(
                      alpha: 0.3,
                    ),
                  )
                : BorderSide.none,
          ),
          elevation: 0,
          color: cardColor,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) =>
                setState(() => _pressed = true),
            onTapUp: (_) =>
                setState(() => _pressed = false),
            onTapCancel: () =>
                setState(() => _pressed = false),
            splashColor:
                cs.primary.withValues(alpha: 0.08),
            highlightColor:
                cs.primary.withValues(alpha: 0.04),
            borderRadius: borderRadius,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  // Leading: selection or accent
                  if (widget.selectionMode)
                    SelectionCheckbox(
                      isSelected: widget.isSelected,
                      borderRadius: borderRadius,
                    )
                  else
                    _OfflineAccentBar(
                      isConnected:
                          sessionStatus.isConnected,
                      statusDotColor:
                          sessionStatus
                              .statusDotColor,
                      outlineVariant:
                          cs.outlineVariant,
                    ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: widget.compact
                            ? AppSpacing.xsm
                            : AppSpacing.sm,
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          // Avatar
                          Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              top: AppSpacing.xxs,
                            ),
                            child: Hero(
                              tag:
                                  'session-avatar-'
                                  '${widget.session.id}',
                              child: Stack(
                                clipBehavior:
                                    Clip.none,
                                children: [
                                  SessionAvatar(
                                    id: avatarId,
                                    flavor:
                                        sessionFlavor,
                                    size:
                                        widget
                                            .compact
                                        ? 36.0
                                        : 44.0,
                                    monochrome:
                                        !sessionStatus
                                            .isConnected,
                                    showFlavorIcon:
                                        true,
                                    square: true,
                                    style:
                                        AvatarStyle
                                            .pixelated,
                                  ),
                                  if (hasDraft)
                                    const DraftBadge(),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: widget.compact
                                ? AppSpacing.sm
                                : AppSpacing.md,
                          ),
                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                // Name row
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        sessionName,
                                        style: theme
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                          color:
                                              titleColor,
                                        ),
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(
                                      width:
                                          AppSpacing
                                              .xsm,
                                    ),
                                    AppStatusDot(
                                      color: sessionStatus
                                              .isConnected
                                          ? Color(
                                              sessionStatus
                                                  .statusDotColor,
                                            )
                                          : cs
                                              .outlineVariant,
                                      pulse:
                                          sessionStatus
                                              .isPulsing,
                                      size: 7,
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height:
                                      AppSpacing.xxs,
                                ),
                                // Path subtitle
                                Text(
                                  sessionSubtitle,
                                  style: theme
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: cs
                                        .onSurfaceVariant,
                                    fontFamily:
                                        'monospace',
                                    fontSize: 11,
                                    height: 1.2,
                                  ),
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  maxLines: 1,
                                ),
                                // Status text
                                if (statusWidget !=
                                    null) ...[
                                  const SizedBox(
                                    height:
                                        AppSpacing
                                            .xxs,
                                  ),
                                  statusWidget,
                                ],
                                // Message preview
                                if (widget
                                        .lastMessagePreview !=
                                    null) ...[
                                  const SizedBox(
                                    height:
                                        AppSpacing
                                            .xs,
                                  ),
                                  Text(
                                    widget
                                        .lastMessagePreview!,
                                    style: theme
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color: cs
                                          .onSurfaceVariant
                                          .withValues(
                                        alpha:
                                            AppOpacity
                                                .high,
                                      ),
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    maxLines: 2,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: AppSpacing.sm,
                          ),
                          // Timestamp & badges
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .end,
                            children: [
                              Text(
                                formatTimestamp(
                                  widget.lastMessageTimestamp ??
                                      widget
                                          .session
                                          .updatedAt,
                                  relative: true,
                                ),
                                style: theme
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                  color: cs
                                      .onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              if (todoProgress !=
                                  null) ...[
                                const SizedBox(
                                  height:
                                      AppSpacing.xsm,
                                ),
                                TodoProgressBadge(
                                  completed:
                                      todoProgress
                                          .completed,
                                  total:
                                      todoProgress
                                          .total,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
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
}

// ────────────────────────────────────────────────────────────
// Shared accent bar for offline sessions
// ────────────────────────────────────────────────────────────

class _OfflineAccentBar extends StatelessWidget {
  const _OfflineAccentBar({
    required this.isConnected,
    required this.statusDotColor,
    required this.outlineVariant,
  });

  final bool isConnected;
  final int statusDotColor;
  final Color outlineVariant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      color: isConnected
          ? Color(statusDotColor)
          : outlineVariant,
    );
  }
}
