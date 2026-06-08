import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
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
    final name = (tool['name'] as String?) ?? '';
    final toolId = _toolIdFor(tool);

    switch (name) {
      case 'TaskCreate':
        final input = WireParsers.asMap(tool['input']) ?? const {};
        final subject = input['subject'] as String?;
        if (subject == null || subject.isEmpty) return existing;
        final itemId = _deriveIdStatic(
          explicit: input['id'] as String?,
          fallback: 'create-$subject',
          toolId: toolId,
        );
        // De-dupe: if the same id is already present, leave the list alone.
        if (existing.any((e) => e.id == itemId)) return existing;
        return [
          ...existing,
          TodoItem(
            id: itemId,
            content: subject,
            status: _statusFromString(input['status'] as String?),
            priority: 'medium',
            order: existing.length,
            createdAt: now,
            updatedAt: now,
            sessionId: session,
          ),
        ];

      case 'TaskUpdate':
        final input = WireParsers.asMap(tool['input']) ?? const {};
        final explicitId = input['taskId'] as String? ?? input['id'] as String?;
        if (explicitId == null) return existing;
        final updated = existing.map((e) {
          if (e.id != explicitId) return e;
          return e.copyWith(
            status: _statusFromString(input['status'] as String?),
            updatedAt: now,
            completedAt: _isCompletedString(input['status'] as String?)
                ? (e.completedAt ?? now)
                : null,
          );
        }).toList();
        return updated;

      case 'TaskList':
        final result = WireParsers.asMap(tool['result']);
        final raw = WireParsers.asList(result?['tasks']) ??
            WireParsers.asList(result?['items']) ??
            WireParsers.asList(result?['todos']) ??
            const [];
        return _domainFromList(raw, session, now);

      case 'TaskGet':
        final result = WireParsers.asMap(tool['result']);
        if (result == null) return existing;
        final subject = (result['subject'] as String?) ??
            (result['title'] as String?) ??
            (result['description'] as String?) ??
            (result['content'] as String?);
        if (subject == null || subject.isEmpty) return existing;
        final itemId = _deriveIdStatic(
          explicit: (result['id'] as String?) ??
              (result['taskId'] as String?) ??
              (WireParsers.asMap(tool['input'])?['taskId'] as String?),
          fallback: 'get-$subject',
          toolId: toolId,
        );
        if (existing.any((e) => e.id == itemId)) {
          return existing.map((e) {
            if (e.id != itemId) return e;
            return e.copyWith(
              status: _statusFromString(result['status'] as String?),
              updatedAt: now,
            );
          }).toList();
        }
        return [
          ...existing,
          TodoItem(
            id: itemId,
            content: subject,
            status: _statusFromString(result['status'] as String?),
            priority: 'medium',
            order: existing.length,
            createdAt: now,
            updatedAt: now,
            sessionId: session,
          ),
        ];

      default:
        return existing;
    }
  }

  /// Static read of the current session's items — used by the static
  /// resolver so the notifier push works without a live `WidgetRef`.
  static List<TodoItem> _currentSessionItemsFor(
    String? sessionId,
    BuildContext context,
  ) {
    if (sessionId == null) return const [];
    final state = ProviderScope.containerOf(context, listen: false)
        .read(todoStateNotifierProvider);
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
      final subject = m['subject'] as String? ??
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
  String get _name => (widget.tool['name'] as String?) ?? '';

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
    final subject = input['subject'] as String?;
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
    final subject = input['subject'] as String?;

    return _TaskBody(
      icon: Icons.edit_note,
      iconColor: Theme.of(context).colorScheme.primary,
      headline: subject ?? (taskId != null ? 'Task #$taskId' : null),
      sublines: [
        if (activeForm != null && activeForm.isNotEmpty) activeForm,
      ],
      status: status,
    );
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
    final subject = (result['subject'] as String?) ??
        (result['title'] as String?) ??
        (result['description'] as String?);
    final status = result['status'] as String?;
    final activeForm = result['activeForm'] as String?;
    return _TaskBody(
      icon: Icons.task_alt,
      iconColor: Theme.of(context).colorScheme.primary,
      headline: subject,
      sublines: [
        if (activeForm != null && activeForm.isNotEmpty) activeForm,
      ],
      status: status,
    );
  }

  static List<_TaskItem> _extractListItems(Map<String, dynamic>? result) {
    if (result == null) return const [];
    final raw = WireParsers.asList(result['tasks']) ??
        WireParsers.asList(result['items']) ??
        WireParsers.asList(result['todos']);
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((m) => _TaskItem(
              subject: m['subject'] as String? ??
                  m['title'] as String? ??
                  m['content'] as String? ??
                  m['description'] as String?,
              status: m['status'] as String?,
              activeForm: m['activeForm'] as String?,
            ))
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
