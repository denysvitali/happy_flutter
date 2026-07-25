import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/tablet/embedded_pane.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/workflow_run.dart';
import '../../core/providers/app_providers.dart';
import '../../core/repositories/workflows_repository.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/wire/wire_parsers.dart';
import '../workflows/workflow_display.dart';
import '../workflows/workflow_run_screen.dart';
import 'chat_tts_gate.dart';
import 'markdown/markdown.dart';
import 'markdown/markdown_view.dart';
import 'tools/tool_status_indicator.dart';
import 'tools/tool_view.dart';
import 'widgets/agent_event_widget.dart';
import 'widgets/agent_result_summary.dart';
import 'widgets/task_event_summary_card.dart';

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
  StreamSubscription<String>? _workflowSubscription;
  Map<String, dynamic>? _taskMsg;
  int _prevChildFingerprint = 0;
  // A Workflow tool call's inner transcript never reaches the session
  // message stream (the daemon keeps it in wf_<runId>.json), so the grouped
  // `children` only ever carry transient task_* events. When we detect a
  // workflow we resolve its run from the sync cache (and fetch once on miss)
  // and embed [WorkflowRunScreen] so the per-agent breakdown is visible.
  String? _runId;
  bool _runFetchAttempted = false;
  // Sub-agent children carry no `role` field (they're sidechain
  // messages), so the predicate matches the original agent-screen
  // behavior: any text item that isn't a thinking placeholder. Task
  // completion notifications also arrive as `kind: 'text'` but are meta
  // events, not sub-agent prose — speaking them reads the step label aloud
  // a second time right after the progress chip already announced it.
  final ChatTtsGate _ttsGate = ChatTtsGate(
    isSpeakable: (m) =>
        (m['kind'] as String?) == 'text' &&
        m['isThinking'] != true &&
        m['taskEvent'] != true,
  );

  @override
  void initState() {
    super.initState();
    _taskMsg = widget.taskData;
    _runId = _resolveRunId(_taskMsg);
    _messageSubscription = sync.onSessionMessagesChanged
        .where((id) => id == widget.sessionId)
        .listen((_) => _refresh());
    _workflowSubscription = sync.onWorkflowsChanged
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
      _loadRun();
      return;
    }
    // The grouped message may gain its `workflowRunId` only once the first
    // task_* sidechain event nests under it, so re-resolve on every refresh.
    final resolvedRunId = _resolveRunId(found) ?? _runId;
    if (resolvedRunId != _runId) {
      setState(() => _runId = resolvedRunId);
      _runFetchAttempted = false;
    }
    _applyUpdate(found);
    _loadRun();
  }

  String? _resolveRunId(Map<String, dynamic>? msg) {
    if (msg == null) return null;
    if (msg['name'] != 'Workflow') return null;
    final tag = WorkflowRun.runTagForMessage(msg);
    if (tag != null) return tag;
    // The grouped `workflowRunId` tag only appears once a task_* sidechain
    // event nests under the tool call, which need not have happened (or the
    // events never group at all). The tool *result* always echoes the run id
    // ("Run ID: wf_…"), so fall back to parsing it — without this the embed
    // never fires and the user sees the raw launch receipt instead of the
    // per-agent breakdown.
    return _runIdFromResult(msg['result']);
  }

  /// Matches the daemon run id echoed in a Workflow tool result, e.g.
  /// `Run ID: wf_6551c046-249`. Scoped to the `Run ID:` label so unrelated
  /// `wf_` substrings (paths, script names) don't yield a false id.
  static final RegExp _runIdInResult = RegExp(r'Run ID:\s*([A-Za-z0-9_-]+)');

  static String? _runIdFromResult(dynamic result) {
    final text = resultAsText(result);
    if (text == null) return null;
    return _runIdInResult.firstMatch(text)?.group(1);
  }

  /// Resolve the [WorkflowRun] for the current [_runId] from the sync cache,
  /// falling back to a single daemon snapshot fetch on miss. The embedded
  /// [WorkflowRunScreen] renders whatever the cache holds; this just makes
  /// sure a not-yet-cached run gets pulled once.
  void _loadRun() {
    final runId = _runId;
    if (runId == null || _runFetchAttempted) return;
    final cached = sync
        .workflowsForSession(widget.sessionId)
        .where((r) => r.runId == runId)
        .firstOrNull;
    if (cached != null) return;
    _runFetchAttempted = true;
    unawaited(
      ref
          .read(workflowsRepositoryProvider)
          .fetchSnapshot(widget.sessionId, runId)
          .then((run) {
            if (!mounted || run == null) return;
            // The fetch writes through to the sync cache, which fires
            // onWorkflowsChanged → _refresh; nothing to setState here.
          }),
    );
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
      final id = msg['id'] as String?;
      final toolUseId = msg['toolUseId'] as String?;
      final uuid = msg['uuid'] as String?;
      if (id == messageId || toolUseId == messageId || uuid == messageId) {
        return msg;
      }
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
    _workflowSubscription?.cancel();
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
    final isWorkflow = _taskMsg?['name'] == 'Workflow';
    final runId = isWorkflow ? _runId : null;
    final cachedRun = runId == null
        ? null
        : sync
              .workflowsForSession(widget.sessionId)
              .where((r) => r.runId == runId)
              .firstOrNull;
    final rawResultSummary = resultAsText(_taskMsg?['result']);
    // The async-launch receipt is internal metadata the tool result itself
    // says must never be shown to the user ("never quote or paste any part
    // of it"). It is NOT a useful outcome, so never render it as the result
    // body. When the daemon streams the background agent's transcript the
    // grouped children fill the feed above and this is moot; the guard only
    // stops the raw receipt leaking for runs whose steps never streamed.
    final isAsyncLaunchReceipt = _isAsyncLaunchReceipt(rawResultSummary);
    final resultSummary = isAsyncLaunchReceipt ? null : rawResultSummary;
    final description =
        descriptionRaw ??
        promptRaw ??
        (isWorkflow
            ? (cachedRun != null ? workflowDisplayName(cachedRun) : 'Workflow')
            : l10n.agentFallbackDescription);
    final subagentType =
        input?['subagent_type'] as String? ?? _taskMsg?['taskType'] as String?;
    final state = _taskMsg?['state'] as String? ?? 'pending';
    final isRunning = state == 'running';
    final children =
        WireParsers.asList(
          _taskMsg?['children'],
        )?.whereType<Map<String, dynamic>>().toList() ??
        [];

    final metadata = WireParsers.asMap(_taskMsg?['metadata']);
    String? childModel;
    for (final c in children) {
      final m = _nonEmptyStr(c['model']);
      if (m != null) {
        childModel = m;
        break;
      }
    }
    // The model the sub-agent was invoked with. The Agent tool input
    // only carries `model` when the parent passed one explicitly; the
    // daemon otherwise records it on the sidechain assistant messages
    // (child `model`), never on the Task message itself.
    final subagentModel =
        _nonEmptyStr(input?['model']) ??
        _nonEmptyStr(metadata?['model']) ??
        childModel;
    // The Task message's own `model` is the orchestrator that spawned
    // this sub-agent (see output_content_handler), not the sub-agent's.
    final parentModel = _nonEmptyStr(_taskMsg?['model']);

    final showPrompt =
        promptRaw != null &&
        promptRaw.isNotEmpty &&
        promptRaw != descriptionRaw;

    final displayChildren = _buildDisplayChildren(children, isRunning);

    final messagesView = _buildMessagesView(
      theme: theme,
      l10n: l10n,
      displayChildren: displayChildren,
      isRunning: isRunning,
      isWorkflow: isWorkflow,
      runId: runId,
      isAsyncLaunchReceipt: isAsyncLaunchReceipt,
      resultSummary: resultSummary,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DebugInfoCard(
          state: state,
          messageId: widget.messageId,
          subagentModel: subagentModel,
          parentModel: parentModel,
        ),
        if (showPrompt) _PromptSection(prompt: promptRaw),
        Expanded(child: messagesView),
      ],
    );

    return EmbeddedPaneShell(
      title: description,
      subtitle: subagentType,
      body: body,
      embedded: widget.embedded,
      showProgress: isRunning,
      onClose: widget.onClose,
    );
  }

  Widget _buildChildMessage(ThemeData theme, Map<String, dynamic> msg) {
    final kind = msg['kind'] as String?;

    if (kind == 'text') {
      // A task_notification / task_updated completion summary is a meta
      // event the CLI encodes as a text row. Rendering it through the plain
      // text path dresses it as sub-agent prose — an unlabelled bubble that
      // just repeats the step description. The chat timeline already routes
      // it to TaskEventSummaryCard (status glyph + transcript path); this
      // feed must too, or the same step reads three times in a row.
      if (msg['taskEvent'] == true) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: TaskEventSummaryCard(data: msg, sessionId: widget.sessionId),
        );
      }
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
      // Task progress chips in this dedicated step feed render as full
      // "<tool> · <description>" step rows — the chat timeline keeps the
      // compact centered chip (with the tool name de-duplicated) via
      // AgentEventWidget, but here the tool name is part of the step the
      // user tapped to see, so the whole label is shown verbatim.
      if (msg['taskEvent'] == true) {
        return _StepChipRow(theme: theme, msg: msg);
      }
      return AgentEventWidget(event: msg['event'], message: msg);
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
    final subagentType =
        input?['subagent_type'] as String? ?? msg['taskType'] as String?;
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

  /// Collapses the sub-agent activity feed so transient indicators don't
  /// drown the result. Transient = sub-agent progress chips, task completion
  /// notifications, and thinking placeholders: meta rows the screen shows
  /// while work happens, none of them sub-agent transcript content.
  /// While the task runs, a run of transient rows describing the same step
  /// collapses to one indicator — the newest, so the completion notification
  /// supersedes the in-flight chip it echoes instead of printing the step
  /// label twice.
  ///
  /// Once finished, thinking placeholders (no user-visible content) are
  /// always dropped. Progress chips are dropped too *when the agent left a
  /// real transcript* (durable text / tool-call / error / nested-task rows)
  /// — there the chips are noise next to the actual work. But async /
  /// background agents never stream their inner tool calls across the wire,
  /// so their sidechain carries *only* progress chips: those chips are the
  /// "N steps" the session list promises, and dropping them leaves an empty
  /// feed that falls through to the (useless) async-launch receipt. In that
  /// chips-only case we keep them, de-duplicated, so the detail shows the
  /// steps the user tapped to see.
  List<Map<String, dynamic>> _buildDisplayChildren(
    List<Map<String, dynamic>> children,
    bool isRunning,
  ) {
    final hasDurable = children.any((c) => _transientKey(c) == null);
    final out = <Map<String, dynamic>>[];
    String? prevTransientKey;
    String? prevTool;
    for (final c in children) {
      final key = _transientKey(c);
      if (key == null) {
        prevTransientKey = null;
        prevTool = null;
        out.add(c);
        continue;
      }
      if (!isRunning) {
        // Finished: thinking placeholders carry nothing to show.
        if (c['kind'] == 'text' && c['isThinking'] == true) continue;
        // A real transcript already fills the feed; meta rows beside it are
        // noise.
        if (hasDurable) continue;
        // Chips-only sidechain: these progress ticks are the steps — keep
        // them (same-step runs collapsed) instead of an empty feed.
      }
      final tool = _taskRowTool(c);
      // Tools must be compatible as well as labels: `Read · notes.md` then
      // `Write · notes.md` are two real steps that share a stripped label,
      // whereas a tool-less completion echo belongs to whatever ran last.
      final sameTool = tool == null || prevTool == null || tool == prevTool;
      if (key == prevTransientKey && sameTool) {
        // Same step reported again: keep the newest row, which carries the
        // final status (a `completed` notification replaces the chip that
        // announced the identical label while the step was in flight).
        out[out.length - 1] = c;
        prevTool = tool ?? prevTool;
        continue;
      }
      prevTransientKey = key;
      prevTool = tool;
      out.add(c);
    }
    return out;
  }

  /// Collapse key when [c] is a transient activity indicator — a sub-agent
  /// progress chip, a task completion notification, or a thinking
  /// placeholder; `null` for durable rows (real text, tool calls, errors,
  /// nested tasks).
  ///
  /// Task rows key on their *displayed* label so the progress chip and the
  /// completion notification that echoes it collapse into one row. The
  /// leading `<tool> · ` the emitter prepends to in-flight chips is stripped
  /// first, since the notification never carries it.
  String? _transientKey(Map<String, dynamic> c) {
    if (c['kind'] == 'text' && c['isThinking'] == true) {
      return 'thinking';
    }
    // Completion notifications arrive as `kind: 'text'`, in-flight ticks as
    // `kind: 'agent-event'`; both are task meta, neither is transcript.
    if (c['taskEvent'] == true) {
      return 'task:${_taskRowLabel(c)}';
    }
    return null;
  }

  /// The tool a task meta row reports, or `null` when it names none (task
  /// completion notifications never do).
  static String? _taskRowTool(Map<String, dynamic> c) {
    final tool = c['subAgentLastTool'];
    return (tool is String && tool.isNotEmpty) ? tool : null;
  }

  /// The label a task meta row renders, minus the `<tool> · ` prefix.
  static String _taskRowLabel(Map<String, dynamic> c) {
    final label = WorkflowRun.stepLabel(c);
    final tool = _taskRowTool(c);
    if (tool == null) return label;
    const sep = ' · ';
    if (label == tool) return '';
    return label.startsWith('$tool$sep')
        ? label.substring(tool.length + sep.length)
        : label;
  }

  /// Builds the scrollable feed below the debug card.
  ///
  /// A real message transcript (classic `Task`/`Agent` sidechain children)
  /// always wins. A `Workflow` tool call never has one — its inner activity
  /// lives daemon-side — so when we resolved a run id we embed
  /// [WorkflowRunScreen] (phases + per-agent prompt/result/error). Otherwise
  /// fall back to the tool result, a running spinner, or the empty note.
  Widget _buildMessagesView({
    required ThemeData theme,
    required AppLocalizations l10n,
    required List<Map<String, dynamic>> displayChildren,
    required bool isRunning,
    required bool isWorkflow,
    required String? runId,
    required bool isAsyncLaunchReceipt,
    required String? resultSummary,
  }) {
    if (displayChildren.isNotEmpty) {
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        itemCount: displayChildren.length,
        itemBuilder: (context, i) => RepaintBoundary(
          key: ValueKey(displayChildren[i]['id'] ?? i),
          child: _buildChildMessage(theme, displayChildren[i]),
        ),
      );
    }
    if (isWorkflow && runId != null) {
      return WorkflowRunScreen(
        sessionId: widget.sessionId,
        runId: runId,
        embedded: true,
      );
    }
    if (!isRunning && isAsyncLaunchReceipt) {
      return _BackgroundAgentTranscriptNote(theme: theme);
    }
    if (!isRunning && resultSummary != null) {
      return AgentResultSummary(text: resultSummary);
    }
    return Center(
      child: isRunning
          ? const CircularProgressIndicator()
          : Text(
              l10n.agentNoMessages,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
  const _ErrorRow({required this.theme, required this.msg});

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

// ----------------------------------------------------------
// Debug info card (model / state / id)
// ----------------------------------------------------------

/// Returns [v] when it is a non-empty string, else `null`.
String? _nonEmptyStr(dynamic v) => (v is String && v.isNotEmpty) ? v : null;

/// Compact, always-visible debug card shown at the top of the agent
/// conversation feed. Mirrors the label/value rows in
/// `message_detail_screen` so the model a sub-agent was invoked with is
/// no longer invisible when something goes wrong (e.g. a gateway
/// "Model not exist." 400).
class _DebugInfoCard extends StatelessWidget {
  const _DebugInfoCard({
    required this.state,
    required this.messageId,
    this.subagentModel,
    this.parentModel,
  });

  final String state;
  final String messageId;
  final String? subagentModel;
  final String? parentModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Local copy so flow analysis promotes it past the null check
    // below (a public getter would not be promoted).
    final resolvedParentModel = parentModel;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.smd),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bug_report_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                // TODO(i18n): localize these debug-card labels.
                Text(
                  'Debug',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _DebugRow(label: 'Model', value: subagentModel ?? '—', mono: true),
            if (subagentModel == null && resolvedParentModel != null)
              _DebugRow(
                label: 'Parent model',
                value: resolvedParentModel,
                mono: true,
              ),
            _DebugRow(label: 'State', value: state),
            _DebugRow(label: 'ID', value: messageId, mono: true),
          ],
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single task-progress chip rendered as a step row in the agent
/// conversation feed. Shows the chip's full label (e.g.
/// `Read · lib/main.dart`) with a status glyph so a chips-only sidechain
/// reads as the list of steps the user opened the screen to inspect.
class _StepChipRow extends StatelessWidget {
  const _StepChipRow({required this.theme, required this.msg});

  final ThemeData theme;
  final Map<String, dynamic> msg;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final label = WorkflowRun.stepLabel(msg);
    final state = WorkflowRun.stepState(msg);
    final (icon, color) = workflowStateStyle(state, cs);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// True when [text] is the async sub-agent launch receipt — internal metadata
/// the tool result explicitly says must never be surfaced to the user. Used to
/// keep that dump out of the agent conversation body.
bool _isAsyncLaunchReceipt(String? text) {
  if (text == null || text.isEmpty) return false;
  return text.contains('Async agent launched') &&
      text.contains('internal metadata');
}

/// Shown for a completed background sub-agent whose step-by-step transcript
/// never reached the session (older daemons, or a tailer that could not parse
/// the launch receipt). Honest and actionable, instead of dumping the raw
/// internal-metadata launch receipt or a misleading "no messages yet".
class _BackgroundAgentTranscriptNote extends StatelessWidget {
  const _BackgroundAgentTranscriptNote({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              size: 32,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Background agent',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'This sub-agent ran in the background. Updated daemons '
              'stream its step-by-step tool calls here; none were '
              'recorded for this run.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
