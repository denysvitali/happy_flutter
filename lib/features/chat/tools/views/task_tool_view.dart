import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';
import '../known_tools.dart';
import '../tool_section_view.dart';

/// Renders TaskCreate / TaskUpdate / TaskList / TaskGet tool calls AND
/// pushes the parsed items into [todoStateNotifierProvider] so they
/// surface in the in-app task list (session banner + Zen home) — same
/// pattern as `TodoView`.
class TaskToolView extends ConsumerStatefulWidget {
  const TaskToolView({
    required this.tool,
    super.key,
    this.metadata,
    this.sessionId,
  });

  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;
  final String? sessionId;

  /// Pushes the task-tool items into the global [todoStateNotifierProvider]
  /// so they surface in the in-app task list (session banner + Zen home).
  ///
  /// Called from [ToolView.initState]/[ToolView.didUpdateWidget] rather
  /// than this widget's own lifecycle because the body is mounted inside
  /// an [AnimatedSize] that is removed from the tree when the tool is
  /// collapsed. Driving the push from the always-mounted parent keeps the
  /// global state fresh even when the user has a tool auto-collapsed.
  static void pushToolToGlobalState(
    BuildContext context,
    Map<String, dynamic> tool,
    String? sessionId,
  ) {
    final items = _resolveItemsFromTool(tool, sessionId, context);
    ProviderScope.containerOf(context, listen: false)
        .read(todoStateNotifierProvider.notifier)
        .setItemsForSession(sessionId, items);
  }

