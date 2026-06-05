import 'package:riverpod/riverpod.dart';

import '../models/todo.dart';

/// Lightweight in-memory state for the agent task list.
///
/// Tasks are kept in a per-session map so concurrent sessions don't
/// clobber each other. The [items] getter exposes the items for the
/// most recently active session (or the union when no session is
/// focused — useful for the Zen home view).
class TodoListState {
  const TodoListState({
    this.bySession = const {},
    this.currentSessionId,
  });

  /// Per-session task lists, keyed by session id.
  final Map<String, List<TodoItem>> bySession;

  /// The session whose task list the UI is currently showing.
  ///
  /// When `null`, [items] returns the union across all sessions.
  final String? currentSessionId;

  /// Items visible to the current view.
  ///
  /// When [currentSessionId] is set, returns that session's list.
  /// Otherwise returns a flattened view of every session.
  List<TodoItem> get items {
    final focused = currentSessionId;
    if (focused != null) {
      return bySession[focused] ?? const [];
    }
    if (bySession.isEmpty) return const [];
    return bySession.values.expand((list) => list).toList(growable: false);
  }

  /// The number of distinct sessions currently holding tasks.
  int get sessionCount => bySession.length;

  TodoListState copyWith({
    Map<String, List<TodoItem>>? bySession,
    String? currentSessionId,
    bool clearCurrentSessionId = false,
  }) {
    return TodoListState(
      bySession: bySession ?? this.bySession,
      currentSessionId: clearCurrentSessionId
          ? null
          : (currentSessionId ?? this.currentSessionId),
    );
  }
}

/// Notifier that manages the agent task list in memory.
///
/// Tasks are not persisted; they are populated from the chat layer
/// (TodoWrite / todo_list tool results) and held in-memory for the
/// duration of the session.
class TodoStateNotifier extends Notifier<TodoListState> {
  @override
  TodoListState build() => const TodoListState();

  /// Replace the task list for a given session.
  ///
  /// The [sessionId] should be the chat session that produced the
  /// TodoWrite tool result. Passing `null` is treated as a global
  /// replace (no session scoping) and preserves the legacy single-list
  /// behaviour used by the Zen home when no session is in scope.
  void setItemsForSession(String? sessionId, List<TodoItem> items) {
    if (sessionId == null) {
      // No session in scope — store under a stable synthetic key.
      state = state.copyWith(
        bySession: {...state.bySession, '__global__': List.of(items)},
        currentSessionId: state.currentSessionId ?? '__global__',
      );
      return;
    }
    state = state.copyWith(
      bySession: {
        ...state.bySession,
        sessionId: List<TodoItem>.from(items),
      },
      currentSessionId: sessionId,
    );
  }

  /// Replace the full list of tasks (legacy single-list API).
  ///
  /// Prefer [setItemsForSession] when the producing session is known.
  void setItems(List<TodoItem> items) {
    setItemsForSession(state.currentSessionId, items);
  }

  /// Toggle a task between pending and completed by [id].
  ///
  /// Operates on the most recently active session. If the item is
  /// already completed, it reverts to pending.
  void toggleComplete(String id) {
    final sessionId = state.currentSessionId;
    if (sessionId == null) return;
    final existing = state.bySession[sessionId];
    if (existing == null) return;
    final updated = existing.map((item) {
      if (item.id != id) return item;
      final next = item.status == TodoState.completed
          ? TodoState.pending
          : TodoState.completed;
      return item.copyWith(status: next);
    }).toList();
    state = state.copyWith(
      bySession: {...state.bySession, sessionId: updated},
    );
  }

  /// Mark a task as [TodoState.completed] by [id].
  void markComplete(String id) {
    final sessionId = state.currentSessionId;
    if (sessionId == null) return;
    final existing = state.bySession[sessionId];
    if (existing == null) return;
    final updated = existing.map((item) {
      if (item.id != id) return item;
      return item.copyWith(status: TodoState.completed);
    }).toList();
    state = state.copyWith(
      bySession: {...state.bySession, sessionId: updated},
    );
  }

  /// Add a new task item to the current session's list.
  void addItem(TodoItem item) {
    final sessionId = state.currentSessionId ?? '__global__';
    final existing = state.bySession[sessionId] ?? const [];
    state = state.copyWith(
      bySession: {
        ...state.bySession,
        sessionId: [...existing, item],
      },
      currentSessionId: sessionId,
    );
  }

  /// Remove a task by [id] from the current session.
  void removeItem(String id) {
    final sessionId = state.currentSessionId;
    if (sessionId == null) return;
    final existing = state.bySession[sessionId];
    if (existing == null) return;
    state = state.copyWith(
      bySession: {
        ...state.bySession,
        sessionId: existing.where((i) => i.id != id).toList(),
      },
    );
  }

  /// Drop the task list for [sessionId] (called on session end).
  void clearSession(String sessionId) {
    if (!state.bySession.containsKey(sessionId)) return;
    final next = {...state.bySession}..remove(sessionId);
    state = state.copyWith(
      bySession: next,
      clearCurrentSessionId: state.currentSessionId == sessionId,
    );
  }

  void clear() {
    state = const TodoListState();
  }

  // No-ops for sync compatibility — tasks use in-memory state.
  void loadFromSync() {}
  Future<void> refreshFromSync() async {}
}

final todoStateNotifierProvider =
    NotifierProvider<TodoStateNotifier, TodoListState>(() {
      return TodoStateNotifier();
    });
