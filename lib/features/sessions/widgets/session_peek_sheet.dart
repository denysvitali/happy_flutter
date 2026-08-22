import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/message.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/message_cache_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import 'mission_control_types.dart';
import 'session_cards.dart';
import 'workspace_identity.dart';

/// Same rejection text the chat composer sends on Stop, so the agent
/// sees one consistent signal regardless of where the stop came from.
const peekAbortReason =
    "The user doesn't want to proceed with this tool "
    'use. The tool use was rejected (eg. if it was a '
    'file edit, the new_string was NOT written to the '
    'file). STOP what you are doing and wait for the '
    'user to tell you how to proceed.';

/// Glanceable preview of a session without navigating into the chat.
///
/// Triaging many streams means paying a context-switch cost per open.
/// The peek sheet flattens that cost: recent messages, one tap to jump
/// in, one tap to stop — all without leaving Mission Control.
Future<void> showSessionPeek(
  BuildContext context, {
  required Session session,
  required VoidCallback onOpen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SessionPeekSheet(
      session: session,
      onOpen: onOpen,
    ),
  );
}

class SessionPeekSheet extends ConsumerStatefulWidget {
  const SessionPeekSheet({
    required this.session,
    required this.onOpen,
    super.key,
  });

  final Session session;
  final VoidCallback onOpen;

  @override
  ConsumerState<SessionPeekSheet> createState() => _SessionPeekSheetState();
}