  /// Resolves the domain [TodoItem] list implied by the current tool call.
  ///
  /// Static so it can be called from [pushToolToGlobalState] (driven by
  /// [ToolView.didUpdateWidget]) regardless of whether this widget's body
  /// is currently mounted. The body lives inside an [AnimatedSize] that
  /// unmounts when the tool is collapsed, so its own lifecycle would skip
  /// pushes for tools that complete while hidden.
  static List<TodoItem> _resolveItemsFromTool(
    Map<String, dynamic> tool,
    String? session,
    BuildContext context,
  ) {
    final existing = _currentSessionItemsFor(session, context);
    final now = DateTime.now().millisecondsSinceEpoch;
    // Wall-clock of the tool event itself. Pushes can replay out of
    // chronological order (the chat ListView is reversed, so a cold load
    // mounts the newest tool first) — per-item guards below use this to
    // keep older events from clobbering newer state.
    final eventAt =
        WireParsers.parseInt(tool['completedAt']) ??
        WireParsers.parseInt(tool['createdAt']) ??
        now;
    final name = KnownTools.canonicalName((tool['name'] as String?) ?? '');
    final toolId = _toolIdFor(tool);

    // Every Happy MCP task tool echoes the full list back in its result
    // ("N items, M open" followed by one `#<id> [<status>] <subject>` per
    // row). That snapshot is authoritative for every id, status and
    // subject, so it heals rows whose create call was never mounted.
    if (name == 'TaskCreate' || name == 'TaskUpdate' || name == 'TaskGet') {
      final snapshot = _happySnapshot(tool, session, eventAt);
      if (snapshot != null) {
        final newestKnown = existing.fold<int>(
          0,
          (max, e) => e.updatedAt > max ? e.updatedAt : max,
        );
        if (eventAt < newestKnown) return existing;
        return snapshot;
      }
    }

    switch (name) {
      case 'TaskCreate':
        final input = WireParsers.asMap(tool['input']) ?? const {};
        final subject =
            input['subject'] as String? ?? input['content'] as String?;
        if (subject == null || subject.isEmpty) return existing;
        // The harness assigns the real task id in the tool *result*
        // ("Task #1 created successfully: <subject>"), not the input.
        // Prefer it so later TaskUpdate calls (which reference that id)
        // can find the item.
        final realId = (input['id'] as String?) ?? _idFromCreateResult(tool);
        final syntheticId = _deriveIdStatic(
          explicit: null,
          fallback: 'create-$subject',
          toolId: toolId,
        );
        final itemId = realId ?? syntheticId;
        // An earlier push (while the tool was still running, before the
        // result carried the harness id) stored this item under the
        // synthetic id.
        final hasSynthetic =
            realId != null && existing.any((e) => e.id == syntheticId);
        final hasReal = existing.any((e) => e.id == itemId);
        if (hasSynthetic && !hasReal) {
          // Migrate in place so the row keeps its position.
          return existing
              .map((e) => e.id == syntheticId ? e.copyWith(id: realId) : e)
              .toList();
        }
        // Both rows exist: a TaskUpdate replayed before this create already
        // inserted a placeholder under the real id. Keep that one (it holds
        // the newer status) and drop the synthetic duplicate.
        final base = hasSynthetic
            ? existing.where((e) => e.id != syntheticId).toList()
            : existing;
        // De-dupe — but fill in the subject when a reverse-order replay
        // inserted a placeholder row from a TaskUpdate processed first.
        if (hasReal) {
          return base.map((e) {
            if (e.id != itemId) return e;
            if (e.content != _placeholderContent(itemId)) return e;
            return e.copyWith(content: subject);
          }).toList();
        }
        return [
          ...base,
          TodoItem(
            id: itemId,
            content: subject,
            status: _statusFromString(input['status'] as String?),
            priority: 'medium',
            order: base.length,
            createdAt: eventAt,
            updatedAt: eventAt,
            sessionId: session,
          ),
        ];

      case 'TaskUpdate':
        final input = WireParsers.asMap(tool['input']) ?? const {};
        final explicitId = input['taskId'] as String? ?? input['id'] as String?;
        if (explicitId == null) return existing;
        final rawName = (tool['name'] as String?) ?? '';
        final rawStatus = input['status'] as String?;
        if (rawStatus == 'deleted' ||
            rawName == 'todo_remove' ||
            rawName == 'mcp__happy__todo_remove') {
          return existing.where((e) => e.id != explicitId).toList();
        }
        final newSubject =
            input['subject'] as String? ?? input['content'] as String?;
        final idx = existing.indexWhere((e) => e.id == explicitId);
        if (idx == -1) {
          // Reverse-order replay can deliver the update before its create.
          // Insert a placeholder so the status isn't lost; the create
          // merges the real subject in when it is processed.
          if (rawStatus == null) return existing;
          return [
            ...existing,
            TodoItem(
              id: explicitId,
              content: (newSubject != null && newSubject.isNotEmpty)
                  ? newSubject
                  : _placeholderContent(explicitId),
              status: _statusFromString(rawStatus),
              priority: 'medium',
              order: existing.length,
              createdAt: eventAt,
              updatedAt: eventAt,
              sessionId: session,
              completedAt: _isCompletedString(rawStatus) ? eventAt : null,
            ),
          ];
        }
        // Stale-event guard: an older replayed update must not clobber
        // state written by a newer event.
        if (eventAt < existing[idx].updatedAt) return existing;
        final updated = existing.map((e) {
          if (e.id != explicitId) return e;
          return e.copyWith(
            // A TaskUpdate may change only the subject/owner/metadata —
            // absence of `status` must not reset the item to pending.
            status: rawStatus == null ? e.status : _statusFromString(rawStatus),
            content: (newSubject != null && newSubject.isNotEmpty)
                ? newSubject
                : e.content,
            updatedAt: eventAt,
            completedAt: _isCompletedString(rawStatus)
                ? (e.completedAt ?? eventAt)
                : null,
          );
        }).toList();
        return updated;

      case 'TaskList':
        final result = tool['result'];
        // No result yet (tool still running) — don't wipe the bucket.
        if (result == null) return existing;
        final map = WireParsers.asMap(result);
        final List<TodoItem> parsed;
        if (map != null) {
          final raw =
              WireParsers.asList(map['tasks']) ??
              WireParsers.asList(map['items']) ??
              WireParsers.asList(map['todos']) ??
              const [];
          parsed = _domainFromList(raw, session, eventAt);
        } else {
          // Plain-text result: one "#<id> [<status>] <subject>" per line.
          final text = _resultText(result);
          if (text == null) return existing;
          parsed = _domainFromListText(text, session, eventAt);
        }
        // An unparseable / empty result must not clobber known tasks, and
        // neither may a snapshot older than per-item state we already hold.
        if (parsed.isEmpty) return existing;
        final newestKnown = existing.fold<int>(
          0,
          (max, e) => e.updatedAt > max ? e.updatedAt : max,
        );
        if (eventAt < newestKnown) return existing;
        return parsed;

      case 'TaskGet':
        final result = tool['result'];
        var map = WireParsers.asMap(result);
        if (map == null) {
          // Plain-text result: "Task #<id>: <subject>\nStatus: <status>\n…"
          final text = _resultText(result);
          if (text != null) map = _mapFromGetResultText(text);
        }
        if (map == null) return existing;
        final subject =
            (map['subject'] as String?) ??
            (map['title'] as String?) ??
            (map['description'] as String?) ??
            (map['content'] as String?);
        if (subject == null || subject.isEmpty) return existing;
        final itemId = _deriveIdStatic(
          explicit:
              (map['id'] as String?) ??
              (map['taskId'] as String?) ??
              (WireParsers.asMap(tool['input'])?['taskId'] as String?),
          fallback: 'get-$subject',
          toolId: toolId,
        );
        if (existing.any((e) => e.id == itemId)) {
          return existing.map((e) {
            if (e.id != itemId) return e;
            // Stale-event guard for reverse-order replays.
            if (eventAt < e.updatedAt) return e;
            return e.copyWith(
              status: _statusFromString(map!['status'] as String?),
              updatedAt: eventAt,
            );
          }).toList();
        }
        return [
          ...existing,
          TodoItem(
            id: itemId,
            content: subject,
            status: _statusFromString(map['status'] as String?),
            priority: 'medium',
            order: existing.length,
            createdAt: eventAt,
            updatedAt: eventAt,
            sessionId: session,
          ),
        ];

      default:
        return existing;
    }
  }

