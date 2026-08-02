import 'package:flutter/material.dart';

import '../../../core/components/pressable_card.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';
import 'session_badges.dart';
import 'session_cards.dart';

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
    this.archiveCountdownLabel,
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
  final String? archiveCountdownLabel;

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  late SessionDerived _d;
  late BorderRadius _borderRadius;
  Color? _titleColor;
  Color? _cardColor;

  @override
  void initState() {
    super.initState();
    _d = SessionDerived.from(widget.session);
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
      _d = SessionDerived.from(widget.session);
      _borderRadius = _resolveBorderRadius();
      _computeThemeValues();
    }
  }

  void _computeThemeValues() {
    final cs = Theme.of(context).colorScheme;
    _titleColor = _d.status.isConnected ? cs.onSurface : cs.onSurfaceVariant;
    _cardColor = widget.isSelected
        ? cs.primary.withValues(alpha: 0.08)
        : cs.surfaceContainerHighest;
  }

  BorderRadius _resolveBorderRadius() {
    if (widget.isSingle) {
      return BorderRadius.circular(AppRadius.md);
    }
    if (widget.isFirst) {
      return const BorderRadius.vertical(top: Radius.circular(AppRadius.md));
    }
    if (widget.isLast) {
      return const BorderRadius.vertical(bottom: Radius.circular(AppRadius.md));
    }
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = widget.session;
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);
    final statusWidget = buildStatusText(_d.status, theme.textTheme);
    final activityLine = buildActivityLine(
      context: context,
      session: session,
      preview: widget.lastMessagePreview,
      previewRole: widget.lastMessageRole,
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: AppFontSize.sm,
        height: 1.3,
      ),
      maxLines: 2,
    );

    return PressableCard(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      semanticLabel: '${_d.name}, ${_d.status.statusText}, ${_d.subtitle}',
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _borderRadius,
          side: widget.isSelected
              ? BorderSide(color: cs.primary.withValues(alpha: 0.3))
              : BorderSide.none,
        ),
        elevation: 0,
        color: _cardColor ?? cs.surfaceContainerHighest,
        clipBehavior: Clip.hardEdge,
        child: Stack(
              fit: StackFit.passthrough,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    widget.selectionMode ? 36 + AppSpacing.md : AppSpacing.md,
                    widget.compact ? AppSpacing.xsm : AppSpacing.sm,
                    AppSpacing.md,
                    widget.compact ? AppSpacing.xsm : AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: buildSessionAvatar(
                          sessionId: session.id,
                          avatarId: _d.avatarId,
                          sessionFlavor: sessionFlavor,
                          size: widget.compact
                              ? AppAvatarSize.small
                              : AppAvatarSize.large,
                          showFlavorIcon: true,
                          hasDraft: hasDraft,
                          avatarStyle: widget.avatarStyle,
                          monochrome: !_d.status.isConnected,
                        ),
                      ),
                      SizedBox(
                        width: widget.compact ? AppSpacing.sm : AppSpacing.md,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildNameRow(
                              name: _d.name,
                              sessionStatus: _d.status,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _titleColor ?? cs.onSurfaceVariant,
                              ),
                              dotColor: _d.status.isConnected
                                  ? null
                              : cs.outlineVariant,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        if (activityLine == null)
                          Text(
                            _d.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFamily: 'monospace',
                                fontSize: AppFontSize.xs,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (statusWidget != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              statusWidget,
                            ],
                            if (activityLine != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              activityLine,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatTimestamp(
                              widget.lastMessageTimestamp ??
                                  session.lastMessageAt ??
                                  session.updatedAt,
                              relative: true,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: AppFontSize.xs,
                            ),
                          ),
                          if (todoProgress != null) ...[
                            const SizedBox(height: AppSpacing.xsm),
                            TodoProgressBadge(
                              completed: todoProgress.completed,
                              total: todoProgress.total,
                            ),
                          ],
                          if (widget.archiveCountdownLabel != null) ...[
                            const SizedBox(height: AppSpacing.xsm),
                            Text(
                              widget.archiveCountdownLabel!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: AppFontSize.xxs,
                              ),
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
                          isSelected: widget.isSelected,
                          borderRadius: _borderRadius,
                        )
                      : _OfflineAccentBar(
                          isConnected: _d.status.isConnected,
                          statusDotColor: _d.status.statusDotColor,
                          outlineVariant: cs.outlineVariant,
                        ),
                ),
              ],
            ),
        ),
      );
  }
}

// ────────────────────────────────────────────────────────────
// Accent bar for offline / connected sessions
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
      width: AppBorder.accent,
      color: isConnected ? Color(statusDotColor) : outlineVariant,
    );
  }
}
