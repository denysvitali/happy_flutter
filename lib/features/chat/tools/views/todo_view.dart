import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show TickerCanceled;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/todo.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/wire/wire_parsers.dart';
import '../tool_section_view.dart';

/// View-local task list item (the on-the-wire shape from TodoWrite).
///
/// Kept separate from the domain [TodoItem] in `core/models/todo.dart`
/// because the tool input only carries a subset of fields. Conversion
/// to the domain model happens in [TodoView.pushToolToGlobalState].
class TodoViewItem {
  TodoViewItem({
    required this.content,
    required this.status,
    this.priority,
    this.id,
    this.description,
  });
  final String content;
  final String status;
  final String? priority;
  final String? id;
  final String? description;

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isPending => status == 'pending';
}

/// View for displaying TodoWrite tool todo lists.
///
/// The parsed items are also pushed into [todoStateNotifierProvider] so
/// they remain visible to the user outside of the chat (session tasks
/// banner, Zen home). The push is driven by [ToolView] via
/// [pushToolToGlobalState] rather than this widget's own lifecycle —
/// the body only mounts while the tool card is expanded, so a collapsed
/// TodoWrite would otherwise never reach the global state. Codex hits
/// this path for every plan update (`todo_list` → `TodoWrite`), which is
/// why its task list used to stay empty in the app.
class TodoView extends ConsumerStatefulWidget {
  const TodoView({
    required this.tool,
    super.key,
    this.metadata,
    this.sessionId,
  });
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  /// Owning chat session — used to scope the global todo state.
  ///
  /// When `null`, items are stored under a synthetic global key so the
  /// Zen home can still display them.
  final String? sessionId;

  /// Wall-clock of the newest todo snapshot pushed per session bucket.
  ///
  /// The chat ListView is reversed, so a cold load mounts the newest
  /// tool card first and older ones after it. Without this guard the
  /// oldest TodoWrite in the window would win and the banner would show
  /// a stale plan.
  static final Map<String, int> _lastPushedAt = <String, int>{};

  /// Test-only reset of the out-of-order push guard.
  @visibleForTesting
  static void resetPushGuard() => _lastPushedAt.clear();

  /// Pushes the todo items carried by [tool] into the global
  /// [todoStateNotifierProvider], scoped to [sessionId].
  ///
  /// Called from [ToolView.initState] / [ToolView.didUpdateWidget] (the
  /// always-mounted parent) so a collapsed or auto-collapsed TodoWrite
  /// still updates the session tasks banner and the Zen list.
  static void pushToolToGlobalState(
    BuildContext context,
    Map<String, dynamic> tool,
    String? sessionId,
  ) {
    final bucket = sessionId ?? _globalBucketKey;
    final eventAt =
        WireParsers.parseInt(tool['completedAt']) ??
        WireParsers.parseInt(tool['createdAt']) ??
        DateTime.now().millisecondsSinceEpoch;
    final lastPushedAt = _lastPushedAt[bucket];
    if (lastPushedAt != null && eventAt < lastPushedAt) {
      // A newer snapshot already won — this is an out-of-order replay.
      return;
    }
    _lastPushedAt[bucket] = eventAt;

    final items = resolveTodos(tool);
    final now = DateTime.now().millisecondsSinceEpoch;
    final toolId = _toolIdFor(tool);
    final domain = <TodoItem>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      // Canonical id: prefer the wire id, then a tool-stable content
      // hash, so the same tool call always yields the same ids.
      final id = (it.id?.isNotEmpty ?? false)
          ? it.id!
          : '$toolId#${it.content.hashCode}';
      domain.add(
        TodoItem(
          id: id,
          content: it.content,
          status: TodoState.fromString(it.status),
          priority: it.priority ?? 'medium',
          order: i,
          description: it.description,
          createdAt: now,
          updatedAt: now,
          sessionId: sessionId,
        ),
      );
    }
    // An empty TodoWrite is still a meaningful state — it clears the
    // session's list so stale tasks don't linger in the banner.
    ProviderScope.containerOf(context, listen: false)
        .read(todoStateNotifierProvider.notifier)
        .setItemsForSession(sessionId, domain);
  }

  /// Stable identifier for a tool call. Used to derive deterministic
  /// item ids when the wire format doesn't carry one.
  static String _toolIdFor(Map<String, dynamic> tool) {
    final id = tool['toolUseId'] as String? ?? tool['id'] as String?;
    if (id != null && id.isNotEmpty) return id;
    return tool['name']?.toString() ?? 'todo';
  }

  /// Parses the todo items carried by [tool], covering every shape the
  /// supported agents emit:
  ///
  /// - Claude `TodoWrite`: `input.todos[{content,status}]`
  /// - Codex `todo_list`:  `input.items[{text,completed}]`
  /// - result-only variants (`newTodos`, `items`, `todos`, `output.*`)
  static List<TodoViewItem> resolveTodos(Map<String, dynamic> tool) {
    final input = WireParsers.asMap(tool['input']) ?? {};
    final rawResult = tool['result'];
    final result = rawResult is Map<String, dynamic> ? rawResult : null;

    var todos = _parseTodos(input['todos']);
    if (todos.isEmpty) {
      todos = _parseTodos(input['items']);
    }
    if (todos.isEmpty && result != null) {
      final newTodos = result['newTodos'] as List?;
      if (newTodos != null) {
        todos = _parseTodos(newTodos);
      }
    }
    if (todos.isEmpty && result != null) {
      todos = _parseTodos(result['items']);
    }
    if (todos.isEmpty && result != null) {
      todos = _parseTodos(result['todos']);
    }
    final nestedOutput = result != null
        ? WireParsers.asMap(result['output'])
        : null;
    if (todos.isEmpty && nestedOutput != null) {
      todos = _parseTodos(nestedOutput['items']);
    }
    if (todos.isEmpty && nestedOutput != null) {
      todos = _parseTodos(nestedOutput['todos']);
    }
    return todos;
  }

  static List<TodoViewItem> _parseTodos(dynamic todos) {
    if (todos == null) return const [];
    if (todos is! List) return const [];
    return todos
        .map((t) {
          final item = WireParsers.asMap(t);
          if (item == null) return null;
          final text =
              item['content'] as String? ?? item['text'] as String? ?? '';
          final completed = item['completed'] == true;
          final status =
              item['status'] as String? ??
              (completed ? 'completed' : 'pending');
          return TodoViewItem(
            content: text,
            status: status,
            priority: item['priority'] as String?,
            id: item['id'] as String?,
            description: item['description'] as String?,
          );
        })
        .whereType<TodoViewItem>()
        .toList();
  }

  @override
  ConsumerState<TodoView> createState() => _TodoViewState();
}

