# 9. Outbox & Message Cache

Two storage services that make chat work offline and across crashes. They're not part of `Sync`'s part-file split — they're sibling services in `lib/core/services/`. They both use MMKV as the backing store.

## What they are

| Service | Purpose | File |
|---|---|---|
| `MessageOutbox` | Failed-send queue. Persists sends that failed with a retry-eligible error. Retries with backoff. | `lib/core/services/message_outbox.dart` |
| `MessageOutboxSqlite` | SQLite variant of the outbox (newer). | `lib/core/services/message_outbox_sqlite.dart` |
| `MessageCacheService` | Last 200 messages per session in MMKV. Restored on cold start. | `lib/core/services/message_cache_service.dart` |

These are two different jobs. The outbox is a *send queue*; the cache is a *display cache*. They are not interchangeable.

## `MessageOutbox`

### Why it exists

A user on a flaky train sends a message. The REST POST fails (network blip). Without the outbox, the message is lost. With the outbox, the message is persisted, the user sees "Failed — retrying", and the next time the network is up, the send goes through.

### Shape

```dart
class MessageOutbox {
  Future<void> enqueue({
    required LocalId localId,
    required String sessionId,
    required Map<String, dynamic> payload,
  });

  Future<void> flush();              // attempt all queued sends
  Future<void> restoreAndFlush();    // called on Sync.create / restore
  Future<void> flushPendingWrites(); // called on Sync.suspend
  Stream<OutboxState> get stateChanges;
}
```

### The retry schedule

```
attempt 1: wait 1s, retry
attempt 2: wait 2s, retry
attempt 3: wait 4s, retry
attempt 4: wait 8s, retry
attempt 5: wait 16s, retry
attempt 6: wait 30s, retry (capped)
max 3 successful retries → mark Failed (exhausted)
```

The cap is 3 retries (in the current production config). The backoff is `1s → 2s → 4s → 8s → 16s → 30s` (capped). The exact numbers are in `message_outbox.dart`.

> **Difference from `InvalidateSync`:** `InvalidateSync` retries up to 5 times with 1s→5s backoff. The outbox retries up to 3 times with 1s→30s backoff. The outbox is for end-user-visible sends; we want to retry longer because the user is waiting.

### Triggers for `flush()`

- `Sync.resume()` — app foregrounded, try again
- A socket reconnect — the network is back
- A periodic background timer (every 30s while the app is foregrounded)
- An explicit "retry" tap from the user

### Persistence

The outbox uses the encrypted `outbox-entries` MMKV value. A versioned envelope
retains separate account/server buckets. Only the authenticated owner's bucket
is restored. Persistence serializes shared-envelope read/modify/write operations,
and browser enqueue requires a committed IndexedDB transaction. Failed writes
leave the message failed, not falsely queued. Legacy ownerless entries remain
encrypted in the `unowned` bucket and are counted, but never auto-bound or retried;
safe account-confirmed recovery is still required for those entries.

The SQLite variant (`message_outbox_sqlite.dart`) uses a real table for the same data. It's newer and may be the future default; for now, both implementations are present.

### What the outbox does NOT do

- It does **not** re-decrypt the message before sending. The payload is the original POST body.
- It does **not** update the in-memory `Message` state. The state update happens when the server echoes the message back (or the user retries and it succeeds).
- Message text is never identity. Entries use canonical `localId`; repeated text
  with distinct IDs remains distinct. Re-enqueueing an ID replaces that entry.

### What the outbox DOES guarantee

- The `localId` is preserved across retries. The server sees the same `localId` and acks with the same server message. The optimistic row in the UI is unchanged.
- Pending heads retain per-session FIFO priority across backoff. A terminal
  dead-letter failure releases that head and retains its payload for manual retry.
- Confirmed `sent` rows cannot be downgraded by stale retry callbacks or restored
  pending/dead entries, including accepted rows still using their local ID.

### The contract test

`test/integration/message_outbox_e2e_test.dart` is the load-bearing test. It pins:

- A failed send lands in the outbox.
- The retry uses the **same** `localId`.
- The server's echo matches the optimistic row.
- After 3 failed retries, the message is marked Failed (exhausted) and removed from the outbox.
- A "retry" tap re-enqueues with a fresh attempt count.

## `MessageCacheService`

### Why it exists

A user kills the app. Reopens it. They want to see the last 200 messages of their current sessions, instantly, while the network fetch runs in the background. The cache is that.

### Shape

```dart
class MessageCacheService {
  static const int messagesPerSession = 200;

  Future<void> scheduleSave(String sessionId);   // debounced 5s
  Future<void> flushPendingWrites();            // synchronous flush
  Future<void> _restoreAllCachedMessages();     // called on Sync.create / restore
  List<Message>? getMessagesForSession(String sessionId);
  Future<void> clearSession(String sessionId);
}
```

