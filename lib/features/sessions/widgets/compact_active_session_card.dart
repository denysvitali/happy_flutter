import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../session_avatar.dart';
import 'session_badges.dart';
import 'session_cards.dart';

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
    this.archiveCountdownLabel,
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
  final String? archiveCountdownLabel;

  @override
  State<CompactActiveSessionCard> createState() =>
      _CompactActiveSessionCardState();
}

class _CompactActiveSessionCardState extends State<CompactActiveSessionCard> {
  bool _pressed = false;
  late SessionDerived _d;

  @override
  void initState() {
    super.initState();
    _d = SessionDerived.from(widget.session);
  }

  @override
  void didUpdateWidget(CompactActiveSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _d = SessionDerived.from(widget.session);
    }
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
    final hasPreview =
        widget.lastMessagePreview != null &&
        widget.lastMessagePreview!.isNotEmpty;

    final needsAttention = widget.unreadCount > 0;
    final cardColor = widget.isSelected
        ? cs.primary.withValues(alpha: 0.10)
        : cs.surfaceContainerLow;
    final borderColor = widget.isSelected
        ? cs.primary.withValues(alpha: 0.32)
        : cs.outlineVariant.withValues(alpha: 0.55);
    // 3-px left accent: primary when unread, status-dot color otherwise.
    final accentColor = needsAttention
        ? cs.primary
        : Color(_d.status.statusDotColor);

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
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: cardColor,
          border: Border.all(color: borderColor, width: AppBorder.hairline),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            splashColor: cs.primary.withValues(alpha: 0.08),
            highlightColor: cs.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              height: hasPreview ? 72 : 56,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.selectionMode)
                    SelectionCheckbox(
                      isSelected: widget.isSelected,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    )
                  else
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppRadius.md),
                          bottomLeft: Radius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          buildSessionAvatar(
                            sessionId: session.id,
                            avatarId: _d.avatarId,
                            sessionFlavor: sessionFlavor,
                            size: 36,
                            showFlavorIcon: widget.showFlavorIcon,
                            hasDraft: hasDraft,
                            avatarStyle: widget.avatarStyle,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildNameRow(
                                  name: _d.name,
                                  sessionStatus: _d.status,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                  pulseDot: needsAttention,
                                ),
                                if (statusWidget != null) ...[
                                  const SizedBox(height: AppSpacing.xxs),
                                  statusWidget,
                                ],
                                if (hasPreview) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  buildPreviewText(
                                    context: context,
                                    preview: widget.lastMessagePreview!,
                                    role: widget.lastMessageRole,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: AppFontSize.xs,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          buildTimestampBadges(
                            timestamp:
                                widget.lastMessageTimestamp ??
                                session.lastMessageAt ??
                                session.updatedAt,
                            theme: theme,
                            cs: cs,
                            unreadCount: widget.unreadCount,
                            todoProgress: todoProgress,
                            archiveCountdownLabel: widget.archiveCountdownLabel,
                          ),
                          if (session.pinned) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              Icons.push_pin,
                              size: AppSpacing.lg,
                              color: cs.primary,
                            ),
                          ],
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
