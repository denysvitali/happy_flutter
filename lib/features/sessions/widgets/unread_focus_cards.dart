import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_button_style.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/snack.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import '../session_avatar.dart';
import 'session_badges.dart';
import 'session_cards.dart';
import 'session_list_details.dart';

/// Smaller values need user action sooner. Routine work stays in All Sessions.
int sessionAttentionPriority(
  Session session, {
  required int unreadCount,
  String? lastMessageRole,
  bool lastMessageIsError = false,
}) {
  if (session.agentState?.requests?.isNotEmpty ?? false) return 0;
  if (session.hasLifecycleError || lastMessageIsError) return 1;
  if (unreadCount > 0) {
    return !session.thinking && lastMessageRole == 'agent' ? 2 : 3;
  }
  return 4;
}

/// Attention card with a quiet surface, slim accent and readable preview.
class NeedsAttentionCard extends StatefulWidget {
  const NeedsAttentionCard({
    required this.session,
    required this.showFlavorIcon,
    required this.onTap,
    required this.onLongPress,
    super.key,
    this.avatarStyle,
    this.lastMessageTimestamp,
    this.lastMessagePreview,
    this.lastMessageRole,
    this.selectionMode = false,
    this.isSelected = false,
    this.unreadCount = 0,
    this.permissionRequests,
    this.lastMessageIsError = false,
  });

  final Session session;
  final bool showFlavorIcon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;
  final String? lastMessageRole;
  final bool selectionMode;
  final bool isSelected;
  final int unreadCount;

  /// Pending permission requests; when non-empty the card renders
  /// inline Allow/Deny so a blocked agent unblocks without a tap into
  /// the chat.
  final Map<String, RequestInfo>? permissionRequests;
  final bool lastMessageIsError;

  @override
  State<NeedsAttentionCard> createState() => _NeedsAttentionCardState();
}

class _NeedsAttentionCardState extends State<NeedsAttentionCard> {
  late SessionDerived _d;

  @override
  void initState() {
    super.initState();
    _d = SessionDerived.from(widget.session);
  }

  @override
  void didUpdateWidget(NeedsAttentionCard oldWidget) {
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
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);
    final hasApproval = widget.permissionRequests?.isNotEmpty ?? false;
    final priority = sessionAttentionPriority(
      session,
      unreadCount: widget.unreadCount,
      lastMessageRole: widget.lastMessageRole,
      lastMessageIsError: widget.lastMessageIsError,
    );
    final reason = hasApproval
        ? context.l10n.chatStatusApprovalNeeded
        : priority == 1
        ? context.l10n.commonError
        : priority == 2
        ? context.l10n.sessionsUnreadAnswer
        : priority == 3
        ? context.l10n.sessionsUnreadActivity
        : null;
    final attentionColor = hasApproval || priority == 1 ? cs.error : cs.primary;
    final statusWidget = reason == null
        ? buildStatusText(_d.status, theme.textTheme)
        : Text(reason, style: AppText.label(theme, attentionColor));
    final hasPreview =
        widget.lastMessagePreview != null &&
        widget.lastMessagePreview!.isNotEmpty;