  /// Subject shown for an item whose TaskUpdate was processed before its
  /// TaskCreate (reverse-order replay). The create call replaces it.
  static String _placeholderContent(String id) => 'Task #$id';

  /// Extracts the harness-assigned task id from a TaskCreate result.
  ///
  /// Handles structured results (`{id: "1"}`) and both plain-text shapes:
  /// `Task #1 created successfully: <subject>` (Claude Code) and
  /// `Added #1: <subject>` (Happy MCP `todo_add`). Missing the Happy shape
  /// filed the created row under a synthetic id, so every later
  /// `todo_update` — which names the task by its real id — missed it and
  /// inserted a second, subject-less `Task #<id>` row instead.
  static String? _idFromCreateResult(Map<String, dynamic> tool) {
    final result = tool['result'];
    final map = WireParsers.asMap(result);
    if (map != null) {
      final id = (map['id'] ?? map['taskId'])?.toString();
      if (id != null && id.isNotEmpty) return id;
      return null;
    }
    final text = _resultText(result);
    if (text == null) return null;
    final m = RegExp(
      r'(?:Task\s+#([A-Za-z0-9_-]+)\s+created|^Added\s+#([A-Za-z0-9_-]+)[:\s])',
      multiLine: true,
    ).firstMatch(text);
    if (m == null) return null;
    return m.group(1) ?? m.group(2);
  }

  /// Full task list echoed back by a Happy MCP task tool, or null when the
  /// result is not one.
  ///
  /// `todo_add` / `todo_update` / `todo_remove` all print an authoritative
  /// snapshot after their headline: a `N items, M open` line followed by one
  /// `#<id> [<status>] <subject>` row per task. Consuming it keeps the list
  /// correct even when the originating create call never mounts (the chat
  /// list is reversed and lazily built, so older tool calls stay off-screen).
  static List<TodoItem>? _happySnapshot(
    Map<String, dynamic> tool,
    String? sessionId,
    int eventAt,
  ) {
    final text = _resultText(tool['result']);
    if (text == null) return null;
    final counts = RegExp(
      r'^\s*\d+\s+items?,\s+\d+\s+open\s*$',
      multiLine: true,
    );
    if (!counts.hasMatch(text)) return null;
    final items = _domainFromListText(text, sessionId, eventAt);
    return items.isEmpty ? null : items;
  }

  /// Plain-text body of a tool result, flattening the MCP content-block
  /// shape (`[{type: text, text: ...}]`) when the backend forwards it.
  static String? _resultText(dynamic result) {
    if (result is String) return result;
    if (result is List) {
      final parts = <String>[];
      for (final block in result) {
        if (block is String) {
          parts.add(block);
        } else if (block is Map) {
          final text = block['text'];
          if (text is String) parts.add(text);
        }
      }
      return parts.isEmpty ? null : parts.join('\n');
    }
    return null;
  }

  /// Parses a plain-text TaskList result into domain items.
  ///
  /// Production line shape: `#<id> [<status>] <subject>`.
  static List<TodoItem> _domainFromListText(
    String text,
    String? sessionId,
    int now,
  ) {
    final lineRe = RegExp(r'^#([A-Za-z0-9_-]+)\s+\[([^\]]+)\]\s+(.+)$');
    final out = <TodoItem>[];
    for (final line in text.split('\n')) {
      final m = lineRe.firstMatch(line.trim());
      if (m == null) continue;
      out.add(
        TodoItem(
          id: m.group(1)!,
          content: m.group(3)!,
          status: TodoState.fromString(m.group(2)!),
          priority: 'medium',
          order: out.length,
          createdAt: now,
          updatedAt: now,
          sessionId: sessionId,
        ),
      );
    }
    return out;
  }

