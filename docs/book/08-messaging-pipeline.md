# 8. The Messaging Pipeline

> **The most important chapter in the book.** Read this before touching `chat_screen.dart`, any `_sync_messaging*` file, or the `MessageOutbox`/`MessageCacheService`.

The messaging pipeline is what defends the **one tap = one stable message** invariant. It is split across six `_sync_messaging*.dart` part files plus two helper services (`MessageOutbox`, `MessageCacheService`) and three other services (`message_processing_service.dart`, `inline_message_processor.dart`, `tool_result_processor.dart`, `sidechain_grouper.dart`).

This chapter traces **one** message from the user's tap to its final state.

## Files

| File | LoC | Role |
|---|---|---|
| `lib/core/services/_sync_messaging.dart` | 1262 | Public surface: `sendMessage`, `fetchMessages`, the per-session `messagesSync` map, the merge entry point |
| `lib/core/services/_sync_messaging_send.dart` | 922 | The send path: optimistic insert, REST POST, outbox enqueue, retry |
| `lib/core/services/_sync_messaging_parse.dart` | 357 | Wire-envelope → `Message` parsing (the structural parse) |
| `lib/core/services/_sync_messaging_parse_output.dart` | 976 | Tool-output envelope parsing, summarization, dedupe |
| `lib/core/services/_sync_messaging_merge.dart` | 1428 | **The merge function. The largest single file.** |
| `lib/core/services/_sync_messaging_rpc.dart` | 954 | RPC layer for the send path |
| `lib/core/services/message_outbox.dart` | (sibling) | MMKV-backed failed-send queue |
| `lib/core/services/message_outbox_sqlite.dart` | (sibling) | SQLite variant of the outbox |
| `lib/core/services/message_cache_service.dart` | (sibling) | Last 200 messages per session in MMKV |
| `lib/core/services/message_processing_service.dart` | (sibling) | The orchestrator for an incoming message |
| `lib/core/services/inline_message_processor.dart` | (sibling) | Fast-path streaming (see [Chapter 7](07-socket.md)) |
| `lib/core/services/sidechain_grouper.dart` | (sibling) | Groups sidechain (subagent) messages into a tree |
| `lib/core/services/tool_result_processor.dart` | (sibling) | Tool-result envelope handling |

## The diagram (one message, end-to-end)

```
USER TAPS SEND
     │
     ▼
chat_screen.dart or chat_action_notifier.dart
     │  (ref.read(chatActionNotifierProvider.notifier).sendMessage(...))
     ▼
Sync.sendMessage(localId, text, ...)         [in _sync_messaging.dart]
     │
     ├──► optimistic insert into in-memory messages map
     ├──► MessageCacheService.scheduleSave(sessionId)         [500ms debounce]
     ├──► _sendSingle(localId, text, ...)                      [in _sync_messaging_send.dart]
     │       │
     │       ├──► if RPC streaming channel is open: send via RPC
     │       │       (_sync_messaging_rpc.dart)
     │       │
     │       └──► else: HTTP POST /v1/.../messages
     │                  with body { localId, text, ... }
     │                  │
     │                  ├── 200 OK (success) ──► mark Sent
     │                  │                          do NOT mark Merged (server hasn't echoed)
     │                  │                          server will emit api-update with the message
     │                  │
     │                  ├── 5xx / network ──► MessageOutbox.enqueue(localId, payload)
     │                  │                          MessageOutbox will retry (1s→30s, max 3)
     │                  │                          MessageOutbox.flush() runs on next resume/restart
     │                  │
     │                  └── 4xx (bad request) ──► mark Failed (no retry)
     │
     ▼
onDataChanged (debounced 100ms)
     │
     ▼
Notifier.loadFromSync() → ChatScreen rebuild → optimistic row visible
```

Now the server's turn:

