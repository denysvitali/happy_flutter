import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/derived_view_providers.dart'
    show sessionByIdProvider;
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/services/sync_service.dart' show SyncData, sync;
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart' show getSessionName;
import '../../../core/wire/wire_parsers.dart';
import '../markdown/markdown.dart';
import '../tools/tool_status_indicator.dart';
import 'sub_session_projection.dart';
import 'sub_session_state_badge.dart';

/// Replies longer than this start collapsed behind "Show more".
const int _kLongReplyChars = 700;
const int _kLongReplyLines = 12;
const double _kCollapsedReplyHeight = 220;

/// Chat card for an Agent call that drives a separate child Happy session
/// (`subagent_type == "happy-session"`).
///
/// Shows the turn's description, its place in the thread of turns to the
/// same child, the child's live state from the session store, the prompt,
/// and the child's reply once the result arrives. Tapping opens the child
/// chat. A child missing from the store is fetched once; if it cannot be
/// found the open action is disabled.
class SubSessionSpawnCard extends ConsumerStatefulWidget {
  const SubSessionSpawnCard({
    required this.call,
    super.key,
    this.messages,
    this.position,
    this.onOpenSession,
    this.fetchSession,
  });

  /// The merged Agent tool-call row.
  final Map<String, dynamic> call;

  /// Resident parent transcript, used to number follow-up turns.
  final List<Map<String, dynamic>>? messages;

  /// Explicit thread position; derived from [messages] when null.
  final SubSessionTurnPosition? position;

  /// Opens the child chat; defaults to pushing `/chat/<childId>`.
  final void Function(String childSessionId)? onOpenSession;

  /// Loads a child missing from the store; defaults to
  /// [Sync.fetchSingleSession].
  final Future<Session?> Function(String sessionId)? fetchSession;

  @override
  ConsumerState<SubSessionSpawnCard> createState() =>
      _SubSessionSpawnCardState();
}

/// One in-flight fetch per child id, shared by every card of the thread.
final Map<String, Future<Session?>> _childFetches = {};

class _SubSessionSpawnCardState extends ConsumerState<SubSessionSpawnCard> {
  bool _promptExpanded = false;
  bool _replyExpanded = false;
  SubSessionLookup _lookup = SubSessionLookup.idle;

  String? get _childId => happySubSessionChildId(widget.call);

  @override
  void initState() {
    super.initState();
    final childId = _childId;
    if (childId == null) {
      _lookup = SubSessionLookup.unavailable;
    } else if (ref.read(sessionByIdProvider(childId)) == null) {
      _fetchChild(childId);
    }
  }

  void _fetchChild(String childId) {
    _lookup = SubSessionLookup.loading;
    final fetch = widget.fetchSession ?? sync.fetchSingleSession;
    final future = _childFetches[childId] ??= fetch(childId).whenComplete(() {
      // Block body: returning the removed future would await itself.
      _childFetches.remove(childId);
    });
    unawaited(
      future.then<void>(
        (session) {
          if (!mounted) return;
          setState(() {
            _lookup = session == null
                ? SubSessionLookup.unavailable
                : SubSessionLookup.idle;
          });
        },
        onError: (Object error) {
          logger.warning('[sub-session] child fetch failed: $error');
          if (mounted) {
            setState(() => _lookup = SubSessionLookup.unavailable);
          }
        },
      ),
    );
  }

