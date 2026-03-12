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
      fontSize: AppFontSize.xs,
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

  late SessionStatus _sessionStatus;
  late String _avatarId;
  late String _sessionName;
  late String _sessionSubtitle;

  @override
  void initState() {
    super.initState();
    _computeDerivedValues();
  }

  @override
  void didUpdateWidget(ActiveSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _computeDerivedValues();
    }
  }

  void _computeDerivedValues() {
    _sessionStatus = getSessionStatus(widget.session);
    _avatarId = getSessionAvatarId(widget.session);
    _sessionName = getSessionName(widget.session);
    _sessionSubtitle = getSessionSubtitle(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: _ActiveSessionCardContent(
        session: widget.session,
        sessionStatus: _sessionStatus,
        avatarId: _avatarId,
        sessionName: _sessionName,
        sessionSubtitle: _sessionSubtitle,
        lastMessageTimestamp: widget.lastMessageTimestamp,
        theme: theme,
        colorScheme: theme.colorScheme,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        onTapDown: () => setState(() => _pressed = true),
        onTapUp: () => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
      ),
    );
  }
}

/// Extracted content for [_ActiveSessionCardState].
/// Does not rebuild when press state changes.
class _ActiveSessionCardContent extends StatelessWidget {
  const _ActiveSessionCardContent({
    required this.session,
    required this.sessionStatus,
    required this.avatarId,
    required this.sessionName,
    required this.sessionSubtitle,
    required this.lastMessageTimestamp,
    required this.theme,
    required this.colorScheme,
    required this.onTap,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  final Session session;
  final SessionStatus sessionStatus;
  final String avatarId;
  final String sessionName;
  final String sessionSubtitle;
  final int? lastMessageTimestamp;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft =
        session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);
    final statusWidget =
        _buildStatusText(sessionStatus, theme.textTheme);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        color: cs.primary.withValues(alpha: 0.04),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.12),
          width: AppBorder.hairline,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onTapDown: (_) => onTapDown(),
          onTapUp: (_) => onTapUp(),
          onTapCancel: onTapCancel,
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
                              '${session.id}',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SessionAvatar(
                                id: avatarId,
                                flavor: sessionFlavor,
                                size: 44,
                                showFlavorIcon: true,
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
                                    width: AppSpacing
                                        .xsm,
                                  ),
                                  AppStatusDot(
                                    color: Color(
                                      sessionStatus
                                          .statusDotColor,
                                    ),
                                    pulse: sessionStatus
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
                                  fontSize:
                                      AppFontSize.xs,
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
                        // Timestamp & badges
                        Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ??
                                    session.updatedAt,
                                relative: true,
                              ),
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: cs
                                    .onSurfaceVariant,
                                fontSize:
                                    AppFontSize.xs,
                              ),
                            ),
                            if (todoProgress !=
                                null) ...[
                              const SizedBox(
                                height: AppSpacing.xs,
                              ),
                              TodoProgressBadge(
                                completed:
                                    todoProgress
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

  late SessionStatus _sessionStatus;
  late String _avatarId;
  late String _sessionName;

  @override
  void initState() {
    super.initState();
    _computeDerivedValues();
  }

  @override
  void didUpdateWidget(
    CompactActiveSessionCard oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _computeDerivedValues();
    }
  }

  void _computeDerivedValues() {
    _sessionStatus = getSessionStatus(widget.session);
    _avatarId = getSessionAvatarId(widget.session);
    _sessionName = getSessionName(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: _CompactActiveSessionCardContent(
        session: widget.session,
        sessionStatus: _sessionStatus,
        avatarId: _avatarId,
        sessionName: _sessionName,
        showFlavorIcon: widget.showFlavorIcon,
        lastMessageTimestamp: widget.lastMessageTimestamp,
        selectionMode: widget.selectionMode,
        isSelected: widget.isSelected,
        theme: theme,
        colorScheme: theme.colorScheme,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        onTapDown: () => setState(() => _pressed = true),
        onTapUp: () => setState(() => _pressed = false),
        onTapCancel: () =>
            setState(() => _pressed = false),
      ),
    );
  }
}

