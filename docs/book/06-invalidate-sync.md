# 6. InvalidateSync

A small primitive that solves one problem: **how to fetch fresh data from the server without spamming it.**

`InvalidateSync` is a debounced server fetcher with exponential backoff. Every data domain has one.

## Where it lives

- Implementation: `lib/core/utils/invalidate_sync.dart`
- Holders: `Sync` (13 fields), plus the per-session `Map<String, InvalidateSync> messagesSync`
- Tests: `test/utils/invalidate_sync_test.dart` (and a few e2e tests in `test/integration/`)

## The shape

```dart
class InvalidateSync {
  InvalidateSync(this._fetch);  // _fetch: () => Future<void>

  Future<void> invalidate();                  // mark dirty; start cycle if idle
  Future<void> invalidateAndAwait();          // mark dirty; await cycle
  void dispose();                             // cancel timers; in-flight resolves
  Stream<InvalidateState> get stateChanges;   // for UI
  bool get isInFlight;                        // for tests
}
```

It's a state machine with three states: **idle**, **running**, **cooldown**.

## The cycle

```
invalidate()
  │
  ├── if idle, start the cycle now
  └── if running or cooldown, mark "dirty" so a follow-up cycle runs after

cycle:
  1. set state = running
  2. call _fetch()
  3. if _fetch threw, retry with backoff (1s, 2s, 4s, ..., 5s, capped at 5s with jitter)
     - max 5 retries
     - 0-250ms random jitter to avoid thundering herd
  4. on success or final failure, set state = cooldown
  5. cooldown = 0ms (or a small delay)
  6. if marked dirty during step 1-5, loop back to 1
  7. set state = idle
```

The exact backoff constants:

- base: 1s
- max delay: 5s
- max retries: 5
- jitter: 0-250ms

These are in `lib/core/utils/invalidate_sync.dart` and `lib/core/utils/backoff.dart`.

## `invalidate()` vs `invalidateAndAwait()`

Use `invalidate()` when you don't care to wait (e.g. a stream tick):

```dart
sync.sessionsSync.invalidate();
```

Use `invalidateAndAwait()` when you want to know the cycle is done (e.g. a refresh button):

```dart
await sync.sessionsSync.invalidateAndAwait();
```

`invalidateAndAwait()` returns when the current cycle (or the next one, if a cycle is about to start) finishes. It does **not** return after the *next* cycle; it returns after *this* cycle.

## Why per-domain

A 13-domain `InvalidateSync` set lets the system:

- Invalidate one domain without disturbing others (e.g. "fetch fresh messages" doesn't refetch settings)
- Have different backoff strategies per domain (e.g. messages are more chatty, settings are rare)
- Avoid the "one giant refetch on every change" anti-pattern

The per-session `Map<String, InvalidateSync> messagesSync` is even more granular: each session has its own message-fetch invalidation, so opening chat A doesn't trigger a fetch for chat B.

## How notifiers use them

Most notifiers don't call `invalidate()` directly. The standard flow is:

1. Server sends a socket event (`api-update` for `SyncDomain.sessions`).
2. `_sync_socket_events.dart` handler updates the in-memory state.
3. The handler calls `sync.sessionsSync.invalidate()` to ensure the next tick fetches.
4. After the debounce (100ms), `onDataChanged` fires.
5. Notifier's `loadFromSync()` runs and re-reads in-memory state.

So `invalidate()` is usually called *from the socket handler*, not from a notifier. Notifiers react to `onDataChanged`.

The exception is screens that *want* a fresh fetch right now (pull-to-refresh, "retry" button, app resume). Those call `invalidateAndAwait()`.

## `dispose()` and the suspend race

When the app suspends, `Sync` calls `dispose()` on every `InvalidateSync`. If a fetch is mid-flight, the future will eventually resolve or throw — `dispose()` doesn't cancel the network call. It just:

1. Cancels the retry timer
2. Cancels the cooldown timer
3. Sets a "disposed" flag

If a fetch resolves after dispose, the result is discarded (no `stateChanges` emit). If a fetch is *in-flight* and `dispose()` is called, the next `invalidate()` is a no-op (the `disposed` flag).

The race that caused the "InvalidateSync disposed crash" (55 fatal/day, fixed in `1ba4ebc`) was: a fetch threw → retry timer scheduled → app suspends → `dispose()` cancels the timer → on next suspend, the timer fires anyway because the cancel was non-atomic with the run.

The fix: make `dispose()` atomic. Cancel the timer **and** check a "I was canceled" flag inside the timer callback. If canceled, no-op. Tests pin this in `test/utils/invalidate_sync_test.dart`.

## The `messagesSync` map

Special case: messages are per-session, so a Map.

```dart
Map<String, InvalidateSync> messagesSync = {};

InvalidateSync messagesSyncFor(String sessionId) {
  return messagesSync.putIfAbsent(
    sessionId,
    () => InvalidateSync(() => sync.fetchMessages(sessionId)),
  );
}
```

When a session is deleted, the entry should be removed (otherwise the map grows unboundedly). The cleanup is in `_sync_messaging.dart` (search for `messagesSync.remove`).

## `SyncSubscriptionMixin` and `SyncDomain`

`SyncSubscriptionMixin` (in `lib/core/utils/sync_subscription_mixin.dart`) provides a more granular alternative to subscribing to `onDataChanged`:

```dart
mixin.subscribeToDomains([SyncDomain.sessions, SyncDomain.machines], () {
  // called only when sessions or machines invalidate
});
```

This is the newer, preferred pattern. The `SyncDomain` enum in `sync_service.dart` lists the eight domains. When a `SyncDomain.x` invalidation completes, the mixin re-fires the callback. See [Chapter 11](11-screen-subscription.md) for the full pattern.

## Files to read next

- `lib/core/utils/invalidate_sync.dart` — the implementation
- `lib/core/utils/backoff.dart` — the backoff helper
- `lib/core/utils/sync_subscription_mixin.dart` — the domain-scoped subscription
- `test/utils/invalidate_sync_test.dart` — unit tests
- `test/integration/session_reconnection_e2e_test.dart` — e2e behavior

## Gotchas

- `invalidateAndAwait()` does **not** return after the *next* cycle. If you call it three times in a row, the third call awaits the third cycle, not the first.
- The backoff caps at 5s, not 30s. The `MessageOutbox` has a different backoff (1s→30s, max 3 retries). They're different primitives for different jobs.
- `dispose()` is one-way. You can't "re-arm" an `InvalidateSync` after dispose. If you need to, construct a new one.
- The per-session `messagesSync` map can leak if you don't clean up. If you see a memory-growth bug, check it.
- The "max retries: 5" applies per cycle. A cycle that succeeds and then a new cycle starts has a fresh retry budget.
- The jitter is per-retry, not per-cycle. Two consecutive retries jitter independently.
