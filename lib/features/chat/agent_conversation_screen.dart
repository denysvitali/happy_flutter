import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/wire_parsers.dart';
import 'markdown/markdown.dart';
import 'tools/tool_status_indicator.dart';
import 'tools/tool_view.dart';
import 'widgets/agent_event_widget.dart';

/// Full-screen view for a Task (sub-agent) tool call's
/// conversation.
///
/// Shows the sidechain messages (children) of the Task as
/// a scrollable chat-like feed. Updates live as new
/// sidechain messages stream in. Supports nested Task
/// navigation for sub-agents within sub-agents.
class AgentConversationScreen extends ConsumerStatefulWidget {
  /// Creates an [AgentConversationScreen].
  const AgentConversationScreen({
    required this.sessionId,
    required this.messageId,
    super.key,
    this.taskData,
  });

  /// The ID of the session this Task belongs to.
  final String sessionId;

  /// The ID of the Task tool-call message.
  final String messageId;

  /// Pre-loaded task message data passed via route extra.
  final Map<String, dynamic>? taskData;

  @override
  ConsumerState<AgentConversationScreen> createState() =>
      _AgentConversationScreenState();
}

class _AgentConversationScreenState
    extends ConsumerState<AgentConversationScreen> {
  final ScrollController _scroll = ScrollController();
  StreamSubscription<String>? _messageSubscription;
  Map<String, dynamic>? _taskMsg;
  int _prevChildCount = 0;
  int _prevChildFingerprint = 0;

  @override
  void initState() {
    super.initState();
    _taskMsg = widget.taskData;
    _messageSubscription = sync.onSessionMessagesChanged
        .where((id) => id == widget.sessionId)
        .listen((_) => _refresh());
    final settings = ref.read(settingsNotifierProvider);
    unawaited(
      TtsService().init(
        language: settings.voiceAssistantLanguage,
        engine: settings.ttsEngine,
      ),
    );
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final messages = sync.sessionMessages[widget.sessionId] ?? [];
    for (final msg in messages) {
      if (msg['id'] == widget.messageId) {
        final children = WireParsers.asList(msg['children']);
        final count = children?.length ?? 0;
        final fingerprint = _computeChildrenFingerprint(children);
        final childrenChanged = fingerprint != _prevChildFingerprint;
        // Always update _taskMsg when found, even if fingerprint unchanged.
        // This fixes infinite spinner when both old and new fingerprint are 0
        // (empty children) — we still need to pick up state changes from sync.
        if (childrenChanged && count > _prevChildCount) {
          _speakNewMessages(children);
        }
        setState(() {
          _taskMsg = Map<String, dynamic>.from(msg);
          _prevChildCount = count;
          _prevChildFingerprint = fingerprint;
        });
        if (childrenChanged) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_scroll.hasClients) {
              _scroll.animateTo(
                _scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
        return;
      }
    }
  }

  int _computeChildrenFingerprint(List<dynamic>? children) {
    if (children == null || children.isEmpty) return 0;
    var hash = children.length;
    for (final item in children) {
      if (item is! Map<String, dynamic>) continue;
      final content = item['content'];
      final nestedChildren = item['children'];
      final nestedCount = nestedChildren is List ? nestedChildren.length : 0;
      final contentHash = switch (content) {
        final String text => Object.hash(text.length, text.hashCode),
        final List<dynamic> list => list.length,
        final Map<dynamic, dynamic> map => map.length,
        _ => content?.hashCode ?? 0,
      };
      hash = Object.hash(
        hash,
        item['id'],
        item['kind'],
        item['state'],
        item['isThinking'],
        item['result'],
        contentHash,
        nestedCount,
      );
    }
    return hash;
  }

  void _speakNewMessages(List<dynamic>? children) {
    final settings = ref.read(settingsNotifierProvider);
    if (!settings.ttsEnabled || children == null || children.isEmpty) {
      return;
    }
    final latestChild = children.last;
    if (latestChild is Map<String, dynamic>) {
      final kind = latestChild['kind'] as String?;
      final content = latestChild['content'] as String? ?? '';
      final isThinking = latestChild['isThinking'] == true;
      if (kind == 'text' && content.isNotEmpty && !isThinking) {
        unawaited(TtsService().speak(content));
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _scroll.dispose();
    TtsService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final input = WireParsers.asMap(_taskMsg?['input']);
    final description =
        input?['description'] as String? ??
        input?['prompt'] as String? ??
        l10n.agentFallbackDescription;
    final subagentType = input?['subagent_type'] as String?;
    final state = _taskMsg?['state'] as String? ?? 'pending';
    final isRunning = state == 'running';
    final children =
        WireParsers.asList(_taskMsg?['children'])
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              description,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            if (subagentType != null)
              Text(
                subagentType,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (isRunning)
            Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.lg,
              ),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: children.isEmpty
          ? Center(
              child: isRunning
                  ? const CircularProgressIndicator()
                  : Text(
                      l10n.agentNoMessages,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            )
          : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              itemCount: children.length,
              itemBuilder: (context, i) => _buildChildMessage(
                theme,
                children[i],
                key: ValueKey(children[i]['id'] ?? i),
              ),
            ),
    );
  }

  Widget _buildChildMessage(
    ThemeData theme,
    Map<String, dynamic> msg, {
    required Key? key,
  }) {
    final kind = msg['kind'] as String?;

    if (kind == 'text') {
      return _buildTextMessage(theme, msg, key: key);
    }

    if (kind == 'tool-call') {
      final toolName = msg['name'] as String? ?? '';
      if (toolName == 'Task' || toolName == 'Agent') {
        return _buildNestedTaskRow(theme, msg, key: key);
      }
      return _buildToolRow(theme, msg, key: key);
    }

    if (kind == 'error') {
      return _ErrorRow(key: key, theme: theme, msg: msg);
    }

    if (kind == 'agent-event') {
      return AgentEventWidget(
        key: key,
        event: msg['event'],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTextMessage(
    ThemeData theme,
    Map<String, dynamic> msg, {
    Key? key,
  }) {
    final content = msg['content'] as String? ?? '';
    if (content.isEmpty) return const SizedBox.shrink();
    final isThinking = msg['isThinking'] == true;

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: isThinking
          ? const _ThinkingRow()
          : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: SimpleMarkdownView(markdown: content),
            ),
    );
  }

  Widget _buildToolRow(ThemeData theme, Map<String, dynamic> msg, {Key? key}) {
    // Use full ToolView for detailed tool call display
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ToolView(
        tool: msg,
        metadata: WireParsers.asMap(_taskMsg?['metadata']),
        sessionId: widget.sessionId,
        isSessionOnline: sync.sessions[widget.sessionId]?.presence == 'online',
        onPress: () {
          final msgId = msg['id'] as String?;
          if (msgId == null) return;
          context.push(
            '/chat/${widget.sessionId}/message/$msgId',
            extra: msg,
          );
        },
      ),
    );
  }

  Widget _buildNestedTaskRow(
    ThemeData theme,
    Map<String, dynamic> msg, {
    Key? key,
  }) {
    final input = WireParsers.asMap(msg['input']);
    final description =
        input?['description'] as String? ??
        input?['prompt'] as String? ??
        AppLocalizations.of(context).agentFallbackTask;
    final subagentType = input?['subagent_type'] as String?;
    final state = msg['state'] as String? ?? 'pending';
    final toolState = _parseToolState(state);
    final children = WireParsers.asList(msg['children']);
    final childCount = children?.length ?? 0;
    final msgId = msg['id'] as String?;

    final Color borderColor;
    switch (toolState) {
      case ToolState.running:
        borderColor = theme.colorScheme.primary.withAlpha(80);
      case ToolState.completed:
        borderColor = AppColors.success.withAlpha(80);
      case ToolState.error:
        borderColor = theme.colorScheme.error.withAlpha(80);
      case ToolState.pending:
        borderColor = theme.colorScheme.outlineVariant;
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs),
      child: InkWell(
        onTap: () {
          if (msgId == null) return;
          context.push(
            '/chat/${widget.sessionId}'
            '/agent/$msgId',
            extra: msg,
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.smd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.smd),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: ToolStatusIndicator(state: toolState, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.rocket_launch,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subagentType != null)
                      Text(
                        subagentType,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: AppOpacity.high,
                          ),
                          fontSize: AppFontSize.xxs,
                        ),
                      ),
                  ],
                ),
              ),
              if (childCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    '$childCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: AppOpacity.half,
                      ),
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: AppOpacity.half,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ToolState _parseToolState(String state) => parseToolState(state);
}