/// Bucket key used when no chat session is in scope.
const String _globalBucketKey = '__global__';

class _TodoViewState extends ConsumerState<TodoView> {
  List<TodoViewItem> _todos = const [];

  @override
  void initState() {
    super.initState();
    _todos = TodoView.resolveTodos(widget.tool);
  }

  @override
  void didUpdateWidget(TodoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = TodoView.resolveTodos(widget.tool);
    var changed = next.length != _todos.length;
    if (!changed) {
      for (var i = 0; i < next.length; i++) {
        if (_todos[i].status != next[i].status ||
            _todos[i].content != next[i].content ||
            _todos[i].description != next[i].description) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) return;
    setState(() => _todos = next);
  }

  @override
  Widget build(BuildContext context) {
    if (_todos.isEmpty) return const SizedBox.shrink();

    final completed = _todos.where((t) => t.isCompleted).length;
    final total = _todos.length;
    // Only the newest in-progress row pulses — one icon is a cheap
    // highlight; every row pulsing forever in an old transcript is not.
    final activeIndex = _todos.indexWhere((t) => t.isInProgress);

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Count summary header
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _CountSummary(completed: completed, total: total),
          ),
          // Task items
          ..._todos.asMap().entries.map(
            (entry) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              ),
              child: _TodoRow(
                key: ValueKey(
                  '${entry.value.id ?? entry.value.content}'
                  '_${entry.value.status}',
                ),
                todo: entry.value,
                pulsing: entry.key == activeIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small summary label showing "X/Y done".
class _CountSummary extends StatelessWidget {
  const _CountSummary({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDone = completed == total;
    final color = allDone
        ? AppColors.success
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(
          allDone ? Icons.check_circle_rounded : Icons.checklist_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$completed/$total done',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A single todo row with status icon and text.
class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo, this.pulsing = false, super.key});

  final TodoViewItem todo;

  /// Whether the status icon plays the pulse animation. Only one row per
  /// list pulses; the rest render a static highlighted icon.
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color statusColor;
    if (todo.isCompleted) {
      statusColor = AppColors.success;
    } else if (todo.isInProgress) {
      statusColor = theme.colorScheme.primary;
    } else {
      statusColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    }

    final Widget statusIcon;
    if (todo.isCompleted) {
      statusIcon = Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: statusColor,
      );
    } else if (todo.isInProgress) {
      statusIcon = pulsing && !AppMotion.reduceMotion(context)
          ? _PulsingIcon(color: statusColor)
          : Icon(
              Icons.radio_button_checked_rounded,
              size: 18,
              color: statusColor,
            );
    } else {
      statusIcon = Icon(
        Icons.check_box_outline_blank_rounded,
        size: 18,
        color: statusColor,
      );
    }

    final decoration = todo.isCompleted ? TextDecoration.lineThrough : null;
    final textColor = todo.isCompleted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: statusIcon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              todo.content,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                decoration: decoration,
                decorationColor: textColor,
                height: AppLineHeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated pulsing radio icon for in-progress items.
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.color});
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  /// Bounded intro: pulse a few cycles, then hold static at full opacity.
  ///
  /// An unbounded `repeat()` kept the frame pipeline warm for as long as a
  /// todo list with an in-progress item was visible — which is the resting
  /// state of any interrupted plan, so chat could never idle. The row is
  /// keyed by `id_status`, so real progress remounts it and restarts the
  /// intro.
  static const int _pulseCycles = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    unawaited(_runBoundedPulse());
  }

  Future<void> _runBoundedPulse() async {
    try {
      for (var i = 0; i < _pulseCycles; i++) {
        await _controller.forward(from: 0).orCancel;
        await _controller.reverse().orCancel;
      }
      _controller.value = 1.0;
    } on TickerCanceled {
      // Disposed mid-pulse — nothing to settle.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Icon(
        Icons.radio_button_checked_rounded,
        size: 18,
        color: widget.color,
      ),
    );
  }
}
