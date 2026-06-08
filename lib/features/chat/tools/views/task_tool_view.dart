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

  @override
  ConsumerState<TaskToolView> createState() => _TaskToolViewState();
}

class _TaskToolViewState extends ConsumerState<TaskToolView> {
  /// Stable id for this tool call — used to derive deterministic item ids
  /// when the wire format doesn't carry one. Same pattern as `TodoView`.
  String get _toolId {
    final id = widget.tool['toolUseId'] as String? ??
        widget.tool['id'] as String?;
    if (id != null && id.isNotEmpty) return id;
    return widget.tool['name']?.toString() ?? 'task';
  }

  @override
  void initState() {
    super.initState();
    // Defer to post-frame so we don't mutate the provider during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pushToGlobalState();
    });
  }

  @override
  void didUpdateWidget(TaskToolView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pushToGlobalState();
    });
  }

  String get _name => (widget.tool['name'] as String?) ?? '';

  void _pushToGlobalState() {
    final items = _resolveItems();
    final container = ProviderScope.containerOf(context, listen: false);
    container
        .read(todoStateNotifierProvider.notifier)
        .setItemsForSession(widget.sessionId, items);
  }

  /// Resolves the domain [TodoItem] list implied by the current tool call.
  ///
  /// Strategy differs per tool:
  /// - TaskCreate: add a single item with the subject.
  /// - TaskUpdate: mutate the matching item's status in place.
  /// - TaskList: replace the session's list with the listed tasks.
  /// - TaskGet: add a single item from the result snapshot.
  List<TodoItem> _resolveItems() {
    final session = widget.sessionId;
    final existing = _currentSessionItems(session);
    final now = DateTime.now().millisecondsSinceEpoch;

    switch (_name) {
      case 'TaskCreate':
        final input = WireParsers.asMap(widget.tool['input']) ?? const {};
        final subject = input['subject'] as String?;
        if (subject == null || subject.isEmpty) return existing;
        final itemId = _deriveId(
          explicit: input['id'] as String?,
          fallback: 'create-$subject',
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
        final input = WireParsers.asMap(widget.tool['input']) ?? const {};
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
        final result = WireParsers.asMap(widget.tool['result']);
        final raw = WireParsers.asList(result?['tasks']) ??
            WireParsers.asList(result?['items']) ??
            WireParsers.asList(result?['todos']) ??
            const [];
        return _domainFromList(raw, session, now);

      case 'TaskGet':
        final result = WireParsers.asMap(widget.tool['result']);
        if (result == null) return existing;
        final subject = (result['subject'] as String?) ??
            (result['title'] as String?) ??
            (result['description'] as String?) ??
            (result['content'] as String?);
        if (subject == null || subject.isEmpty) return existing;
        final itemId = _deriveId(
          explicit: (result['id'] as String?) ??
              (result['taskId'] as String?) ??
              (WireParsers.asMap(widget.tool['input'])?['taskId'] as String?),
          fallback: 'get-$subject',
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

  List<TodoItem> _currentSessionItems(String? sessionId) {
    if (sessionId == null) return const [];
    // Read once (non-reactive) — we just need the current snapshot.
    final state = ref.read(todoStateNotifierProvider);
    return state.bySession[sessionId] ?? const [];
  }

  String _deriveId({required String fallback, String? explicit}) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    // Use toolId + fallback key so repeated calls with the same wire
    // payload yield the same id.
    return '$_toolId#$fallback';
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