// ----------------------------------------------------------
// Thinking row
// ----------------------------------------------------------

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant
                .withValues(alpha: AppOpacity.high),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            AppLocalizations.of(context).chatThinking,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: AppOpacity.high),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------
// Error row (compact inline error indicator)
// ----------------------------------------------------------

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.theme, required this.msg, super.key});

  final ThemeData theme;
  final Map<String, dynamic> msg;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final errorType = msg['errorType'] as String? ?? 'unknown';
    final errorMessage = msg['errorMessage'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: InkWell(
        onTap: () => _showErrorSheet(context),
        borderRadius: BorderRadius.circular(AppRadius.xsm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd,
            vertical: AppSpacing.xsm,
          ),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(
              alpha: AppOpacity.half,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xsm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 14, color: cs.error),
              const SizedBox(width: AppSpacing.xsm),
              Flexible(
                child: Text(
                  '$errorType: $errorMessage',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                    fontSize: AppFontSize.sm,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSheet(BuildContext context) {
    final debugData = WireParsers.asMap(msg['debugData']);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(msg['errorType'] as String? ?? 'Error'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg['errorMessage'] as String? ?? 'Unknown error'),
              if (debugData != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Debug data:',
                  style: Theme.of(ctx).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  debugData.toString(),
                  style: Theme.of(ctx).textTheme.bodySmall
                      ?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.sm,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx).commonClose),
          ),
        ],
      ),
    );
  }
}
