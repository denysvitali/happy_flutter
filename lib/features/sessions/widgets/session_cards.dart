import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/models/message.dart';
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
    'geometric' => AvatarStyle.geometric,
    'rings' => AvatarStyle.rings,
    'constellation' => AvatarStyle.constellation,
    'wave' => AvatarStyle.wave,
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

/// Derived display values computed from a [Session].
class _SessionDerived {
  _SessionDerived({
    required this.status,
    required this.avatarId,
    required this.name,
    required this.subtitle,
  });

  factory _SessionDerived.from(Session session) {
    return _SessionDerived(
      status: getSessionStatus(session),
      avatarId: getSessionAvatarId(session),
      name: getSessionName(session),
      subtitle: getSessionSubtitle(session),
    );
  }

  final SessionStatus status;
  final String avatarId;
  final String name;
  final String subtitle;
}

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
      fontSize: AppFontSize.xs,
    ),
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
  );
}

/// Builds a Telegram-style message preview with a "You: " prefix
/// for user messages in a subtle accent color.
Widget _buildPreviewText({
  required BuildContext context,
  required String preview,
  required String? role,
  required TextStyle? style,
  required int maxLines,
}) {
  final cs = Theme.of(context).colorScheme;
  final isUser = role == MessageRole.user;
  final baseStyle = style?.copyWith(
    color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.high),
  );

  if (!isUser) {
    return Text(
      preview,
      style: baseStyle,
      overflow: TextOverflow.ellipsis,
      maxLines: maxLines,
    );
  }

  return RichText(
    overflow: TextOverflow.ellipsis,
    maxLines: maxLines,
    text: TextSpan(
      children: [
        TextSpan(
          text: 'You: ',
          style: baseStyle?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        TextSpan(
          text: preview,
          style: baseStyle,
        ),
      ],
    ),
  );
}

/// Name row: session name with trailing status dot.
Widget _buildNameRow({
  required String name,
  required SessionStatus sessionStatus,
  required TextStyle? style,
  Color? dotColor,
  double dotSize = 7,
}) {
  return Row(
    children: [
      Flexible(
        child: Text(
          name,
          style: style,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      const SizedBox(width: AppSpacing.xsm),
      AppStatusDot(
        color: dotColor ??
            Color(sessionStatus.statusDotColor),
        pulse: sessionStatus.isPulsing,
        size: dotSize,
      ),
    ],
  );
}

/// Right column: timestamp + optional unread + todo badges.
Widget _buildTimestampBadges({
  required int timestamp,
  required ThemeData theme,
  required ColorScheme cs,
  int unreadCount = 0,
  ({int completed, int total})? todoProgress,
  double badgeGap = AppSpacing.xxs,
}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        formatTimestamp(timestamp, relative: true),
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: AppFontSize.xs,
        ),
      ),
      if (unreadCount > 0) ...[
        SizedBox(height: badgeGap),
        UnreadBadge(count: unreadCount),
      ],
      if (todoProgress != null) ...[
        SizedBox(height: badgeGap),
        TodoProgressBadge(
          completed: todoProgress.completed,
          total: todoProgress.total,
        ),
      ],
    ],
  );
}

/// Shared avatar with Hero, optional draft badge.
Widget _buildAvatar({
  required String sessionId,
  required String avatarId,
  required String? sessionFlavor,
  required double size,
  required bool showFlavorIcon,
  required bool hasDraft,
  AvatarStyle? avatarStyle,
  bool monochrome = false,
}) {
  return Hero(
    tag: 'session-avatar-$sessionId',
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        SessionAvatar(
          id: avatarId,
          flavor: sessionFlavor,
          size: size,
          showFlavorIcon: showFlavorIcon,
          monochrome: monochrome,
          square: true,
          style: avatarStyle,
        ),
        if (hasDraft) const DraftBadge(),
      ],
    ),
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
    this.lastMessagePreview,
    this.lastMessageRole,
    this.unreadCount = 0,
  });

  final Session session;
  final VoidCallback? onTap;
  final bool showFlavorIcon;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;
  final String? lastMessageRole;
  final int unreadCount;

  @override
  State<ActiveSessionCard> createState() =>
      _ActiveSessionCardState();
}

