import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/tablet/embedded_pane.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/workflow_run.dart';
import '../../core/providers/app_providers.dart';
import '../../core/repositories/workflows_repository.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import '../../core/wire/wire_parsers.dart';
import '../workflows/workflow_display.dart';
import '../workflows/workflow_run_screen.dart';
import 'agent_presentation.dart';
import 'agent_steps.dart';
import 'chat_tts_gate.dart';
import 'widgets/agent_conversation_info.dart';
import 'widgets/agent_conversation_row.dart';
import 'widgets/agent_result_summary.dart';

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

    final presentation = AgentPresentation.fromMessage(_taskMsg);

    final showPrompt =
        promptRaw != null &&
        promptRaw.isNotEmpty &&
        promptRaw != descriptionRaw;

    final displayChildren = buildAgentDisplayChildren(children, isRunning);

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
        AgentConversationDebugCard(
          state: state,
          messageId: widget.messageId,
          subagentModel: presentation.model,
          parentModel: presentation.parentModel,
          presentation: presentation,
        ),
        if (showPrompt) AgentConversationPrompt(prompt: promptRaw),
        Expanded(child: messagesView),
      ],
    );

    return EmbeddedPaneShell(
      title: description,
      subtitle: presentation.isNativeCodex
          ? (presentation.overview ?? subagentType)
          : subagentType,
      body: body,
      embedded: widget.embedded,
      showProgress: isRunning,
      onClose: widget.onClose,
    );
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
          child: AgentConversationMessage(
            message: displayChildren[i],
            sessionId: widget.sessionId,
            metadata: WireParsers.asMap(_taskMsg?['metadata']),
            isSessionOnline:
                sync.sessions[widget.sessionId]?.presence == 'online',
          ),
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
          ? const AppCircularProgressIndicator()
          : Text(
              l10n.agentNoMessages,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
            Text('Background agent', style: AppText.title(theme)),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'This sub-agent ran in the background. Updated daemons '
              'stream its step-by-step tool calls here; none were '
              'recorded for this run.',
              textAlign: TextAlign.center,
              style: AppText.secondary(theme, cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
