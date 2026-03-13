# State Management Recommendation

**Date:** 2026-03-13
**Agent:** A3 — State Management Specialist

---

## Current Approach

Riverpod v3 with manual NotifierProvider (no code generation). A Sync singleton serves as the central data hub, with providers acting as UI projections via `loadFromSync()` / `refreshFromSync()`.

**Recommendation:** Keep Riverpod v3 manual NotifierProvider. The current choice is scalable and test-friendly. Focus improvements on fixing bugs and reducing sync coupling.

---

## Critical Bugs Found

### 1. FeedState Cache Invalidation Bug (P0)

**File:** `lib/core/providers/feed_notifier.dart` (lines 52–75)

`FeedState.copyWith()` does not clear `_unreadCountCache` and `_unreadNotificationsCache`. New instances inherit stale cached values.

```dart
// BUG: copyWith() creates new FeedState but caches are not cleared
FeedState copyWith({List<FeedItem>? items, List<Notification>? notifications}) {
  return FeedState(
    items: items ?? this.items,
    notifications: notifications ?? this.notifications,
  );
  // _unreadCountCache and _unreadNotificationsCache carry over
}
```

**Fix:**
```dart
FeedState copyWith({...}) {
  return FeedState(
    items: items ?? this.items,
    notifications: notifications ?? this.notifications,
  ).._unreadCountCache = null
   .._unreadNotificationsCache = null;
}
```

### 2. TodoListState Cache Invalidation Bug (P0)

**File:** `lib/core/providers/todo_notifier.dart` (lines 133–153)

`TodoListState.copyWith()` does not clear `_allTodosCache`. After list changes, `allTodos` returns stale combined list.

**Fix:** Same pattern — clear `_allTodosCache` in `copyWith()`.

### 3. Session Creation Race Condition (P0 — ROADMAP bug)

**File:** `lib/core/services/sync_service.dart` (lines 3487–3514)

When creating a session, `sync._notifyDataChanged()` fires but `SessionsNotifier.loadFromSync()` may not execute before a message send is attempted. This causes: `"Bad state: Session cb28ed0b17eda800a5bcf6b1b not loaded"`

**Root cause:** The provider bridge (sync → provider) is asynchronous. No guarantee that `loadFromSync()` completes between session creation and message send.

---

## High Priority Issues

### 4. Inconsistent Mutation Pattern

**File:** `lib/core/providers/session_git_status_notifier.dart` (line 41)

```dart
// Line 37 - Good: spread operator
state = {...state, sessionId: status};

// Line 41 - Inconsistent: creates copy then mutates
state = Map<String, GitStatus>.from(state)..remove(sessionId);
```

**Fix:** Standardize on spread operators everywhere.

### 5. Redundant Double-Load in AuthStateNotifier

**File:** `lib/core/providers/auth_state_notifier.dart` (lines 53–77)

`checkAuth()` calls `loadFromSync()` for all providers twice — once before awaiting sync queues, once after. The first batch is a no-op (queues are empty).

**Fix:** Remove the first batch of `loadFromSync()` calls.

---

## Medium Priority Issues

### 6. Missing Logging in loadFromSync Guards

All notifiers guard with `if (!sync.isInitialized) return;` but silently. Add warning-level logging to aid debugging sync initialization issues.

### 7. Settings Nullable Field Workaround

`SettingsNotifier.updateSetting` uses JSON roundtrip to clear nullable fields because `copyWith()` uses `??`. This is fragile but functional. Consider `freezed` in a future refactor.

---

## Provider Architecture Summary

| Provider | State | Tests | Quality |
|----------|-------|-------|---------|
| `authStateNotifierProvider` | `AuthState` | Yes | Good (redundant load) |
| `sessionsNotifierProvider` | `Map<String, Session>` | Yes | Good |
| `machinesNotifierProvider` | `Map<String, Machine>` | Yes | Good |
| `settingsNotifierProvider` | `Settings` | Yes | Good (JSON workaround) |
| `connectionNotifierProvider` | `ConnectionStatus` | Yes | Good |
| `currentSessionNotifierProvider` | `Session?` | Yes | Good |
| `profileNotifierProvider` | `Profile?` | Yes | Good |
| `artifactsNotifierProvider` | `Map<String, DecryptedArtifact>` | Yes | Good |
| `friendsNotifierProvider` | `FriendsState` | Yes | Good (cache done right) |
| `feedNotifierProvider` | `FeedState` | Yes | **BUG: cache invalidation** |
| `todoStateNotifierProvider` | `TodoListState` | Yes | **BUG: cache invalidation** |
| `sessionGitStatusNotifierProvider` | `Map<String, GitStatus>` | Yes | OK (inconsistent mutation) |

---

## Scalability Concerns

1. **Provider count (12+)** — manageable, but the bridge pattern is fragile
2. **Message stream bottleneck** — all screens listen to `onSessionMessagesChanged`; consider session-specific streams if performance degrades
3. **Memory accumulation** — caches in FeedState and TodoListState can grow without bounds