    final bgColor = widget.isSelected
        ? Color.alphaBlend(cs.primary.withValues(alpha: 0.08), cs.surface)
        : cs.surface;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: widget.isSelected
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.45),
            width: AppBorder.hairline,
          ),
        ),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            onLongPress: widget.onLongPress,
            child: Stack(
              children: [
                if (!widget.selectionMode)
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: attentionColor,
                      child: const SizedBox(width: AppBorder.accent),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.selectionMode)
                            SelectionCheckbox(
                              isSelected: widget.isSelected,
                              borderRadius: BorderRadius.zero,
                            )
                          else
                            buildSessionAvatar(
                              sessionId: session.id,
                              avatarId: _d.avatarId,
                              sessionFlavor: session.metadata?.flavor,
                              size: AppAvatarSize.small,
                              showFlavorIcon: widget.showFlavorIcon,
                              hasDraft: hasDraft,
                              avatarStyle: widget.avatarStyle,
                            ),
                          const SizedBox(width: AppSpacing.xsm),
                          Expanded(
                            child: SessionListDetails(
                              name: _d.name,
                              titleMaxLines: 1,
                              timestamp:
                                  widget.lastMessageTimestamp ??
                                  session.lastMessageAt ??
                                  session.updatedAt,
                              sessionStatus: _d.status,
                              status: statusWidget,
                              unreadCount: widget.unreadCount,
                              todoProgress: todoProgress,
                              isPinned: session.pinned,
                              detail: hasPreview
                                  ? buildPreviewText(
                                      context: context,
                                      preview: widget.lastMessagePreview!,
                                      role: widget.lastMessageRole,
                                      style: AppText.secondary(theme),
                                      maxLines: 1,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      if (widget.permissionRequests != null &&
                          widget.permissionRequests!.isNotEmpty &&
                          !widget.selectionMode) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _CardPermissionRow(
                          sessionId: session.id,
                          requests: widget.permissionRequests!,
                          isOnline: session.presence == 'online',
                        ),
                      ],
                    ],
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

/// Inline Allow/Deny for the oldest pending permission request, so a
/// blocked agent unblocks without opening the chat. Mirrors the
/// handler in `PendingPermissionBar`.
class _CardPermissionRow extends ConsumerStatefulWidget {
  const _CardPermissionRow({
    required this.sessionId,
    required this.requests,
    required this.isOnline,
  });

  final String sessionId;
  final Map<String, RequestInfo> requests;
  final bool isOnline;

  @override
  ConsumerState<_CardPermissionRow> createState() => _CardPermissionRowState();
}

class _CardPermissionRowState extends ConsumerState<_CardPermissionRow> {
  bool _busy = false;

  Future<void> _act(bool allow) async {
    if (_busy || !widget.isOnline || widget.requests.isEmpty) return;
    final requestId = widget.requests.keys.first;
    setState(() => _busy = true);
    await HapticFeedback.mediumImpact();
    try {
      final notifier = ref.read(permissionsNotifierProvider.notifier);
      if (allow) {
        await notifier.allow(widget.sessionId, requestId);
      } else {
        await notifier.deny(widget.sessionId, requestId);
      }
    } catch (_) {
      if (mounted) context.showSnack(context.l10n.permissionActionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final first = widget.requests.entries.first;
    final count = widget.requests.length;
    final label = count > 1
        ? '${first.value.tool} · +${count - 1}'
        : first.value.tool;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, size: AppIconSize.sm, color: cs.error),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.secondary(theme, cs.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_busy)
          const SizedBox(
            width: AppIconSize.md,
            height: AppIconSize.md,
            child: AppCircularProgressIndicator(strokeWidth: 2),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(
                onPressed: widget.isOnline ? () => _act(false) : null,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                ).merge(AppButtonStyle.compact),
                child: Text(l10n.permissionDeny),
              ),
              FilledButton(
                onPressed: widget.isOnline ? () => _act(true) : null,
                style: AppButtonStyle.destructiveFilled(
                  cs,
                ).merge(AppButtonStyle.compact),
                child: Text(l10n.permissionAllow),
              ),
            ],
          ),
      ],
    );
  }
}

/// Quiet borderless row used in the "All Sessions" section of the
/// Unread Focus view. Rendered inside [UnreadFocusListGroup] to get
/// hairline dividers between rows and a single rounded surface.
class UnreadFocusListRow extends StatelessWidget {
  const UnreadFocusListRow({
    required this.session,
    required this.showFlavorIcon,
    required this.onTap,
    required this.onLongPress,
    super.key,
    this.avatarStyle,
    this.lastMessageTimestamp,
    this.lastMessagePreview,
    this.lastMessageRole,
    this.selectionMode = false,
    this.isSelected = false,
    this.archiveCountdownLabel,
    this.unreadCount = 0,
  });

  final Session session;
  final bool showFlavorIcon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;
  final String? lastMessageRole;
  final bool selectionMode;
  final bool isSelected;
  final String? archiveCountdownLabel;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final derived = SessionDerived.from(session);
    final activity = getSessionActivity(context, session);
    // The activity line already says "<tool> needs approval"; don't
    // repeat it as "Permission required" one row below.
    final statusWidget = activityRestatesStatus(activity)
        ? null
        : buildStatusText(derived.status, theme.textTheme);
    final activityLine = buildActivityLineFor(
      context: context,
      activity: activity,
      preview: lastMessagePreview,
      previewRole: lastMessageRole,
      style: AppText.secondary(theme),
    );
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected
            ? cs.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode)
                  SelectionCheckbox(
                    isSelected: isSelected,
                    borderRadius: BorderRadius.zero,
                  )
                else
                  buildSessionAvatar(
                    sessionId: session.id,
                    avatarId: derived.avatarId,
                    sessionFlavor: session.metadata?.flavor,
                    size: AppAvatarSize.small,
                    showFlavorIcon: showFlavorIcon,
                    hasDraft: hasDraft,
                    avatarStyle: avatarStyle,
                  ),
                const SizedBox(width: AppSpacing.xsm),
                Expanded(
                  child: SessionListDetails(
                    name: derived.name,
                    timestamp:
                        lastMessageTimestamp ??
                        session.lastMessageAt ??
                        session.updatedAt,
                    sessionStatus: derived.status,
                    status: statusWidget,
                    detail: activityLine,
                    unreadCount: unreadCount,
                    todoProgress: todoProgress,
                    archiveCountdownLabel: archiveCountdownLabel,
                    isPinned: session.pinned,
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

/// Wraps a list of [UnreadFocusListRow] children in a single
/// rounded surface with hairline dividers between rows.
class UnreadFocusListGroup extends StatelessWidget {
  const UnreadFocusListGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
          width: AppBorder.hairline,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                thickness: AppBorder.hairline,
                indent: AppSpacing.sm + AppAvatarSize.small + AppSpacing.xsm,
                endIndent: AppSpacing.sm,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
          ],
        ],
      ),
    );
  }
}
