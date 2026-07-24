# 4. Sync: Anatomy

## What `Sync` is

A single in-memory object that holds the entire mirror of the server's state for the current user. Sessions, machines, messages, artifacts, friends, feed, todos, settings, profile, purchases, push tokens, native update info, session git status, encryption keys, WebSocket state, per-session outbox state, fetch cursors — all live on this object.

It is constructed as a Dart singleton:

```dart
// lib/core/services/sync_service.dart
class Sync {
  factory Sync() => _instance;
  Sync._();
  static final Sync _instance = Sync._();
}
```

`lib/main.dart` does `final sync = Sync();` once. Every other file gets the same instance. Tests use `createTestSync()` from `test/helpers/test_helpers.dart` to reset the singleton's fields.

## Why one class

`docs/ARCHITECTURE.md` (May 2026) calls this out as the **god object** issue. The runtime is one class managing ~13 domains. The class is **textually decomposed** into 19 part files for navigation, but the runtime is still one object.

The decomposition is honest about the trade-off:

- ✅ Splitting into per-domain managers (Phase 3 of `ARCHITECTURE.md`) would require inventing repository interfaces, refactoring every `Notifier`, and finding a way to preserve the cross-domain ordering (e.g. `fetchMessages` must run after `fetchSessions`).
- ❌ Splitting hasn't happened because the cost is high and the benefit is mostly navigation, which the part files already provide.

When you add a new method to `Sync`, **put it in the part file that matches the concern.** Don't add it to `sync_service.dart` itself unless it's a class-level concern (constants, types, the factory).

## The file (top of `sync_service.dart`)

1149 lines. Holds:

1. **The factory and constructor** (lines 125-129).
2. **Constants** (lines 131-180): `sessionReadyTimeoutMs`, page sizes, fetch timeouts, supported permission modes, the system prompt suffix.
3. **Public fields**: in-memory state, per-domain `InvalidateSync` fields, streams, outbox refs.
4. **The `part` directives** (lines 69-86): the 19 part files.

```dart
part '_sync_data.dart';
part '_sync_data_artifacts.dart';
part '_sync_data_machines.dart';
part '_sync_health.dart';
part '_sync_isolate_helpers.dart';
part '_sync_lifecycle.dart';
part '_sync_messaging.dart';
part '_sync_messaging_merge.dart';
part '_sync_messaging_parse.dart';
part '_sync_messaging_parse_output.dart';
part '_sync_messaging_rpc.dart';
part '_sync_messaging_send.dart';
part '_sync_operations.dart';
part '_sync_operations_session.dart';
part '_sync_sessions.dart';
part '_sync_socket.dart';
part '_sync_socket_events.dart';
part '_sync_test_helpers.dart';
```

The main file's job: hold the public surface (fields, getters, top-level methods that span concerns), and `part` everything else.

## The 19 part files (the four concerns)

The 19 part files group into four concerns, but the names are not always intuitive. Here's the map.

### Concern 1: Lifecycle and operations

| File | LoC | What it holds |
|---|---|---|
| `_sync_lifecycle.dart` | 802 | `create`, `restore`, `suspend`, `resume`, `clear`, `isInitialized`, `isReady`. The app-entry / app-exit plumbing. |
| `_sync_operations.dart` | 384 | Cross-domain operations (e.g. session-archive, session-delete). |
| `_sync_operations_session.dart` | 1380 | Session-scoped operations (create, archive, delete, worktree creation, etc.). The largest of the part files. |
| `_sync_sessions.dart` | 163 | Session-list fetching, session updates. Thin — most session logic is in `_sync_operations_session.dart`. |
| `_sync_health.dart` | 68 | Health checks, liveness, freshness reports. |

### Concern 2: Data (per-domain fetching)

| File | LoC | What it holds |
|---|---|---|
| `_sync_data.dart` | 705 | The cross-domain fetch coordinator. Settings, profile, purchases, friends, todos, feed, push tokens, native update, session git status. |
| `_sync_data_artifacts.dart` | 234 | Artifact-specific fetch and merge. |
| `_sync_data_machines.dart` | 414 | Machine-specific fetch and merge. |

### Concern 3: Messaging (the hard part)

| File | LoC | What it holds |
|---|---|---|
| `_sync_messaging.dart` | 1262 | **The top of the messaging subsystem.** Public `sendMessage`, `fetchMessages`, message-merge entry points, the `messagesSync` map (per-session `InvalidateSync`). |
| `_sync_messaging_send.dart` | 922 | The send path: optimistic insert, REST POST, outbox enqueue, retry. |
| `_sync_messaging_parse.dart` | 357 | Wire-envelope → `Message` parsing. The structural parse (server enqueues, message kinds). |
| `_sync_messaging_parse_output.dart` | 976 | **The dense tool-output parser.** Tool-result envelopes, summarization, dedupe. The source of the `fetchMessages dropped (output filter)` production warnings before the recent fix. |
| `_sync_messaging_merge.dart` | 1428 | **The merge function.** Where `localId` identity is enforced. The largest single file. |
| `_sync_messaging_rpc.dart` | 954 | RPC layer — sending messages over the streaming RPC channel. |

