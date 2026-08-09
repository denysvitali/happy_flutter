# Sync Singleton Patterns

This document details patterns for working with the Sync singleton.

## Standard Screen Subscription Template

```dart
StreamSubscription<void>? _syncSubscription;

@override
void initState() {
  super.initState();
  Future<void>.microtask(() async {
    await ref.read(xNotifierProvider.notifier).refreshFromSync();
  });
  _syncSubscription = sync.onDataChanged.listen((_) {
    if (!mounted) return;
    ref.read(xNotifierProvider.notifier).loadFromSync();
  });
}

@override
void dispose() {
  _syncSubscription?.cancel();
  super.dispose();
}
```

**Note:** `ChatScreen` deviates from this template — it subscribes to both `sync.onDataChanged` and `sync.onSessionMessagesChanged`, and uses a local `_refreshFromSync()` with `setState()` because it manages paginated message lists locally.

## Sync Test Setup

`Sync()` is a true singleton (factory returns `_instance`), so every
`InvalidateSync` field must be re-wired in `setUp` or a previous test's
state leaks into the next one.

**Use `createTestSync()` from `test/helpers/test_helpers.dart`** — it is the
single source of truth for the field list and pre-wires every one to a no-op:

```dart
setUp(() {
  sync = createTestSync();
});
```

Do not hand-roll the field list in a test: it drifts the moment a domain is
added or removed. If a test needs realistic in-memory session maps rather than
no-ops, use `createPartialMockSync()` instead.

## Key Methods

- `sync.create()` — Full init for new login; awaits settings/profile/purchases
- `sync.restore()` — Restore on app restart; does NOT await settings/profile
- `sync.forceReconnect({reason})` — User-facing "Reconnect now" entry point;
  forces a fresh socket dial and (re-)arms the reconnect watchdog
- `sync.onDataChanged` — Stream for data changes (debounced 100ms)
- `sync.onSessionMessagesChanged` — Stream for session message changes (debounced 100ms)
- `sync.isInitialized` — Whether sync has been initialized
- `sync.isReady` — Set after sessions+machines resolve (separate from isInitialized)

## InvalidateSync

Each data type has an `InvalidateSync` for debounced server fetches:
- Exponential backoff: 1s–5s (with 0–250ms random jitter)
- Max retries: 5
- `invalidate()` — marks work needed, starts immediately if idle
- `invalidateAndAwait()` — invalidates and returns a Future for the cycle
- `dispose()` — cancels retry and cooldown timers

## Reconnect Watchdog

`resume()` arms a 15s watchdog when the socket is not connected (or is a
zombie — see below). On fire it forces `socketIoClient.reconnect()`,
invalidates syncs (cooldown-throttled), refreshes the visible session, and
re-arms itself while the socket stays disconnected. It is cancelled on
connect, `suspend()`, and `shutdown()`. This bounds foreground recovery to
~one watchdog period after the network returns, instead of waiting out
Socket.IO's 10-attempt backoff cycles.

An opening connection or Socket.IO Manager-owned retry loop counts as an
in-flight dial. Lifecycle, connectivity, and watchdog callers must not dispose
that Manager and start an overlapping generation; only explicit forced paths
(token rotation, zombie detection, and the user action) bypass the guard.

**Zombie sockets:** if the OS suspended the app before the 2s deferred
suspend-disconnect fired (common on iOS), the socket can still report
`connected` on resume while the server-side session is long dead. `resume()`
forces a fresh connection when status is `connected` but the app was
backgrounded longer than `Sync._zombieSocketMaxIdleMs` (45s).

## Testing Escape Hatches

Several `@visibleForTesting` members exist on `Sync`:
- `testSocketConnectedOverride`, `testSocketSendOverride`
- `testNotifyDataChanged()`, `testSetSessionMessages()`