/// Extracted content for
/// [_CompactActiveSessionCardState].
/// Does not rebuild when press state changes.
class _CompactActiveSessionCardContent
    extends StatelessWidget {
  const _CompactActiveSessionCardContent({
    required this.session,
    required this.sessionStatus,
    required this.avatarId,
    required this.sessionName,
    required this.showFlavorIcon,
    required this.lastMessageTimestamp,
    required this.selectionMode,
    required this.isSelected,
    required this.theme,
    required this.colorScheme,
    required this.onTap,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  final Session session;
  final SessionStatus sessionStatus;
  final String avatarId;
  final String sessionName;
  final bool showFlavorIcon;
  final int? lastMessageTimestamp;
  final bool selectionMode;
  final bool isSelected;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft =
        session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);
    final statusWidget =
        _buildStatusText(sessionStatus, theme.textTheme);

    final cardColor = isSelected
        ? cs.primary.withValues(alpha: 0.10)
        : cs.primary.withValues(alpha: 0.04);
    final borderColor = isSelected
        ? cs.primary.withValues(alpha: 0.3)
        : cs.primary.withValues(alpha: 0.12);

    return Container(
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
          onTap: onTap,
          onTapDown: (_) => onTapDown(),
          onTapUp: (_) => onTapUp(),
          onTapCancel: onTapCancel,
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
                if (selectionMode)
                  SelectionCheckbox(
                    isSelected: isSelected,
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
                        sessionStatus.statusDotColor,
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
                              '${session.id}',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SessionAvatar(
                                id: avatarId,
                                flavor: sessionFlavor,
                                size: 36,
                                showFlavorIcon:
                                    showFlavorIcon,
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
                                    width: AppSpacing
                                        .xsm,
                                  ),
                                  AppStatusDot(
                                    color: Color(
                                      sessionStatus
                                          .statusDotColor,
                                    ),
                                    pulse: sessionStatus
                                        .isPulsing,
                                    size: 7,
                                  ),
                                ],
                              ),
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
                        // Timestamp & badges
                        Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ??
                                    session.updatedAt,
                                relative: true,
                              ),
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: cs
                                    .onSurfaceVariant,
                                fontSize:
                                    AppFontSize.xs,
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
                                    todoProgress.total,
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

  late SessionStatus _sessionStatus;
  late String _avatarId;
  late String _sessionName;
  late String _sessionSubtitle;
  late BorderRadius _borderRadius;
  Color? _titleColor;
  Color? _cardColor;

  @override
  void initState() {
    super.initState();
    _computeSessionValues();
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
      _computeSessionValues();
      _computeThemeValues();
    }
  }

  void _computeSessionValues() {
    _sessionStatus = getSessionStatus(widget.session);
    _avatarId = getSessionAvatarId(widget.session);
    _sessionName = getSessionName(widget.session);
    _sessionSubtitle = getSessionSubtitle(widget.session);
    _borderRadius = _resolveBorderRadius();
  }

  void _computeThemeValues() {
    final cs = Theme.of(context).colorScheme;
    _titleColor = _sessionStatus.isConnected
        ? cs.onSurface
        : cs.onSurfaceVariant;
    _cardColor = widget.isSelected
        ? cs.primary.withValues(alpha: 0.08)
        : cs.surface;
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

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: _SessionCardContent(
        session: widget.session,
        sessionStatus: _sessionStatus,
        avatarId: _avatarId,
        sessionName: _sessionName,
        sessionSubtitle: _sessionSubtitle,
        lastMessageTimestamp: widget.lastMessageTimestamp,
        lastMessagePreview: widget.lastMessagePreview,
        compact: widget.compact,
        selectionMode: widget.selectionMode,
        isSelected: widget.isSelected,
        onLongPress: widget.onLongPress,
        borderRadius: _borderRadius,
        titleColor: _titleColor ?? theme.colorScheme.onSurfaceVariant,
        cardColor: _cardColor ?? theme.colorScheme.surface,
        theme: theme,
        colorScheme: theme.colorScheme,
        onTap: widget.onTap,
        onTapDown: () => setState(() => _pressed = true),
        onTapUp: () => setState(() => _pressed = false),
        onTapCancel: () =>
            setState(() => _pressed = false),
      ),
    );
  }
}

/// Extracted content for [_SessionCardState].
/// Does not rebuild when press state changes.
class _SessionCardContent extends StatelessWidget {
  const _SessionCardContent({
    required this.session,
    required this.sessionStatus,
    required this.avatarId,
    required this.sessionName,
    required this.sessionSubtitle,
    required this.lastMessageTimestamp,
    required this.lastMessagePreview,
    required this.compact,
    required this.selectionMode,
    required this.isSelected,
    required this.onLongPress,
    required this.borderRadius,
    required this.titleColor,
    required this.cardColor,
    required this.theme,
    required this.colorScheme,
    required this.onTap,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  final Session session;
  final SessionStatus sessionStatus;
  final String avatarId;
  final String sessionName;
  final String sessionSubtitle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;
  final bool compact;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final Color titleColor;
  final Color cardColor;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft =
        session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);
    final statusWidget =
        _buildStatusText(sessionStatus, theme.textTheme);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: isSelected
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
          onTap: onTap,
          onTapDown: (_) => onTapDown(),
          onTapUp: (_) => onTapUp(),
          onTapCancel: onTapCancel,
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
                if (selectionMode)
                  SelectionCheckbox(
                    isSelected: isSelected,
                    borderRadius: borderRadius,
                  )
                else
                  _OfflineAccentBar(
                    isConnected:
                        sessionStatus.isConnected,
                    statusDotColor:
                        sessionStatus.statusDotColor,
                    outlineVariant: cs.outlineVariant,
                  ),
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: compact
                          ? AppSpacing.xsm
                          : AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Padding(
                          padding:
                              const EdgeInsets.only(
                            top: AppSpacing.xxs,
                          ),
                          child: Hero(
                            tag:
                                'session-avatar-'
                                '${session.id}',
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SessionAvatar(
                                  id: avatarId,
                                  flavor: sessionFlavor,
                                  size: compact
                                      ? 36.0
                                      : 44.0,
                                  monochrome:
                                      !sessionStatus
                                          .isConnected,
                                  showFlavorIcon: true,
                                  square: true,
                                  style: AvatarStyle
                                      .pixelated,
                                ),
                                if (hasDraft)
                                  const DraftBadge(),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: compact
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
                                    width: AppSpacing
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
                                    pulse: sessionStatus
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
                                  fontSize:
                                      AppFontSize.xs,
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
                                      AppSpacing.xxs,
                                ),
                                statusWidget,
                              ],
                              // Message preview
                              if (lastMessagePreview !=
                                  null) ...[
                                const SizedBox(
                                  height:
                                      AppSpacing.xs,
                                ),
                                Text(
                                  lastMessagePreview!,
                                  style: theme
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: cs
                                        .onSurfaceVariant
                                        .withValues(
                                      alpha: AppOpacity
                                          .high,
                                    ),
                                    fontSize:
                                        AppFontSize.sm,
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
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ??
                                    session.updatedAt,
                                relative: true,
                              ),
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: cs
                                    .onSurfaceVariant,
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
                                completed:
                                    todoProgress
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
