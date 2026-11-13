import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/inbox_message.dart';
import '../../../core/providers/chat_action_notifier.dart';
import '../../../core/services/inbox_state_storage.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/snack.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import '../../../core/utils/utils.dart' show formatRelativeTime;
import '../../chat/markdown/markdown_view.dart' show SimpleMarkdownView;
import '../../sessions/widgets/session_cards.dart' show buildSessionAvatar;
import '../inbox_providers.dart';
import 'inbox_kind_style.dart';

/// Text delivered to the agent for an Inbox reply. Quoting the subject
/// tells the agent which of its messages is being answered.
String inboxReplyText(InboxMessage message, String reply) =>
    'Re: ${message.subject}\n\n${reply.trim()}';

/// A message thread: the agent's message on the left, the user's reply on
/// the right, and a composer while a reply is still possible.
class InboxThreadView extends ConsumerStatefulWidget {
  const InboxThreadView({
    required this.item,
    this.showHeaderActions = true,
    super.key,
  });

  final InboxItem item;

  /// Wide layouts show actions in the thread header; the standalone screen
  /// puts them in its app bar instead.
  final bool showHeaderActions;

  @override
  ConsumerState<InboxThreadView> createState() => _InboxThreadViewState();
}

class _InboxThreadViewState extends ConsumerState<InboxThreadView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scheduleMarkRead();
  }

  @override
  void didUpdateWidget(InboxThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.key != widget.item.key) {
      _controller.clear();
      _scheduleMarkRead();
    }
  }

  void _scheduleMarkRead() {
    final key = widget.item.key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.item.key != key) return;
      ref.read(inboxStateProvider.notifier).markRead(key);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final reply = text.trim();
    if (reply.isEmpty || _sending) return;
    final item = widget.item;
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatActionNotifierProvider.notifier)
          .sendMessage(item.sessionId, inboxReplyText(item.message, reply));
      ref.read(inboxStateProvider.notifier).recordReply(item.key, reply);
      _controller.clear();
      if (mounted) {
        context.showSnack(l10n.inboxReplySent(item.sessionName));
      }
    } catch (e, st) {
      logger.warning('[inbox] reply to ${item.sessionId} failed: $e', e, st);
      if (mounted) {
        context.showSnack(l10n.inboxReplyFailed, tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final message = item.message;
    final state = ref.watch(
      inboxStateProvider.select(
        (s) => s[item.key] ?? InboxMessageState.initial,
      ),
    );
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoint.contentMax,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ThreadHeader(
                          item: item,
                          state: state,
                          showActions: widget.showHeaderActions,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Divider(height: 1, color: cs.outlineVariant),
                        const SizedBox(height: AppSpacing.lg),
                        _AgentBubble(item: item),
                        if (state.replied && state.reply != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _UserBubble(text: state.reply!, at: state.repliedAt!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!state.replied && message.options.isNotEmpty)
          _SuggestedReplies(
            options: message.options,
            enabled: !_sending,
            onPick: _send,
          ),
        _ReplyComposer(
          controller: _controller,
          focusNode: _focusNode,
          sending: _sending,
          hint: l10n.inboxReplyHint(item.sessionName),
          onSend: () => _send(_controller.text),
        ),
      ],
    );
  }
}

class _ThreadHeader extends ConsumerWidget {
  const _ThreadHeader({
    required this.item,
    required this.state,
    required this.showActions,
  });

  final InboxItem item;
  final InboxMessageState state;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final message = item.message;
    final when = DateTime.fromMillisecondsSinceEpoch(message.createdAt);
    final absolute = MaterialLocalizations.of(context);
    final timeLabel =
        '${absolute.formatMediumDate(when)} · '
        '${absolute.formatTimeOfDay(TimeOfDay.fromDateTime(when))}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                message.subject,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (showActions) InboxMessageActions(item: item, state: state),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            InboxKindPill(kind: message.kind),
            if (inboxItemNeedsReply(item, state))
              InboxPill(
                label: l10n.inboxNeedsReply,
                color: theme.colorScheme.error,
                icon: Icons.reply_rounded,
              ),
            if (item.archived)
              InboxPill(
                label: l10n.inboxArchivedSession,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            buildSessionAvatar(
              sessionId: item.sessionId,
              avatarId: item.avatarId,
              sessionFlavor: item.flavor,
              size: AppAvatarSize.large,
              showFlavorIcon: true,
              hasDraft: false,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sessionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(theme),
                  ),
                  Text(
                    '${l10n.inboxToYou} · $timeLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.secondary(theme),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => context.pushNamed(
                'chat',
                pathParameters: {'sessionId': item.sessionId},
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l10n.inboxOpenSession),
            ),
          ],
        ),
      ],
    );
  }
}

/// Done / unread actions for one message, shared by the thread header and
/// the standalone screen's app bar.
class InboxMessageActions extends ConsumerWidget {
  const InboxMessageActions({
    required this.item,
    required this.state,
    this.onDone,
    super.key,
  });

  final InboxItem item;
  final InboxMessageState state;

  /// Runs after the message was moved to Done (e.g. to close the screen).
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(inboxStateProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: state.done ? l10n.inboxMoveToInbox : l10n.inboxMarkDone,
          icon: Icon(
            state.done ? Icons.move_to_inbox_rounded : Icons.done_rounded,
          ),
          onPressed: () {
            final done = !state.done;
            notifier.setDone(item.key, done: done);
            if (done) {
              context.showSnack(
                l10n.inboxMarkedDone,
                action: SnackBarAction(
                  label: l10n.inboxUndo,
                  onPressed: () => notifier.setDone(item.key, done: false),
                ),
              );
              onDone?.call();
            }
          },
        ),
        IconButton(
          tooltip: l10n.inboxMarkUnread,
          icon: const Icon(Icons.mark_email_unread_outlined),
          onPressed: () {
            notifier.markUnread(item.key);
            onDone?.call();
          },
        ),
      ],
    );
  }
}

class _AgentBubble extends StatelessWidget {
  const _AgentBubble({required this.item});

  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kind = InboxKindStyle.of(context, item.message.kind);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(AppRadius.xs),
            topEnd: Radius.circular(AppRadius.xl),
            bottomStart: Radius.circular(AppRadius.xl),
            bottomEnd: Radius.circular(AppRadius.xl),
          ),
          border: BorderDirectional(
            start: BorderSide(color: kind.color, width: AppSpacing.xxs),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: item.message.body.trim().isEmpty
            ? Text(item.message.subject, style: theme.textTheme.bodyLarge)
            : SimpleMarkdownView(markdown: item.message.body),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, required this.at});

  final String text;
  final int at;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final time = formatRelativeTime(
      DateTime.fromMillisecondsSinceEpoch(at),
      l10n: l10n,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(AppRadius.xl),
                topEnd: Radius.circular(AppRadius.xs),
                bottomStart: Radius.circular(AppRadius.xl),
                bottomEnd: Radius.circular(AppRadius.xl),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('${l10n.inboxYou} · $time', style: AppText.secondary(theme)),
      ],
    );
  }
}

class _SuggestedReplies extends StatelessWidget {
  const _SuggestedReplies({
    required this.options,
    required this.enabled,
    required this.onPick,
  });

  final List<String> options;
  final bool enabled;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.inboxSuggestedReplies, style: AppText.label(theme)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in options)
                ActionChip(
                  label: Text(option),
                  onPressed: enabled ? () => onPick(option) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !sending,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => IconButton.filled(
                tooltip: context.l10n.inboxSend,
                onPressed: sending || value.text.trim().isEmpty ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                        dimension: AppIconSize.md,
                        child: AppCircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