```
SERVER PROCESSES MESSAGE
     │
     ▼
Server emits "api-update" over the socket
     │  payload: ApiUpdate { dataType: "message", ... }
     ▼
SocketIoClient → Sync.handleUpdate(update)
     │
     ▼
_sync_socket_events.dart dispatches by dataType
     │
     ▼
_sync_messaging.dart handler:
     │
     ├──► parse update.payload via _sync_messaging_parse.dart
     │       (wire envelope → Message with localId, serverId, content, role, ...)
     │
     ├──► if it's a tool-result envelope, route through tool_result_processor.dart
     │       and _sync_messaging_parse_output.dart
     │
     ├──► merge via _sync_messaging_merge.dart
     │       merge(localMessage: optimistic, serverMessage: server)
     │       │
     │       ├── if localMessage.localId == serverMessage.localId:
     │       │     REPLACE localMessage with serverMessage (in place)
     │       │     preserve `localId` (the new message's localId is the same)
     │       │     preserve `serverId` (set from serverMessage.id)
     │       │     update state Sent → Merged
     │       │
     │       ├── if serverMessage has no localId (inbound agent message):
     │       │     APPEND as new message
     │       │
     │       └── if neither: log warning, drop (data corruption)
     │
     ├──► if session has sidechain messages, route through sidechain_grouper.dart
     │       to assemble the parent/child tree
     │
     ├──► MessageCacheService.scheduleSave(sessionId)         [500ms debounce]
     │
     ▼
onSessionMessagesChanged(sessionId)    [no debounce]
onDataChanged                          [debounced 100ms]
     │
     ▼
ChatScreen receives onSessionMessagesChanged → _refreshFromSync()
     → re-reads in-memory messages for the session
     → setState → rebuild → optimistic row replaced by canonical
```

That's the full path. Now let's dissect each phase.

## Phase 1: User tap → `sendMessage` call

The screen's tap handler **does not** call `sync.sendMessage` directly. It calls the notifier:

```dart
// In chat_screen.dart (or _chat_screen_actions.dart)
ref.read(chatActionNotifierProvider.notifier).sendMessage(
  sessionId: session.id,
  text: textController.text,
  localId: LocalId.generate(),  // ← generated ONCE here
  // ... profile, mode, attachments, etc.
);
```

`LocalId.generate()` is called *exactly once*. The returned `LocalId` is passed through every layer. **Never** re-derive it from text, timestamp, or anything else.

`chat_action_notifier.dart` (`lib/core/providers/chat_action_notifier.dart`) is a `Notifier<void>` — its `state` is irrelevant, it's a pure action dispatcher. This is how the app avoids "screen calls `sync.method()`" coupling.

The notifier eventually calls `sync.sendMessage(localId: localId, ...)`. From here, the path is in `Sync`.

## Phase 2: Optimistic insert

`_sync_messaging.dart::sendMessage` first inserts the optimistic message into the in-memory messages map. The optimistic message has:

- `localId` (the one we just generated)
- `serverId = null`
- state = `Sending` (or `Draft` for queued)
- `text` as given
- `createdAt = DateTime.now().millisecondsSinceEpoch`

It's stored in a `Map<LocalId, Message>` keyed by `localId`. **The map is keyed by `localId`, not by position.** This is the structural defense of the invariant.

## Phase 3: Cache write (debounced)

`MessageCacheService.scheduleSave(sessionId)` is called. The service:

- Holds the last 200 messages per session in memory
- Debounces writes to MMKV by 500ms
- On flush, serializes the messages list and writes it under a per-session key

The cache is what makes cold start (after force-kill) show the last seen messages immediately. It's also what makes the optimistic message persist across a process restart — if the app is killed between optimistic insert and REST success, the next cold start loads the cached state, the user sees their message, and the outbox retries the send.

## Phase 4: Send (RPC or REST)

`_sync_messaging_send.dart::_sendSingle` decides:

- If a streaming RPC channel is already open for the session (rare; only when the agent is mid-response), use the RPC path (`_sync_messaging_rpc.dart`).
- Otherwise, use HTTP POST.

The REST body **carries the `localId`**:

```json
POST /v1/sessions/<id>/messages
{
  "localId": "<the one we generated>",
  "text": "continue",
  // ... mode, profile, attachments
}
```

The server stores the `localId` and echoes it back on the `api-update`. This is what allows the merge step to match.

### Three outcomes

| Outcome | State | What happens next |
|---|---|---|
| HTTP 200 | `Sent` (not yet `Merged`) | Server will eventually emit `api-update`; the merge step completes the transition |
| 5xx / network error | `Failed` (retry-eligible) | `MessageOutbox.enqueue(localId, payload)`; outbox retries with backoff |
| 4xx (bad request) | `Failed` (no retry) | Logged + Sentry. User sees "Failed — tap to retry" |

Note: `Sent` and `Merged` are different states. `Sent` = "the server accepted it." `Merged` = "the server echoed it back and we replaced the optimistic row." A successful `Sent` that is not yet `Merged` is normal during high-latency or high-concurrency.

## Phase 5: Outbox (the retry queue)

`MessageOutbox` is the safety net for failed sends. It's in `lib/core/services/message_outbox.dart` (with a SQLite variant in `message_outbox_sqlite.dart`).

When a send fails with a retry-eligible error:

```dart
MessageOutbox.enqueue(
  localId: localId,  // ← the same one
  sessionId: sessionId,
  payload: {...},    // the body we tried to POST
  attempt: 1,
);
```