class _SessionPeekSheetState extends ConsumerState<SessionPeekSheet> {
  Future<List<Map<String, dynamic>>>? _messages;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _messages = MessageCacheService().getMessagesAsync(widget.session.id);
  }

  Future<void> _stop() async {
    if (_stopping) return;
    final l10n = context.l10n;
    setState(() => _stopping = true);
    try {
      await ref
          .read(chatActionNotifierProvider.notifier)
          .abortSession(widget.session.id, reason: peekAbortReason);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(l10n.missionControlPeekStopRequested),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _stopping = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(l10n.missionControlPeekStopFailed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final derived = SessionDerived.from(widget.session);
    final lane = missionLaneFor(widget.session, SessionUiEntry.empty);
    final path = widget.session.metadata?.path;
    final hasPath = path != null && path.isNotEmpty;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.smd,
              ),
              child: Row(
                children: [
                  buildSessionAvatar(
                    sessionId: widget.session.id,
                    avatarId: derived.avatarId,
                    sessionFlavor: widget.session.metadata?.flavor,
                    size: AppAvatarSize.small,
                    showFlavorIcon: false,
                    hasDraft: false,
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          derived.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasPath)
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: workspaceIdentityColor(
                                    context,
                                    sessionFolderKey(widget.session),
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Flexible(
                                child: Text(
                                  missionShortPath(path),
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
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _LaneBadge(lane: lane),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _messages,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final bubbles = extractPeekBubbles(
                    snapshot.data ?? const [],
                  );
                  if (bubbles.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        l10n.missionControlPeekNoMessages,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: bubbles.length,
                    itemBuilder: (context, index) =>
                        _PeekBubble(item: bubbles[index]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.smd,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpen();
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(l10n.missionControlPeekOpenChat),
                    ),
                  ),
                  if (widget.session.presence == 'online') ...[
                    const SizedBox(width: AppSpacing.smd),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error),
                      ),
                      onPressed: _stopping ? null : _stop,
                      icon: _stopping
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.stop_rounded),
                      label: Text(l10n.missionControlPeekStop),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extracts displayable bubbles from raw cached message maps.
///
/// Mirrors Sync's preview scan rules: skip sidechains, thinking rows and
/// agent events; render errors as error text; summarize tool calls.
@visibleForTesting
List<PeekItem> extractPeekBubbles(List<Map<String, dynamic>> messages) {
  final items = <PeekItem>[];
  for (final msg in messages) {
    if (msg['isSidechain'] == true) continue;
    final role = msg['role'] as String?;
    if (role != MessageRole.user && role != MessageRole.agent) continue;
    final kind = msg['kind'] as String?;
    if (kind == 'agent-event') continue;
    if (msg['isThinking'] == true) continue;
    if (kind == 'tool-call') {
      final summary = peekToolSummary(msg);
      if (summary != null) {
        items.add(PeekItem(role: role!, isTool: true, text: summary));
      }
      continue;
    }
    final errorText = msg['errorMessage'] as String?;
    final bodyText =
        errorText ?? ((msg['content'] ?? msg['text']) as String?);
    if (bodyText == null || bodyText.trim().isEmpty) continue;
    items.add(
      PeekItem(
        role: role!,
        isError: msg['isError'] == true || kind == 'error',
        text: cleanPeekText(bodyText.trim(), maxLen: 320),
      ),
    );
  }
  if (items.length <= peekMaxBubbles) return items;
  return items.sublist(items.length - peekMaxBubbles);
}

/// Max bubbles rendered by the peek sheet — glanceable, not a transcript.
@visibleForTesting
const peekMaxBubbles = 8;

/// One displayable row in the peek sheet.
class PeekItem {
  const PeekItem({
    required this.role,
    required this.text,
    this.isTool = false,
    this.isError = false,
  });

  /// `'user'` or `'agent'`.
  final String role;
  final String text;
  final bool isTool;
  final bool isError;
}

/// One-line "Used Bash · rg foo" summary for a tool-call message map.
String? peekToolSummary(Map<String, dynamic> message) {
  final name = message['name'] as String?;
  if (name == null || name.isEmpty) return null;
  final input = message['input'];
  String? target;
  if (input is Map) {
    for (final key in const [
      'command',
      'file_path',
      'path',
      'pattern',
      'url',
      'description',
    ]) {
      final value = input[key];
      if (value is String && value.trim().isNotEmpty) {
        target = value.trim();
        break;
      }
    }
  }
  if (target != null && target.length > 60) {
    target = '${target.substring(0, 60)}…';
  }
  return cleanPeekText(
    target == null ? 'Used $name' : 'Used $name · $target',
    maxLen: 90,
  );
}

/// Strips markdown noise and collapses [raw] to at most [maxLen] chars.
String cleanPeekText(String raw, {required int maxLen}) {
  var text = raw
      .replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), ' [code]')
      .replaceAll(RegExp(r'`[^`]+`'), ' [code]')
      .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), ' [image]');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length > maxLen) {
    text = '${text.substring(0, maxLen)}…';
  }
  return text;
}

class _LaneBadge extends StatelessWidget {
  const _LaneBadge({required this.lane});

  final MissionLane lane;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = missionLaneColor(context, lane);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.12), cs.surface),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(missionLaneIcon(lane), size: 12, color: color),
          const SizedBox(width: AppSpacing.xxxs),
          Text(
            missionLaneLabel(context, lane),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: AppFontSize.xxs,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeekBubble extends StatelessWidget {
  const _PeekBubble({required this.item});

  final PeekItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final isUser = item.role == MessageRole.user;
    final bg = item.isError
        ? Color.alphaBlend(cs.error.withValues(alpha: 0.1), cs.surface)
        : isUser
        ? Color.alphaBlend(cs.primary.withValues(alpha: 0.08), cs.surface)
        : cs.surfaceContainerHigh;
    final fg = item.isError ? cs.error : cs.onSurface;
    final roleLabel = isUser
        ? l10n.missionControlPeekYou
        : l10n.missionControlPeekAgent;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.xs,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roleLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: AppFontSize.xxs,
                fontWeight: FontWeight.w700,
                color: isUser ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxs),
            if (item.isTool)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.terminal_outlined,
                    size: AppIconSize.sm,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: Text(
                      item.text,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: AppFontSize.xs,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                item.text,
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
              ),
          ],
        ),
      ),
    );
  }
}