### Concern 4: Socket and isolation

| File | LoC | What it holds |
|---|---|---|
| `_sync_socket.dart` | 804 | The socket connection, reconnect logic, the `onDataChanged` / `onSessionMessagesChanged` streams. |
| `_sync_socket_events.dart` | 798 | Per-event-type handlers: `api-update`, `inline-message`, etc. |
| `_sync_isolate_helpers.dart` | 319 | Isolate.run helpers for CPU-bound work (offline TTS, AES decrypt). The "no `this` capture" pattern. |
| `_sync_test_helpers.dart` | 459 | `@visibleForTesting` escape hatches: `testSocketConnectedOverride`, `testSocketSendOverride`, `testNotifyDataChanged()`, `testSetSessionMessages()`. |

## Total: 13,578 LoC

The `Sync` class is 1,149 + 12,429 = 13,578 LoC across 20 files. It is the largest single class in the codebase by a wide margin. (For comparison, the providers barrel is 19 files × ~80 LoC = ~1,500 LoC.)

## The public surface (what notifiers and screens touch)

Most notifiers don't touch `Sync` directly. They go through `loadFromSync()` / `refreshFromSync()` on the notifier itself. But the **direct calls** that exist (mostly in `chat_screen.dart`, `new_session_screen.dart`, and a handful of others) are:

```dart
sync.isInitialized           // bool
sync.isReady                // bool (after sessions+machines resolve)
sync.onDataChanged          // Stream<void>  (debounced 100ms)
sync.onSessionMessagesChanged  // Stream<String>  (session id per event)
sync.sendMessage(...)       // -> Future<SendResult>
sync.fetchMessages(...)     // -> Future<void>
sync.deleteSession(...)     // -> Future<void>
sync.abortSession(...)      // -> Future<void>
sync.applySettings(...)     // -> Future<void>
sync.createSession(...)     // -> Future<Session>
sync.createWorktree(...)    // -> Future<Worktree>
sync.suspend()              // -> Future<void>
sync.resume()               // -> Future<void>
```

Plus a few `load*` / `invalidate*` helpers, and `getMessagesForSession(sessionId)` / `getSession(sessionId)` for in-memory reads.

## The 9 `InvalidateSync` fields

`Sync` owns one `InvalidateSync` per data domain, exposed as public fields so notifiers can call `.invalidate()` / `.invalidateAndAwait()` on them:

```dart
InvalidateSync sessionsSync;
InvalidateSync settingsSync;
InvalidateSync profileSync;
InvalidateSync purchasesSync;
InvalidateSync machinesSync;
InvalidateSync pushTokenSync;
InvalidateSync nativeUpdateSync;
InvalidateSync artifactsSync;
InvalidateSync sessionGitStatusSync;
// plus:
Map<String, InvalidateSync> messagesSync;  // per session id
```

The authoritative list is `createTestSync()` in
`test/helpers/test_helpers.dart` — it must wire every field, so it fails to
compile when one is added or removed.

See [Chapter 6](06-invalidate-sync.md).

## How to add a new method to `Sync`

1. Decide which concern it belongs to (lifecycle, data, messaging, socket, operations).
2. Open the matching part file. If it doesn't fit any, add a new part file (declare it in `sync_service.dart`).
3. Put the method in the part file. Do **not** add it to `sync_service.dart` itself.
4. If the method needs new state, declare the field in `sync_service.dart` (so the public surface is in one place).
5. If the method needs to emit a stream event, use `onDataChanged` (global) or `onSessionMessagesChanged` (per-session).
6. Add a test in `test/services/sync_*_test.dart` or `test/integration/`.

## Files to read next

- `lib/core/services/sync_service.dart` — the top of the class
- `lib/core/services/_sync_lifecycle.dart` — start here for the entry/exit plumbing
- `docs/ARCHITECTURE.md` — the architecture review, including the god-object discussion

## Gotchas

- The `Sync` singleton returns a dirty global by default. **Tests must reset it.** Use `createTestSync()` from `test/helpers/test_helpers.dart`.
- A few methods that look like they should be in `Sync` are actually in helper services that `Sync` calls into (e.g. `MessageOutbox`, `MessageCacheService`, `AuthService`).
- The `_sync_operations_session.dart` and `_sync_messaging_merge.dart` files are huge and dense. Don't try to read them end-to-end; read the section you need.
- `_sync_health.dart` is small but the *fields* it depends on (last-fetched timestamps, retry counts) are scattered across the other part files. The freshness report is best-effort.
- `_sync_sessions.dart` is unusually thin (163 LoC) because most session logic was moved to `_sync_operations_session.dart`. If you're looking for a method and don't find it in `_sync_sessions.dart`, check `_sync_operations_session.dart` first.
- `SyncDomain` is an enum declared in `sync_service.dart` itself, used by `SyncSubscriptionMixin` to scope invalidations. See [Chapter 11](11-screen-subscription.md).