The outbox persists the entry to MMKV (or SQLite in the future). On the next opportunity — a network reconnect, a `resume()`, a periodic flush — `MessageOutbox.flush()` runs:

```
for entry in outbox:
  attempt += 1
  POST entry.payload
  if 200: dequeue, mark original localId as Sent
  if 4xx: dequeue, mark Failed (no retry)
  if 5xx: keep in outbox, schedule next retry with backoff
  if attempts > 3: dequeue, mark Failed (exhausted)
```

The retry uses the **same `localId`** as the original. The server sees the same `localId`, recognizes the retry, and acks with the same server message. The optimistic row's `localId` is preserved end-to-end.

> **Common bug:** an early version of the outbox regenerated `localId` on retry. The server saw a "new" message; the user got a duplicate. This is why the contract test `test/integration/message_outbox_e2e_test.dart` exists.

## Phase 6: Server echo (socket `api-update`)

The server, having processed the message, emits an `api-update` with a payload that contains the message. The payload structure is in `lib/core/wire/message_envelope.dart`. The wire-level *semantic* parsing is in `_sync_messaging_parse.dart`.

The parser:

1. Reads the `dataType` (e.g. `"message"`, `"tool-result"`, `"sidechain"`).
2. Reads the `content` (which can be a list of blocks, a string, a tool envelope).
3. Constructs a `Message` model with `localId`, `serverId`, `role`, `text`, `createdAt`, `meta`, `toolData`, etc.
4. Returns a list of `Message` objects (one update can carry multiple messages — e.g. a `tool-result` may also bring a status update).

`WireParsers` (in `lib/core/utils/wire_parsers.dart`) handles the lenient type coercion. The wire can return numbers as strings or vice versa depending on the server version; `WireParsers` makes the deserialization robust.

## Phase 7: Tool-result handling

If the update is a tool-result, the parser routes through `_sync_messaging_parse_output.dart` and `tool_result_processor.dart`. The output filter has a known set of "skip" categories that log at info-level (assistant content list is empty, unrecognized output content block, user content block type=X not handled, pi result with no tool rows) and a "log at warning for unknown" policy.

A `tool-result` carries a tool call id, an output (string or structured), a parent message id, an isError flag, and permissions. The handler appends a new message with `role = 'tool'` and `toolData = {...}` to the message stream.