The cache is **read by `Sync.getMessagesForSession(sessionId)`** when the in-memory state is empty (cold start). The in-memory state is the source of truth at runtime; the cache is the source of truth on cold start.

### Debounced writes

Every `scheduleSave(sessionId)` call resets a 5s timer (with a 15s hard ceiling so sustained streaming still flushes). When the timer fires, the service serializes the in-memory messages for that session and writes them to MMKV.

```
scheduleSave(sessionA)  ─┐
scheduleSave(sessionA)  ─┼─ 5s ────► write sessionA to MMKV
scheduleSave(sessionA)  ─┘
```

If the app is killed during the debounce window without a lifecycle callback, the write is lost; `Sync.suspend()` flushes pending saves synchronously so a normal background does not lose them. The cost is acceptable because the outbox handles the *send* side and the next cold-start will refetch from the server anyway.

### `flushPendingWrites()` on suspend

On `Sync.suspend()`, the service synchronously flushes all pending writes. This is what makes the cold start after a force-kill show the last seen messages. Without this, a user who backgrounds the app and force-kills it would see an empty chat on reopen.

### Cache size

`messagesPerSession = 200`. The cap is a per-session cap, not a global cap. A user with 50 sessions will have 50 × 200 = 10,000 messages in MMKV. For most users, that's a few MB.

The cap is enforced at write time: when saving, the service keeps the most recent 200 messages and drops the rest.

### When the cache is invalidated

The cache is **not** invalidated in the normal sense. The in-memory state is the truth; the cache is a snapshot. On cold start, the cache is loaded into memory, then the network fetch overlays it. Newer messages from the network replace older ones from the cache; older ones from the network are dropped if the cache already has newer ones.

The one explicit invalidation: `clearSession(sessionId)` is called when a session is deleted.

## The relationship to `Sync`

```
Sync.getMessagesForSession(sessionId):
  if in-memory has messages for sessionId:
    return in-memory
  else:
    return MessageCacheService.getMessagesForSession(sessionId)
```

That's it. The cache is a fallback. The in-memory state is the source.

## What the outbox + cache + fetch together guarantee

A user who:

1. Sends a message while online → optimistic insert + cache + REST + merge.
2. Goes offline → REST fails → outbox enqueue + cache update.
3. Comes back online → outbox flushes → REST succeeds → server echoes → merge.
4. Force-kills the app before the outbox flushes → cold start → cache loads → outbox flushes in background → server echoes → merge.
5. Force-kills the app and stays offline forever → cold start → cache loads the last seen state → outbox entries remain queued → next time online, they flush.

The user **always** sees their optimistic messages (via cache) and **always** gets them delivered (via outbox) when the network is back.

## Files to read next

- `lib/core/services/message_outbox.dart` — the retry queue
- `lib/core/services/message_outbox_sqlite.dart` — the SQLite variant
- `lib/core/services/message_cache_service.dart` — the per-session cache
- `lib/core/services/mmkv_storage.dart` — the underlying MMKV wrapper
- `test/integration/message_outbox_e2e_test.dart` — outbox contract
- `test/integration/message_cache_coldstart_e2e_test.dart` — cache cold start

## Gotchas

- The outbox and the cache are **separate**. If you call `MessageOutbox.enqueue` but forget `MessageCacheService.scheduleSave`, the message is in the outbox but not in the cache — and a force-kill before the next fetch loses the optimistic display.
- Retry budgets depend on failure class. Permanent failures dead-letter promptly;
  transient failures retain the longer configured budget. See production constants
  in `message_outbox.dart`, not historical three-attempt examples.
- The cache write is debounced 5s (15s ceiling); suspend starts an async worker
  flush and shutdown waits for it. A force-kill inside the window without a lifecycle callback loses that save. The outbox is the source of truth for the *send*; the cache is the source of truth for the *display*.
- On Linux, one delayed startup worker checks MMKV's mapped size against its live payload and compacts only materially sparse files; compaction never runs in the hot write path.
- Cache and outbox payloads use device-key at-rest encryption, separate from
  session transport encryption. This does not turn the display cache into a send
  queue or provide cross-device recovery.
- Each device has its own account/server-scoped outbox. If the user has two
  devices, each has its own queue. A message sent from device A and queued in A's outbox will not be retried by device B.
- `MessageOutboxSqlite` is newer. If you're writing new code, prefer it. The MMKV version is still the default at the time of this writing.
- The 200-message cap is per-session. If a user scrolls back into a session that was previously cached but has now grown, the older messages are gone — they have to be refetched from the server.
