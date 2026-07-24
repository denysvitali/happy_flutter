# 1. The Big Picture

## What happy_flutter is

The mobile app for [Happy](https://github.com/anthropics/happy-cli-go) — a Claude Code companion. You're on a train, you want to talk to your dev machine at home. This is the train-side of that conversation.

Flutter 3.38.7, Dart 3.10+, Riverpod v3 (manual `Notifier`s, no codegen), Socket.IO realtime, MMKV local storage, NaCl + AES-256-GCM encryption.

## One-paragraph mental model

There is a server (the Happy CLI, running on your dev machine). There is an app (this). The app talks to the server over HTTPS for commands and over a persistent WebSocket for streaming updates. The server sends you `ApiUpdate` events whenever a session changes, a message lands, a friend request arrives, etc. The app's job is to keep a faithful local mirror of the server's state and present it.

Local state lives in a single in-memory object — the `Sync` singleton. UI subscribes to it through Riverpod providers. A tap in the UI calls `sync.sendMessage(...)`, which creates an optimistic local message with a fresh `localId`, hits REST, and waits for the server to echo the same message back over the socket, at which point the optimistic row is replaced by the canonical one — **by `localId`, never by text, never by position.**

That's the whole app. Everything else is details.

## The three globals

```dart
// lib/main.dart initializes these exactly once.
final sync = Sync();                  // state + API + socket + encryption
final socketIoClient = SocketIoClient(); // wired into sync, but exposed
final logger = LoggerService();       // 5000-entry circular buffer, Sentry forward
```

You can grep for `sync.` and `logger.` to see every call site. Most UI code should not call them directly — it should call notifier methods.

## Data flow (one direction, normal operation)

```
[User tap]
  → screen handler
  → ref.read(chatActionNotifierProvider.notifier).sendMessage(...)
  → sync.sendMessage(localId, text, ...)                 [optimistic insert + REST]
                                                            ↓
                                              MessageCacheService writes to MMKV
                                                            ↓
                                            HTTP POST /v1/.../messages
                                                            ↓
                                       (server processes, eventually emits ApiUpdate)
                                                            ↓
                                    Socket.IO event "api-update" → Sync.handleUpdate
                                                            ↓
                                       Sync merges by localId, updates in-memory state
                                                            ↓
                                  Stream<void> onDataChanged (debounced 100ms)
                                                            ↓
                                   Notifier.loadFromSync() → emits new state
                                                            ↓
                                          Riverpod rebuilds widgets
```

For everything except chat, the loop is simpler: `onDataChanged` → `loadFromSync()` → state update → rebuild. Chat uses an extra `onSessionMessagesChanged` stream because it manages paginated message lists locally.

## What this app is *not*

- **Not** an offline-first peer. The server is the source of truth. Local state is a cache + outbox.
- **Not** a Redux/Bloc app. State is in a singleton, not in reducers.
- **Not** using `freezed`/`json_serializable` for the core models. Most models are hand-written `fromJson`/`toJson`/`copyWith`. The `*.freezed.dart` / `*.g.dart` files you see are for *some* models, not all.
- **Not** a DI-heavy codebase. Services are constructed where used, often directly inside `Sync`.

## What to remember

1. **`Sync` is the world.** Touch the right `_sync_*.dart` part file; don't add new top-level globals.
2. **`localId` is identity.** Repeated text is never identity.
3. **Optimistic replacement is by `localId`.** Never by text similarity, never by list position.
4. **One tap = one logical message.** Even if REST and the socket echo arrive in any order.
5. **The FSM exists.** `lib/core/fsm/message_state_machine.dart` pins legal transitions. When in doubt, check the state machine.

## Files to read next

- `lib/main.dart` — the entry point, the three globals
- `lib/core/services/sync_service.dart` — the top of the Sync class (~1,700 LoC, with 21 part files)
- `lib/core/types/identity_types.dart` — `LocalId`, `ServerMessageId`, `SessionId`
- `lib/core/fsm/message_state_machine.dart` — the FSM

## Gotchas

- The fact that `Sync` is a singleton (`factory Sync() => _instance`) means **tests must reset its state**. Use `createTestSync()` from `test/helpers/test_helpers.dart`. The default `Sync()` returns a dirty global.
- There are two `dataType` parsing layers: `lib/core/wire/message_envelope.dart` (the structural envelope) and `lib/core/encryption/processors/` (the semantic content). They look similar but are not the same.
- The messaging FSM is a *projection* of event logs (`lib/core/event_log/`), not a real state machine on a live object. The "transition" functions return new state; they don't mutate.
