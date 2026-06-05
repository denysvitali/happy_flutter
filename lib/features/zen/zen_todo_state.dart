// Re-export of the canonical task state notifier from `core/providers`.
//
// Kept under `features/zen/` so legacy imports of the file continue
// to resolve. The notifier itself lives in `core/providers/` so
// non-zen features (e.g. the chat tool view) can consume it through
// the standard app_providers barrel.
export '../../core/providers/todo_state_notifier.dart'
    show
        TodoListState,
        TodoStateNotifier,
        todoStateNotifierProvider;