The merge is by `localId` (if the tool result has one) or by append (if it's a new tool result from the server).

## Phase 8: Merge (the load-bearing step)

`_sync_messaging_merge.dart` (1428 LoC, the largest file in the messaging layer) is where the invariant is enforced. The merge function:

```dart
// Pseudocode — actual code is in _sync_messaging_merge.dart
void _mergeMessage(Message serverMessage) {
  final localId = serverMessage.localId;
  if (localId == null) {
    // Inbound server message with no localId (e.g. agent's reply)
    // → append as new
    _appendMessage(serverMessage);
    return;
  }

  final existing = _messagesByLocalId[localId];
  if (existing == null) {
    // Server has a message we don't have locally
    // → append as new (the optimistic may have been lost)
    _appendMessage(serverMessage);
    return;
  }

  // The match case: replace optimistic with canonical
  _messagesByLocalId[localId] = serverMessage.copyWith(
    // Preserve fields the server doesn't echo (rare)
    localId: existing.localId,
    // Trust the server for everything else
  );

  // Notify
  _notifySessionMessagesChanged(sessionId);
  _notifyDataChanged();
}
```

The merge is **by `localId`**, never by text or position. The map is keyed by `localId`. The function is called from the socket handler, the fetch path, and the outbox-retry-success path. All three call the same function.

The function also handles the "fetch brought in a message we already have" case: if `serverMessage.localId` matches a local entry, the local entry is replaced (idempotent). If the server has a different `serverId` for the same `localId`, the canonical `serverId` is taken from the server.

## Phase 9: Sidechain grouping

`sidechain_grouper.dart` groups sidechain (subagent) messages into a tree by `parentToolUseId`. A sidechain message is a separate logical message stream (an agent calling another agent). The grouping is **presentation only** — the merge function still treats each sidechain message as its own `Message` with its own `localId`. The tree is built lazily in the chat screen.

The recent production issue "Sidechain orphans absorbed" (100+ warnings/day) was about the sidechain grouper absorbing orphans. The fix (in `35db8c4`, on main, needs release) gates the Sentry capture on `triedFetchOlder && hasMoreOlder && count >= 5`. The normal happy-path absorption is now a local info log.

## Phase 10: Cache write + notification

After merge:

1. `MessageCacheService.scheduleSave(sessionId)` — 500ms debounce.
2. `onSessionMessagesChanged(sessionId)` — fires synchronously, no debounce.
3. `onDataChanged` — fires after 100ms debounce.

`ChatScreen` subscribes to `onSessionMessagesChanged` and rebuilds via local `setState`. Other screens that depend on data changed (`onDataChanged`) re-`loadFromSync()`.

## The dedup contract

The merge function is the dedup. It's idempotent: calling it twice with the same `serverMessage` produces the same state. The tests that pin this are:

- `test/integration/message_deduplication_e2e_test.dart` — REST-before-socket, fetch-overlap, server re-broadcast
- `test/integration/socket_echo_before_rest_e2e_test.dart` — socket before REST
- `test/integration/socket_echo_before_fetch_e2e_test.dart` — socket before fetch + re-broadcast
- `test/fsm/message_state_machine_contract_test.dart` — state transitions and identity preservation

## When the merge step fails

The merge function is the most-tested code in the app. If you're making changes here, run:

```bash
mise exec -- flutter test test/integration/message_deduplication_e2e_test.dart
mise exec -- flutter test test/integration/socket_echo_before_fetch_e2e_test.dart
mise exec -- flutter test test/integration/socket_echo_before_rest_e2e_test.dart
mise exec -- flutter test test/fsm/message_state_machine_contract_test.dart
```

These four tests cover every documented out-of-order delivery case.

## The state machine (for the message itself, not the FSM)

A message's state, as held in `MessageState`:

```
Draft  (created but not yet sent)
  ↓
Sending  (optimistic insert + REST in flight)
  ↓
  ├── Sent  (REST 200, awaiting server echo)
  │     ↓
  │   Merged  (server echoed; optimistic replaced)
  │
  ├── Pending  (REST succeeded but socket echo late)
  │     ↓
  │   Sent → Merged
  │
  └── Failed  (REST error)
        ↓
      Sending  (user retries, same localId)
```

A message that goes `Sent → Merged` is normal. A message that goes `Failed → Sending` (retry) preserves `localId`. A message that is `Merged` and gets a new server event for the same `localId` is a no-op (idempotent).

## The "stuck in Sending" recovery

A `Sending` message that never gets a response is bad. The codebase has two recovery paths:

1. **App suspend/resume** — `Sync.resume()` triggers a fetch for all open sessions, which brings the canonical state.
2. **`_sessionSpawnedAt` registry** — when a session is created, a 60-second timer marks it. If a send within that window fails, `_sync_operations_session.dart` retries the session-spawn up to 3 times. This is for the "session created but no message echo" race, not for the message itself.

A truly stuck `Sending` is rare; the production data shows it as a low-frequency issue.

## Files to read next

- `lib/core/services/_sync_messaging.dart` — start here for the public surface
- `lib/core/services/_sync_messaging_send.dart` — the send path
- `lib/core/services/_sync_messaging_merge.dart` — the merge function (read this whole file)
- `lib/core/services/_sync_messaging_parse.dart` — wire parsing
- `lib/core/services/message_outbox.dart` — the retry queue
- `lib/core/services/message_cache_service.dart` — the per-session cache
- `test/fsm/message_state_machine_contract_test.dart` — the contract
- `test/integration/message_deduplication_e2e_test.dart` — the dedup proof

## Gotchas

- The merge function is **the** load-bearing function. Every other file in the messaging pipeline can have a bug; the merge function is where the invariant is enforced. If you're not sure, read this file end-to-end.
- The optimistic insert happens **before** the REST call. If the REST call fails, the optimistic message is still in the map. The user sees their message; it's marked `Failed`.
- The cache write is debounced 500ms. If the user kills the app within 500ms of an optimistic insert, the message may not be cached. The outbox is the source of truth for retry; the cache is the source of truth for display.
- `MessageOutbox` and `MessageCacheService` are **separate** services. Don't confuse them.
- The `messagesSync` map is per-session. If you delete a session, clean up its entry.
- The fast-path `inline-message` does **not** go through the merge function for streaming chunks. It only writes the canonical state via the merge function when the server emits the final `api-update`.
- The FSM in `lib/core/fsm/` is a *projection*. The actual state is in the `Message` model; the FSM is a function that derives legal transitions.
- `LocalId` is a typed wrapper, not a string. Don't construct it from a string literal.
- The `localId` in a `Message` is the optimistic `localId`. The `serverId` is the server-assigned id. They are different things.
- "Replace the optimistic row" means *in the map*. The UI may briefly show two rows during the transition; the final state has one. The UI is responsible for stable rendering (using `localId` as the React-style key).