  void _open(String childId) {
    final open = widget.onOpenSession;
    if (open != null) {
      open(childId);
    } else {
      context.push('/chat/$childId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final childId = _childId;
    final child = childId == null
        ? null
        : ref.watch(sessionByIdProvider(childId));
    final childState = subSessionChildState(child);
    final lookup = child != null ? SubSessionLookup.idle : _lookup;
    final status = subSessionTurnStatus(widget.call);
    final position =
        widget.position ??
        (widget.messages == null
            ? null
            : SubSessionThreads.fromMessages(
                widget.messages!,
              ).positionOf(widget.call));

    final input = WireParsers.asMap(widget.call['input']);
    final description = _text(input?['description']);
    final prompt = _text(input?['prompt']);
    final reply = subSessionReply(widget.call);
    final title = child == null ? null : getSessionName(child);
    final repository = subSessionRepositoryLabel(child);
    final canOpen = childId != null && child != null;

    final tone = switch (status) {
      SubSessionTurnStatus.failed => AppBadgeTone.danger,
      SubSessionTurnStatus.unknown => AppBadgeTone.warning,
      SubSessionTurnStatus.completed => AppBadgeTone.success,
      SubSessionTurnStatus.running => AppBadgeTone.info,
    };
    final toneColors = AppToneColors.of(context, tone);
    final isFollowUp = position?.isFollowUp ?? false;
    final label = isFollowUp
        ? '${l10n.subSessionLabel} · '
              '${l10n.subSessionFollowUp(position!.number)}'
        : l10n.subSessionLabel;

    final card = Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.smd),
        side: BorderSide(color: toneColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canOpen ? () => _open(childId) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.badge(theme, cs.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SubSessionStateBadge(state: childState, lookup: lookup),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description ?? title ?? l10n.subSessionLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (title != null || repository != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    [?title, ?repository].join(' · '),
                    style: AppText.secondary(theme, cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (prompt != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _PromptSection(
                  prompt: prompt,
                  expanded: _promptExpanded,
                  onToggle: () =>
                      setState(() => _promptExpanded = !_promptExpanded),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              _OutcomeSection(
                status: status,
                reply: reply,
                expanded: _replyExpanded,
                onToggle: () =>
                    setState(() => _replyExpanded = !_replyExpanded),
              ),
              _Footer(
                position: position,
                canOpen: canOpen,
                unavailable: lookup == SubSessionLookup.unavailable,
                onOpen: canOpen ? () => _open(childId) : null,
              ),
            ],
          ),
        ),
      ),
    );

    if (!isFollowUp) return card;
    // Follow-ups hang off the thread instead of reading as new spawns.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 18,
            color: cs.outline,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(child: card),
      ],
    );
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection({
    required this.prompt,
    required this.expanded,
    required this.onToggle,
  });

  final String prompt;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionToggle(
          label: context.l10n.subSessionPrompt,
          expanded: expanded,
          onTap: onToggle,
        ),
        if (expanded)
          SelectableText(prompt, style: style)
        else
          Text(
            prompt,
            style: style,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _OutcomeSection extends StatelessWidget {
  const _OutcomeSection({
    required this.status,
    required this.reply,
    required this.expanded,
    required this.onToggle,
  });

  final SubSessionTurnStatus status;
  final String? reply;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final replyText = reply;
    final notice = switch (status) {
      SubSessionTurnStatus.running => _Notice(
        leading: const ToolStatusIndicator(state: ToolState.running, size: 14),
        text: l10n.subSessionWaiting,
        color: cs.onSurfaceVariant,
      ),
      SubSessionTurnStatus.failed => _Notice(
        leading: Icon(Icons.error_outline, size: 16, color: cs.error),
        text: l10n.subSessionFailed,
        color: cs.error,
      ),
      SubSessionTurnStatus.unknown => _Notice(
        leading: Icon(
          Icons.help_outline_rounded,
          size: 16,
          color: AppToneColors.of(context, AppBadgeTone.warning).iconColor,
        ),
        text: l10n.subSessionUnknown,
        color: AppToneColors.of(context, AppBadgeTone.warning).foreground,
      ),
      SubSessionTurnStatus.completed when replyText == null => _Notice(
        leading: Icon(
          Icons.check_circle_outline,
          size: 16,
          color: cs.onSurfaceVariant,
        ),
        text: l10n.subSessionNoReply,
        color: cs.onSurfaceVariant,
      ),
      SubSessionTurnStatus.completed => null,
    };
    if (replyText == null || status == SubSessionTurnStatus.running) {
      return notice ?? const SizedBox.shrink();
    }
    final isLong =
        replyText.length > _kLongReplyChars ||
        '\n'.allMatches(replyText).length > _kLongReplyLines;
    final body = SimpleMarkdownView(markdown: replyText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?notice,
        if (notice != null) const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.subSessionReply,
          style: AppText.label(theme, cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xxs),
        if (!isLong || expanded)
          body
        else
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: _kCollapsedReplyHeight,
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: body,
            ),
          ),
        if (isLong)
          _SectionToggle(
            label: expanded ? l10n.toolOutputShowLess : l10n.toolOutputShowMore,
            expanded: expanded,
            onTap: onToggle,
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.leading,
    required this.text,
    required this.color,
  });

  final Widget leading;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SizedBox(width: 16, height: 16, child: Center(child: leading)),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(text, style: AppText.secondary(Theme.of(context), color)),
        ),
      ],
    );
  }
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.label(theme, cs.onSurfaceVariant)),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.position,
    required this.canOpen,
    required this.unavailable,
    required this.onOpen,
  });

  final SubSessionTurnPosition? position;
  final bool canOpen;
  final bool unavailable;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final turnCount = position?.count ?? 1;
    return Row(
      children: [
        Expanded(
          child: Text(
            unavailable
                ? l10n.subSessionUnavailableHint
                : (turnCount > 1 && !(position?.isFollowUp ?? false))
                ? l10n.subSessionTurnCount(turnCount)
                : '',
            style: AppText.secondary(theme, cs.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(l10n.subSessionOpen),
        ),
      ],
    );
  }
}

String? _text(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
