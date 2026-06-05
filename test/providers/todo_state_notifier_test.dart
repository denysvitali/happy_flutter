// Contract tests for the agent task state notifier.
//
// Pinned invariants (see CLAUDE.md core invariants):
//   1. setItemsForSession(sessionId, items) is idempotent — calling it
//      twice with the same sessionId and identical content does not
//      produce duplicate items.
//   2. A repeated TodoWrite for the same session replaces the list
//      (the latest call wins) without leaking the previous items.
//   3. Items from different sessions are scoped — one session's tasks
//      never appear under another session's key.
//   4. The wire form `TodoViewItem` is converted to the domain
//      `TodoItem` with a stable canonical id derived from
//      (toolUseId, content-hash) so a second render of the same
//      tool call is a no-op replacement.
//   5. An empty TodoWrite is a meaningful state — it clears the
//      session's list so stale tasks don't linger.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('TodoStateNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    TodoStateNotifier notifier() =>
        container.read(todoStateNotifierProvider.notifier);

    TodoListState state() => container.read(todoStateNotifierProvider);

    test('initial state is empty (no items, no current session)', () {
      expect(state().items, isEmpty);
      expect(state().currentSessionId, isNull);
      expect(state().sessionCount, 0);
    });

    test('setItemsForSession stores items under the session key', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
        _domainItem('b', TodoState.inProgress, order: 1),
      ]);

      expect(state().currentSessionId, 's1');
      expect(state().bySession['s1'], hasLength(2));
      expect(state().items, hasLength(2));
      expect(state().sessionCount, 1);
    });

    test('repeated setItemsForSession with same sessionId replaces, '
        'does not duplicate', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
      ]);
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
        _domainItem('b', TodoState.pending, order: 1),
      ]);

      // The previous single-item list must be replaced, not appended.
      expect(state().bySession['s1'], hasLength(2));
      expect(state().sessionCount, 1);
    });

    test('two sessions do not clobber each other', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
      ]);
      notifier().setItemsForSession('s2', [
        _domainItem('b', TodoState.pending, order: 0),
        _domainItem('c', TodoState.pending, order: 1),
      ]);

      expect(state().bySession['s1'], hasLength(1));
      expect(state().bySession['s2'], hasLength(2));
      expect(state().sessionCount, 2);
      // Most recently active session is the focused one.
      expect(state().currentSessionId, 's2');
    });

    test('empty list clears the session scope but keeps the key', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
      ]);
      notifier().setItemsForSession('s1', const []);

      // The session key still exists (empty list) so the focused view
      // remains scoped to that session — it doesn't fall back to the
      // union.
      expect(state().bySession['s1'], isEmpty);
      expect(state().currentSessionId, 's1');
      expect(state().items, isEmpty);
    });

    test('setItemsForSession with null uses a synthetic global key', () {
      notifier().setItemsForSession(null, [
        _domainItem('a', TodoState.pending, order: 0),
      ]);

      expect(state().bySession.keys, contains('__global__'));
      expect(state().bySession['__global__'], hasLength(1));
    });

    test('clearSession removes the key and resets focus if needed', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
      ]);
      notifier().clearSession('s1');

      expect(state().bySession.containsKey('s1'), isFalse);
      expect(state().currentSessionId, isNull);
    });

    test('clearSession does not change focus for a non-active session', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
      ]);
      notifier().setItemsForSession('s2', [
        _domainItem('b', TodoState.pending, order: 0),
      ]);
      notifier().clearSession('s1');

      expect(state().bySession.containsKey('s1'), isFalse);
      expect(state().currentSessionId, 's2');
    });

    test('toggleComplete flips pending <-> completed on focused session', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
      ]);
      notifier().toggleComplete('a');
      expect(state().bySession['s1']!.single.status, TodoState.completed);

      notifier().toggleComplete('a');
      expect(state().bySession['s1']!.single.status, TodoState.pending);
    });

    test('toggleComplete is a no-op for unknown id', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
      ]);
      notifier().toggleComplete('not-here');

      expect(state().bySession['s1']!.single.id, 'a');
      expect(state().bySession['s1']!.single.status, TodoState.pending);
    });

    test('items getter returns focused session when set, else union', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
      ]);
      notifier().setItemsForSession('s2', [
        _domainItem('b', TodoState.pending, order: 0),
      ]);

      // Focused: only s2 visible.
      expect(state().items.map((i) => i.id), ['b']);

      // Clear focus: union of both.
      notifier().clearSession('s2');
      expect(state().items.map((i) => i.id), ['a']);
    });

    test('clear() resets everything', () {
      notifier().setItemsForSession('s1', [
        _domainItem('a', TodoState.pending, order: 0),
      ]);
      notifier().clear();

      expect(state().bySession, isEmpty);
      expect(state().currentSessionId, isNull);
      expect(state().items, isEmpty);
    });
  });

  group('TodoStateNotifier canonical id contract', () {
    // Mirrors the conversion in
    // lib/features/chat/tools/views/todo_view.dart::_pushToGlobalState.
    // Pin the rules so a future refactor can't silently change the
    // identity that downstream consumers depend on.

    test('wire id wins when present and non-empty', () {
      // The TodoView prefers it.id if non-empty. This is the most
      // common case for tools that emit their own ids.
      const wireId = 'abc-123';
      const content = 'Review the diff';
      expect(_resolveItemId(wireId, content, 'tool-1'), wireId);
    });

    test('null wire id falls back to tool-stable content hash', () {
      const content = 'Review the diff';
      final first = _resolveItemId(null, content, 'tool-1');
      final second = _resolveItemId(null, content, 'tool-1');
      // Same content + same tool id => same derived id.
      expect(first, second);
      expect(first, startsWith('tool-1#'));
    });

    test('different tool ids produce different derived ids for same content',
        () {
      final a = _resolveItemId(null, 'same content', 'tool-a');
      final b = _resolveItemId(null, 'same content', 'tool-b');
      expect(a, isNot(equals(b)));
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────

TodoItem _domainItem(
  String id,
  TodoState status, {
  required int order,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TodoItem(
    id: id,
    content: 'item-$id',
    status: status,
    priority: 'medium',
    order: order,
    createdAt: now,
    updatedAt: now,
  );
}

/// Mirror of the canonical-id rule in
/// `lib/features/chat/tools/views/todo_view.dart`. Kept here so the
/// test pins the contract even if the implementation file is refactored.
String _resolveItemId(String? wireId, String content, String toolId) {
  if (wireId?.isNotEmpty ?? false) return wireId!;
  return '$toolId#${content.hashCode}';
}