  /// Parses a plain-text TaskGet result into the map shape the structured
  /// path consumes.
  ///
  /// Production shape: `Task #<id>: <subject>` followed by `Status: <s>`.
  static Map<String, dynamic>? _mapFromGetResultText(String text) {
    final head = RegExp(
      r'^Task\s+#([A-Za-z0-9_-]+):\s+(.+)$',
      multiLine: true,
    ).firstMatch(text);
    if (head == null) return null;
    final status = RegExp(
      r'^Status:\s+(\S+)',
      multiLine: true,
    ).firstMatch(text);
    return {
      'id': head.group(1),
      'subject': head.group(2)!.trim(),
      if (status != null) 'status': status.group(1),
    };
  }

  /// Static read of the current session's items — used by the static
  /// resolver so the notifier push works without a live `WidgetRef`.
  static List<TodoItem> _currentSessionItemsFor(
    String? sessionId,
    BuildContext context,
  ) {
    if (sessionId == null) return const [];
    final state = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(todoStateNotifierProvider);
    return state.bySession[sessionId] ?? const [];
  }

  /// Static tool-id derivation — mirrors the instance getter so that
  /// both the static resolver and the existing instance build path
  /// produce the same id for the same wire payload.
  static String _toolIdFor(Map<String, dynamic> tool) {
    final id = tool['toolUseId'] as String? ?? tool['id'] as String?;
    if (id != null && id.isNotEmpty) return id;
    return tool['name']?.toString() ?? 'task';
  }

  static String _deriveIdStatic({
    required String fallback,
    required String toolId,
    String? explicit,
  }) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return '$toolId#$fallback';
  }

  static bool _isCompletedString(String? s) {
    if (s == null) return false;
    return TodoState.fromString(s) == TodoState.completed;
  }

  static TodoState _statusFromString(String? s) =>
      TodoState.fromString(s ?? 'pending');

  static List<TodoItem> _domainFromList(
    List<dynamic> raw,
    String? sessionId,
    int now,
  ) {
    final out = <TodoItem>[];
    for (var i = 0; i < raw.length; i++) {
      final m = raw[i];
      if (m is! Map) continue;
      final subject =
          m['subject'] as String? ??
          m['title'] as String? ??
          m['content'] as String? ??
          m['description'] as String?;
      if (subject == null || subject.isEmpty) continue;
      out.add(
        TodoItem(
          id: (m['id'] as String?) ?? 'list-$subject',
          content: subject,
          status: TodoState.fromString(m['status'] as String? ?? 'pending'),
          priority: (m['priority'] as String?) ?? 'medium',
          order: i,
          createdAt: now,
          updatedAt: now,
          sessionId: sessionId,
        ),
      );
    }
    return out;
  }

  @override
  ConsumerState<TaskToolView> createState() => _TaskToolViewState();
}

class _TaskToolViewState extends ConsumerState<TaskToolView> {
  String get _name =>
      KnownTools.canonicalName((widget.tool['name'] as String?) ?? '');

