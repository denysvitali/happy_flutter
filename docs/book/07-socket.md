# 7. The Socket.IO Layer

A persistent WebSocket carries every "something changed on the server" event to the app. The connection is `wss://<server>/v1/updates`, Socket.IO protocol, websocket-only transport (no polling fallback), JWT-authenticated.

## Where it lives

- Client: `lib/core/api/socket_io_client.dart`
- Connection state on `Sync`: `lib/core/services/_sync_socket.dart` (804 LoC)
- Event dispatch: `lib/core/services/_sync_socket_events.dart` (798 LoC)
- Reconnect: same `_sync_socket.dart` (state machine for the connection)
- Lifecycle: `lib/core/services/_sync_lifecycle.dart` (suspend/resume)

## Connection lifecycle

```
disconnected ── connect() ──► connecting ── onConnect ──► connected
                                  │                          │
                                  │ onConnectError           │ onDisconnect
                                  ▼                          ▼
                              errored ◄──── backoff ──── disconnected
                                                            │
                                                       (auto-reconnect)
                                                            │
                                                            ▼
                                                        connecting
```

The reconnect backoff is `2s → 10s` (linear, not exponential). Why linear: a server that's down for 30s usually needs a moment to come back up; flooding it with reconnects doesn't help.

The connection state is exposed via `connectionNotifierProvider` so the UI can show "Reconnecting..." indicators.

## What runs over the socket

The server pushes two kinds of events:

1. **`api-update`** — an `ApiUpdate` event with a payload describing what changed (sessions, messages, machines, friends, todos, etc.). The dominant event type.
2. **`inline-message`** — a fast-path for assistant message deltas. Goes through `inline_message_processor.dart` (a separate helper service) and bypasses the full message-parse pipeline. Used for streaming.

Other events (e.g. friend-request, artifact-update) come through the same `api-update` channel with a different `dataType` field.

## How events land in `Sync`

```
Socket.IO "api-update" event
  → SocketIoClient handler
  → Sync.handleUpdate(ApiUpdate)
  → routes by ApiUpdate.dataType:
      - "session"      → updateSessionInPlace(...)
      - "message"      → processIncomingMessage(...)
      - "machine"      → updateMachineInPlace(...)
      - "friend"       → ...
      - etc.
  → updates in-memory state
  → calls onDataChanged (debounced 100ms)
  → if the update is for a session's messages, also calls onSessionMessagesChanged
```

The dispatch is in `_sync_socket_events.dart`. Each `dataType` has a handler. Some handlers are short (a few lines), some are long (the message handler is in `_sync_messaging.dart`).

## The fast path (`inline-message`)

A normal `api-update` carries a complete `ApiUpdate` envelope. The `inline-message` is a different shape — it's a single message delta (or a chunk of one). The processing is in `lib/core/services/inline_message_processor.dart`.

The fast path exists because the full `api-update` machinery is heavyweight (parse, merge, invalidate). For a streaming assistant response that produces 50 chunks per second, that's too much overhead. The fast path:

1. Decrypts the chunk
2. Appends to the in-memory message (or creates a new one if it's the first chunk)
3. Calls `onSessionMessagesChanged` for the chat screen
4. **Does not** call `onDataChanged` or invalidate anything

`ChatScreen` is the only consumer of the fast path. Other screens don't see streaming deltas.

## The `onDataChanged` stream

`Stream<void> onDataChanged` is **debounced 100ms**. Why:

- A burst of `api-update` events for the same session (e.g. 5 tool-result updates in a row) would trigger 5 `loadFromSync()` calls. The debounce coalesces them.
- The debounce is reset on every event during the 100ms window.

The debounce lives in `_sync_socket.dart`, in the `notifyDataChanged()` helper (and is exposed for tests as `testNotifyDataChanged()`).

## The `onSessionMessagesChanged` stream

`Stream<String> onSessionMessagesChanged` emits the session id of any session whose messages changed. The chat screen subscribes to this; on each event, it re-fetches *its* session's messages (with `setState`, not via the global `loadFromSync`).

This is the documented exception to the standard subscription template — see [Chapter 11](11-screen-subscription.md).

## Auth on the socket

The socket authenticates with a JWT. The token is read from `TokenStorage` (FlutterSecureStorage) at connect time. If the token rotates mid-session (e.g. via `token_refresh_manager.dart`), the socket **disconnects and reconnects** with the new token.

Token refresh is initiated by REST 401s, not by the socket.

## Reconnect: what survives

When the socket disconnects and reconnects, the in-memory state on `Sync` is **preserved**. The reconnect is purely a transport event; the data is still there.

What does *not* survive:

- The "we're connected" state for any per-message in-flight `api-update` ack. If the socket dropped between REST-success and socket-echo, the merge doesn't happen via the socket; the next `invalidateAndAwait` cycle (triggered by the disconnect) refetches.
- The fast-path streaming buffer. If you disconnect mid-stream, you have to re-open the session and refetch from the last server-acked position.

## Test override hooks

`Sync` exposes `@visibleForTesting` members for tests that need to simulate socket behavior without a real server:

```dart
@visibleForTesting
bool? testSocketConnectedOverride;  // forces socket "connected" state

@visibleForTesting
void testNotifyDataChanged();       // synchronously fires onDataChanged

@visibleForTesting
void testSetSessionMessages(String sessionId, List<Message> messages);
```

These are in `_sync_test_helpers.dart`. Use them when an e2e test needs to simulate "the server just sent an event."

## Files to read next

- `lib/core/api/socket_io_client.dart` — the raw client
- `lib/core/services/_sync_socket.dart` — connection state machine
- `lib/core/services/_sync_socket_events.dart` — event dispatch
- `lib/core/services/inline_message_processor.dart` — fast path
- `test/integration/socket_inline_message_e2e_test.dart` — fast-path e2e
- `test/integration/session_reconnection_e2e_test.dart` — reconnect e2e

## Gotchas

- The 100ms debounce on `onDataChanged` is global. If you need a sub-100ms latency for a specific event, use `onSessionMessagesChanged` (no debounce) or call the notifier directly.
- `inline-message` and `api-update` for the *same* message are not coordinated. The fast path processes deltas; the `api-update` carries the canonical message. If both arrive, the merge layer (in `_sync_messaging_merge.dart`) deduplicates by `localId`/`serverId`.
- The reconnect backoff is **2s → 10s**, not exponential. If you see "socket flapping" (connect/disconnect/connect), the linear backoff means it never slows down.
- The `onSessionMessagesChanged` stream emits the *session id* as the event payload. The chat screen is the primary consumer; if you subscribe, you need to filter by the session you're displaying.
- The socket does **not** carry the "agent finished" or "agent error" events directly. Those come via `api-update` with `dataType = "session-status"` or similar.
- JWT rotation is **disconnect + reconnect**, not a hot-swap. There's a brief window where the socket is down.
- The fast-path streaming buffer is **lost on disconnect**. The next chat open refetches from the last server-acked cursor.
