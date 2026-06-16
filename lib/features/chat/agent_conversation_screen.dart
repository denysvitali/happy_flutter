import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/wire_parsers.dart';
import 'chat_tts_gate.dart';
import 'markdown/markdown.dart';
import 'markdown/markdown_view.dart';
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
    this.embedded = false,
    this.onClose,
  });

  /// The ID of the session this Task belongs to.
  final String sessionId;

  /// The ID of the Task tool-call message.
  final String messageId;

  /// Pre-loaded task message data passed via route extra.
  final Map<String, dynamic>? taskData;

  /// When true, render as a pane inside a tablet master-detail layout.
  /// Skips the outer [Scaffold]/[AppBar] and uses a thin in-pane header.
  final bool embedded;

  /// Called when the in-pane close button is tapped (embedded only).
  final VoidCallback? onClose;

  @override
  ConsumerState<AgentConversationScreen> createState() =>
      _AgentConversationScreenState();
}

class _AgentConversationScreenState
    extends ConsumerState<AgentConversationScreen> {
  final ScrollController _scroll = ScrollController();
  StreamSubscription<String>? _messageSubscription;
  Map<String, dynamic>? _taskMsg;
  int _prevChildFingerprint = 0;
  // Sub-agent children carry no `role` field (they're sidechain
  // messages), so the predicate matches the original agent-screen
  // behavior: any text item that isn't a thinking placeholder.
  final ChatTtsGate _ttsGate = ChatTtsGate(
    isSpeakable: (m) =>
        (m['kind'] as String?) == 'text' && m['isThinking'] != true,
  );

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
    final found = _findMessageById(messages, widget.messageId);
    if (found == null) {
      final taskDataChildren =
          WireParsers.asList(widget.taskData?['children'])?.length ?? 0;
      logger.debug(
        '[AgentConversation] _refresh: NOT FOUND in ${messages.length} msgs '
        'id=${widget.messageId} '
        'taskDataChildren=$taskDataChildren '
        'topLevelIds=${messages.take(5).map((m) => m['id']).toList()}',
      );
      return;
    }
    _applyUpdate(found);
  }

  /// Recursively search messages and their children for [messageId].
  Map<String, dynamic>? _findMessageById(
    List<Map<String, dynamic>> messages,
    String messageId,
  ) => _findMessageByIdVisited(messages, messageId, <Map<String, dynamic>>{});

  Map<String, dynamic>? _findMessageByIdVisited(
    List<Map<String, dynamic>> messages,
    String messageId,
    Set<Map<String, dynamic>> visited,
  ) {
    for (final msg in messages) {
      if (!visited.add(msg)) continue;
      if (msg['id'] == messageId) return msg;
      final children = WireParsers.asList(msg['children']);
      if (children == null || children.isEmpty) continue;
      final nested = _findMessageByIdVisited(
        children.whereType<Map<String, dynamic>>().toList(),
        messageId,
        visited,
      );
      if (nested != null) return nested;
    }
    return null;
  }

  void _applyUpdate(Map<String, dynamic> msg) {
    final children = WireParsers.asList(msg['children']);
    final count = children?.length ?? 0;
    // Never downgrade: keep the richer children set.
    final currentChildren = WireParsers.asList(_taskMsg?['children']);
    final currentCount = currentChildren?.length ?? 0;
    final merged = Map<String, dynamic>.from(msg);
    if (count < currentCount && currentChildren != null) {
      merged['children'] = List<dynamic>.from(currentChildren);
    }
    final mergedChildKinds = WireParsers.asList(
      merged['children'],
    )?.whereType<Map<String, dynamic>>().map((c) => c['kind']).toList();
    logger.debug(
      '[AgentConversation] _applyUpdate '
      'id=${widget.messageId} '
      'sync=$count prev=$currentCount '
      'merged=${WireParsers.asList(merged['children'])?.length ?? 0} '
      'kinds=$mergedChildKinds',
    );
    final mergedChildren = WireParsers.asList(merged['children']);
    final fingerprint = _computeChildrenFingerprint(mergedChildren);
    final childrenChanged = fingerprint != _prevChildFingerprint;
    if (!_ttsGate.isInitialLoadComplete) {
      // Seed the baseline from the first batch of children we see so
      // the existing tail isn't replayed when entering the screen.
      _ttsGate.markInitialLoadCompleteDynamic(mergedChildren);
    } else if (childrenChanged) {
      _speakNewMessages(mergedChildren);
    }
    setState(() {
      _taskMsg = merged;
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
    final speech = _ttsGate.evaluateDynamic(
      items: children,
      ttsEnabled: settings.ttsEnabled,
    );
    if (speech != null) {
      unawaited(
        TtsService().enqueueSpeak(
          speech,
          useOffline: settings.ttsUseOffline,
          offlineVoiceId: settings.ttsVoiceId,
        ),
      );
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
    final descriptionRaw = input?['description'] as String?;
    final promptRaw = input?['prompt'] as String?;
    final description =
        descriptionRaw ?? promptRaw ?? l10n.agentFallbackDescription;
    final subagentType = input?['subagent_type'] as String?;
    final state = _taskMsg?['state'] as String? ?? 'pending';
    final isRunning = state == 'running';
    final children =
        WireParsers.asList(
          _taskMsg?['children'],
        )?.whereType<Map<String, dynamic>>().toList() ??
        [];

    final showPrompt =
        promptRaw != null &&
        promptRaw.isNotEmpty &&
        promptRaw != descriptionRaw;

    final messagesView = children.isEmpty
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
            itemBuilder: (context, i) => RepaintBoundary(
              key: ValueKey(children[i]['id'] ?? i),
              child: _buildChildMessage(theme, children[i]),
            ),
          );

    final body = showPrompt
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PromptSection(prompt: promptRaw),
              Expanded(child: messagesView),
            ],
          )
        : messagesView;

    if (!widget.embedded) {
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
                padding: const EdgeInsets.only(right: AppSpacing.lg),
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
        body: body,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AgentEmbeddedHeader(
          description: description,
          subagentType: subagentType,
          isRunning: isRunning,
          onClose: widget.onClose,
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildChildMessage(ThemeData theme, Map<String, dynamic> msg) {
    final kind = msg['kind'] as String?;

    if (kind == 'text') {
      return _buildTextMessage(theme, msg);
    }

    if (kind == 'tool-call') {
      final toolName = msg['name'] as String? ?? '';
      if (toolName == 'Task' || toolName == 'Agent' || toolName == 'Workflow') {
        return _buildNestedTaskRow(theme, msg);
      }
      return _buildToolRow(theme, msg);
    }

    if (kind == 'error') {
      return _ErrorRow(theme: theme, msg: msg);
    }

    if (kind == 'agent-event') {
      return AgentEventWidget(event: msg['event']);
    }

    return const SizedBox.shrink();
  }

  Widget _buildTextMessage(ThemeData theme, Map<String, dynamic> msg) {
    final content = msg['content'] as String? ?? '';
    if (content.isEmpty) return const SizedBox.shrink();
    final isThinking = msg['isThinking'] == true;

    return Padding(
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

  Widget _buildToolRow(ThemeData theme, Map<String, dynamic> msg) {
    // Use full ToolView for detailed tool call display
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ToolView(
        tool: msg,
        metadata: WireParsers.asMap(_taskMsg?['metadata']),
        sessionId: widget.sessionId,
        isSessionOnline: sync.sessions[widget.sessionId]?.presence == 'online',
        onPress: () {
          final msgId = msg['id'] as String?;
          if (msgId == null) return;
          context.push('/chat/${widget.sessionId}/message/$msgId', extra: msg);
        },
      ),
    );
  }

  Widget _buildNestedTaskRow(ThemeData theme, Map<String, dynamic> msg) {
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
// Embedded header
// ----------------------------------------------------------

class _AgentEmbeddedHeader extends StatelessWidget {
  const _AgentEmbeddedHeader({
    required this.description,
    required this.isRunning,
    this.subagentType,
    this.onClose,
  });

  final String description;
  final String? subagentType;
  final bool isRunning;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: AppBorder.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  description,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subagentType != null)
                  Text(
                    subagentType!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (isRunning)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              // TODO(i18n): close tooltip not yet localized
              tooltip: 'Close',
              onPressed: onClose,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
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
            color: theme.colorScheme.onSurfaceVariant.withValues(
              alpha: AppOpacity.high,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            AppLocalizations.of(context).chatThinking,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(
                alpha: AppOpacity.high,
              ),
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
            color: cs.errorContainer.withValues(alpha: AppOpacity.half),
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
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  debugData.toString(),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
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

// ----------------------------------------------------------
// Prompt section (collapsible — shown above the agent feed)
// ----------------------------------------------------------

class _PromptSection extends StatefulWidget {
  const _PromptSection({required this.prompt});

  final String prompt;

  @override
  State<_PromptSection> createState() => _PromptSectionState();
}

class _PromptSectionState extends State<_PromptSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.smd),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.smd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Prompt',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDuration.normal,
            curve: AppCurve.standard,
            child: _expanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: MarkdownView(
                        markdown: widget.prompt,
                        textColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