class _ActiveSessionCardState
    extends State<ActiveSessionCard> {
  bool _pressed = false;
  late _SessionDerived _d;

  @override
  void initState() {
    super.initState();
    _d = _SessionDerived.from(widget.session);
  }

  @override
  void didUpdateWidget(ActiveSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _d = _SessionDerived.from(widget.session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = widget.session;
    final hasPreview = widget.lastMessagePreview != null &&
        widget.lastMessagePreview!.isNotEmpty;
    final statusWidget =
        _buildStatusText(_d.status, theme.textTheme);
    final todoProgress = getTodoProgress(session.todos);
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft =
        session.draft != null && session.draft!.isNotEmpty;

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
          clipBehavior: Clip.hardEdge,
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
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      _buildAvatar(
                        sessionId: session.id,
                        avatarId: _d.avatarId,
                        sessionFlavor: sessionFlavor,
                        size: 44,
                        showFlavorIcon: true,
                        hasDraft: hasDraft,
                        avatarStyle: widget.avatarStyle,
                      ),
                      const SizedBox(
                        width: AppSpacing.md,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            _buildNameRow(
                              name: _d.name,
                              sessionStatus:
                                  _d.status,
                              style: theme
                                  .textTheme.titleSmall
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            const SizedBox(
                              height: AppSpacing.xxs,
                            ),
                            Text(
                              _d.subtitle,
                              style: theme
                                  .textTheme.bodySmall
                                  ?.copyWith(
                                color:
                                    cs.onSurfaceVariant,
                                fontFamily: 'monospace',
                                fontSize:
                                    AppFontSize.xs,
                                height: 1.2,
                              ),
                              overflow:
                                  TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (hasPreview) ...[
                              const SizedBox(
                                height:
                                    AppSpacing.xxs,
                              ),
                              _buildPreviewText(
                                context: context,
                                preview: widget
                                    .lastMessagePreview!,
                                role: widget
                                    .lastMessageRole,
                                style: theme
                                    .textTheme.bodySmall
                                    ?.copyWith(
                                  fontSize:
                                      AppFontSize.xs,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                              ),
                            ],
                            if (statusWidget !=
                                null) ...[
                              const SizedBox(
                                height:
                                    AppSpacing.xxs,
                              ),
                              statusWidget,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: AppSpacing.sm,
                      ),
                      _buildTimestampBadges(
                        timestamp:
                            widget.lastMessageTimestamp ??
                                session.updatedAt,
                        theme: theme,
                        cs: cs,
                        unreadCount: widget.unreadCount,
                        todoProgress: todoProgress,
                        badgeGap: AppSpacing.xxs,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Color(
                        _d.status.statusDotColor,
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
                ),
              ],
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
    this.lastMessagePreview,
    this.lastMessageRole,
    this.selectionMode = false,
    this.isSelected = false,
    this.unreadCount = 0,
  });

  final Session session;
  final VoidCallback? onTap;
  final bool showFlavorIcon;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;
  final String? lastMessageRole;
  final bool selectionMode;
  final bool isSelected;
  final int unreadCount;

  @override
  State<CompactActiveSessionCard> createState() =>
      _CompactActiveSessionCardState();
}

class _CompactActiveSessionCardState
    extends State<CompactActiveSessionCard> {
  bool _pressed = false;
  late _SessionDerived _d;

  @override
  void initState() {
    super.initState();
    _d = _SessionDerived.from(widget.session);
  }

  @override
  void didUpdateWidget(
    CompactActiveSessionCard oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _d = _SessionDerived.from(widget.session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = widget.session;
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft =
        session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);
    final statusWidget =
        _buildStatusText(_d.status, theme.textTheme);
    final hasPreview =
        widget.lastMessagePreview != null &&
        widget.lastMessagePreview!.isNotEmpty;

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
          clipBehavior: Clip.hardEdge,
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
              height: hasPreview ? 72 : 56,
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
                          _d.status.statusDotColor,
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
                          _buildAvatar(
                            sessionId: session.id,
                            avatarId: _d.avatarId,
                            sessionFlavor:
                                sessionFlavor,
                            size: 36,
                            showFlavorIcon:
                                widget.showFlavorIcon,
                            hasDraft: hasDraft,
                            avatarStyle:
                                widget.avatarStyle,
                          ),
                          const SizedBox(
                            width: AppSpacing.sm,
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                _buildNameRow(
                                  name: _d.name,
                                  sessionStatus:
                                      _d.status,
                                  style: theme
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                    color:
                                        cs.onSurface,
                                  ),
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
                                if (hasPreview) ...[
                                  const SizedBox(
                                    height:
                                        AppSpacing.sm,
                                  ),
                                  _buildPreviewText(
                                    context: context,
                                    preview: widget
                                        .lastMessagePreview!,
                                    role: widget
                                        .lastMessageRole,
                                    style: theme
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      fontSize:
                                          AppFontSize
                                              .xs,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: AppSpacing.sm,
                          ),
                          _buildTimestampBadges(
                            timestamp: widget
                                    .lastMessageTimestamp ??
                                session.updatedAt,
                            theme: theme,
                            cs: cs,
                            unreadCount:
                                widget.unreadCount,
                            todoProgress:
                                todoProgress,
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
    this.lastMessageRole,
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
  final String? lastMessageRole;

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  bool _pressed = false;
  late _SessionDerived _d;
  late BorderRadius _borderRadius;
  Color? _titleColor;
  Color? _cardColor;

  @override
  void initState() {
    super.initState();
    _d = _SessionDerived.from(widget.session);
    _borderRadius = _resolveBorderRadius();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _computeThemeValues();
  }

  @override
  void didUpdateWidget(SessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.isSingle != widget.isSingle ||
        oldWidget.isFirst != widget.isFirst ||
        oldWidget.isLast != widget.isLast ||
        oldWidget.isSelected != widget.isSelected) {
      _d = _SessionDerived.from(widget.session);
      _borderRadius = _resolveBorderRadius();
      _computeThemeValues();
    }
  }

  void _computeThemeValues() {
    final cs = Theme.of(context).colorScheme;
    _titleColor = _d.status.isConnected
        ? cs.onSurface
        : cs.onSurfaceVariant;
    _cardColor = widget.isSelected
        ? cs.primary.withValues(alpha: 0.08)
        : cs.surfaceContainerHighest;
  }

  BorderRadius _resolveBorderRadius() {
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
    final session = widget.session;
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft =
        session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);
    final statusWidget =
        _buildStatusText(_d.status, theme.textTheme);

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: _borderRadius,
            side: widget.isSelected
                ? BorderSide(
                    color: cs.primary.withValues(
                      alpha: 0.3,
                    ),
                  )
                : BorderSide.none,
          ),
          elevation: 0,
          color:
              _cardColor ?? cs.surfaceContainerHighest,
          clipBehavior: Clip.hardEdge,
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
            borderRadius: _borderRadius,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    widget.selectionMode
                        ? 36 + AppSpacing.md
                        : AppSpacing.md,
                    widget.compact
                        ? AppSpacing.xsm
                        : AppSpacing.sm,
                    AppSpacing.md,
                    widget.compact
                        ? AppSpacing.xsm
                        : AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          top: AppSpacing.xxs,
                        ),
                        child: _buildAvatar(
                          sessionId: session.id,
                          avatarId: _d.avatarId,
                          sessionFlavor:
                              sessionFlavor,
                          size: widget.compact
                              ? 36.0
                              : 44.0,
                          showFlavorIcon: true,
                          hasDraft: hasDraft,
                          avatarStyle:
                              widget.avatarStyle,
                          monochrome: !_d
                              .status.isConnected,
                        ),
                      ),
                      SizedBox(
                        width: widget.compact
                            ? AppSpacing.sm
                            : AppSpacing.md,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            _buildNameRow(
                              name: _d.name,
                              sessionStatus:
                                  _d.status,
                              style: theme
                                  .textTheme.titleSmall
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.w600,
                                color: _titleColor ??
                                    cs
                                        .onSurfaceVariant,
                              ),
                              dotColor: _d.status
                                      .isConnected
                                  ? null
                                  : cs.outlineVariant,
                            ),
                            const SizedBox(
                              height:
                                  AppSpacing.xxs,
                            ),
                            Text(
                              _d.subtitle,
                              style: theme
                                  .textTheme.bodySmall
                                  ?.copyWith(
                                color:
                                    cs.onSurfaceVariant,
                                fontFamily:
                                    'monospace',
                                fontSize:
                                    AppFontSize.xs,
                                height: 1.2,
                              ),
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              maxLines: 1,
                            ),
                            if (statusWidget !=
                                null) ...[
                              const SizedBox(
                                height:
                                    AppSpacing.xxs,
                              ),
                              statusWidget,
                            ],
                            if (widget
                                    .lastMessagePreview !=
                                null) ...[
                              const SizedBox(
                                height:
                                    AppSpacing.sm,
                              ),
                              _buildPreviewText(
                                context: context,
                                preview: widget
                                    .lastMessagePreview!,
                                role: widget
                                    .lastMessageRole,
                                style: theme
                                    .textTheme.bodySmall
                                    ?.copyWith(
                                  fontSize:
                                      AppFontSize.sm,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: AppSpacing.sm,
                      ),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatTimestamp(
                              widget.lastMessageTimestamp ??
                                  session.updatedAt,
                              relative: true,
                            ),
                            style: theme
                                .textTheme.labelSmall
                                ?.copyWith(
                              color:
                                  cs.onSurfaceVariant,
                              fontSize:
                                  AppFontSize.xs,
                            ),
                          ),
                          if (todoProgress !=
                              null) ...[
                            const SizedBox(
                              height:
                                  AppSpacing.xsm,
                            ),
                            TodoProgressBadge(
                              completed: todoProgress
                                  .completed,
                              total:
                                  todoProgress.total,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: widget.selectionMode
                      ? SelectionCheckbox(
                          isSelected:
                              widget.isSelected,
                          borderRadius:
                              _borderRadius,
                        )
                      : _OfflineAccentBar(
                          isConnected:
                              _d.status.isConnected,
                          statusDotColor:
                              _d.status.statusDotColor,
                          outlineVariant:
                              cs.outlineVariant,
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