  @override
  void initState() {
    super.initState();
    // Defer to post-frame so we don't mutate the provider during build.
    // [ToolView] also pushes; dedup in the resolver keeps double-pushes safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TaskToolView.pushToolToGlobalState(
        context,
        widget.tool,
        widget.sessionId,
      );
    });
  }

  @override
  void didUpdateWidget(TaskToolView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TaskToolView.pushToolToGlobalState(
        context,
        widget.tool,
        widget.sessionId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_name) {
      'TaskCreate' => _buildCreate(context),
      'TaskUpdate' => _buildUpdate(context),
      'TaskList' => _buildList(context),
      'TaskGet' => _buildGet(context),
      _ => const SizedBox.shrink(),
    };
    return ToolSectionView(child: body);
  }

  Widget _buildCreate(BuildContext context) {
    final input = WireParsers.asMap(widget.tool['input']) ?? const {};
    final subject = input['subject'] as String? ?? input['content'] as String?;
    final description = input['description'] as String?;
    final activeForm = input['activeForm'] as String?;
    final status = input['status'] as String?;

    return _TaskBody(
      icon: Icons.add_task,
      iconColor: AppColors.success,
      headline: subject,
      sublines: [
        if (description != null && description.isNotEmpty) description,
        if (activeForm != null && activeForm.isNotEmpty) activeForm,
      ],
      status: status,
    );
  }

  Widget _buildUpdate(BuildContext context) {
    final input = WireParsers.asMap(widget.tool['input']) ?? const {};
    final taskId = input['taskId'] as String? ?? input['id'] as String?;
    final status = input['status'] as String?;
    final activeForm = input['activeForm'] as String?;
    final subject = input['subject'] as String? ?? input['content'] as String?;
    // The update payload names the task by id only. Resolve the subject
    // from the task list this session already built (TaskCreate/TaskList
    // push into it) so the row says which task changed, not "Task #5".
    final known = subject ?? _knownSubjectFor(taskId);

    return _TaskBody(
      icon: Icons.edit_note,
      iconColor: Theme.of(context).colorScheme.primary,
      headline: known ?? (taskId != null ? 'Task #$taskId' : null),
      sublines: [
        if (activeForm != null && activeForm.isNotEmpty) activeForm,
        if (known != null && taskId != null) '#$taskId',
      ],
      status: status,
    );
  }

  /// Subject of [taskId] as currently known to this session's task list,
  /// or null when unknown or still a reverse-replay placeholder.
  String? _knownSubjectFor(String? taskId) {
    if (taskId == null) return null;
    final sessionId = widget.sessionId;
    if (sessionId == null) return null;
    final items = ref.watch(todoStateNotifierProvider).bySession[sessionId];
    if (items == null) return null;
    for (final item in items) {
      if (item.id != taskId) continue;
      if (item.content.isEmpty) return null;
      if (item.content == TaskToolView._placeholderContent(taskId)) return null;
      return item.content;
    }
    return null;
  }

  Widget _buildList(BuildContext context) {
    final result = WireParsers.asMap(widget.tool['result']);
    final items = _extractListItems(result);
    if (items.isEmpty) return const _EmptyHint('No tasks in list');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            '${items.length} task${items.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        for (final item in items) _ListRow(item: item),
      ],
    );
  }

  Widget _buildGet(BuildContext context) {
    final result = WireParsers.asMap(widget.tool['result']);
    if (result == null) {
      final input = WireParsers.asMap(widget.tool['input']) ?? const {};
      final id = input['taskId'] as String? ?? input['id'] as String?;
      return _EmptyHint(id != null ? 'No data for #$id' : 'No data');
    }
    final subject =
        (result['subject'] as String?) ??
        (result['title'] as String?) ??
        (result['description'] as String?);
    final status = result['status'] as String?;
    final activeForm = result['activeForm'] as String?;
    return _TaskBody(
      icon: Icons.task_alt,
      iconColor: Theme.of(context).colorScheme.primary,
      headline: subject,
      sublines: [if (activeForm != null && activeForm.isNotEmpty) activeForm],
      status: status,
    );
  }

  static List<_TaskItem> _extractListItems(Map<String, dynamic>? result) {
    if (result == null) return const [];
    final raw =
        WireParsers.asList(result['tasks']) ??
        WireParsers.asList(result['items']) ??
        WireParsers.asList(result['todos']);
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => _TaskItem(
            subject:
                m['subject'] as String? ??
                m['title'] as String? ??
                m['content'] as String? ??
                m['description'] as String?,
            status: m['status'] as String?,
            activeForm: m['activeForm'] as String?,
          ),
        )
        .where((t) => t.subject != null && t.subject!.isNotEmpty)
        .toList();
  }
}

class _TaskItem {
  const _TaskItem({this.subject, this.status, this.activeForm});
  final String? subject;
  final String? status;
  final String? activeForm;
}

class _TaskBody extends StatelessWidget {
  const _TaskBody({
    required this.icon,
    required this.iconColor,
    required this.headline,
    required this.sublines,
    this.status,
  });

  final IconData icon;
  final Color iconColor;
  final String? headline;
  final List<String> sublines;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (headline != null && headline!.isNotEmpty)
                Text(
                  headline!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              for (final s in sublines)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxxs),
                  child: Text(
                    s,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: AppLineHeight.normal,
                    ),
                  ),
                ),
              if (status != null && status!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _StatusBadge(status: status!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.item});
  final _TaskItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.circle,
              size: 6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.subject!, style: theme.textTheme.bodySmall),
                if (item.activeForm != null && item.activeForm!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.activeForm!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (item.status != null && item.status!.isNotEmpty)
            _StatusBadge(status: item.status!),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      'completed' => AppColors.success,
      'in_progress' => theme.colorScheme.primary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
