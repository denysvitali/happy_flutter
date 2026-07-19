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

`Sync()` is a true singleton (factory returns `_instance`). When testing, initialize all InvalidateSync fields:

```dart
setUp(() {
  sync = Sync();
  sync.sessionsSync = InvalidateSync(() async {});
  sync.settingsSync = InvalidateSync(() async {});
  sync.profileSync = InvalidateSync(() async {});
  sync.purchasesSync = InvalidateSync(() async {});
  sync.machinesSync = InvalidateSync(() async {});
  sync.pushTokenSync = InvalidateSync(() async {});
  sync.nativeUpdateSync = InvalidateSync(() async {});
  sync.artifactsSync = InvalidateSync(() async {});
  sync.friendsSync = InvalidateSync(() async {});
  sync.friendRequestsSync = InvalidateSync(() async {});
  sync.feedSync = InvalidateSync(() async {});
  sync.todosSync = InvalidateSync(() async {});
  sync.sessionGitStatusSync = InvalidateSync(() async {});
});
```

Or use `createTestSync()` from `test/helpers/test_helpers.dart` which pre-wires all fields to no-ops.

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

**Zombie sockets:** if the OS suspended the app before the 2s deferred
suspend-disconnect fired (common on iOS), the socket can still report
`connected` on resume while the server-side session is long dead. `resume()`
forces a fresh connection when status is `connected` but the app was
backgrounded longer than `Sync._zombieSocketMaxIdleMs` (60s).

## Testing Escape Hatches

Several `@visibleForTesting` members exist on `Sync`:
- `testSocketConnectedOverride`, `testSocketSendOverride`
- `testNotifyDataChanged()`, `testSetSessionMessages()`
