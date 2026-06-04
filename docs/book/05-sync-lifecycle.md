# 5. Sync Lifecycle

This chapter is about **when** `Sync` does things, and how the app's lifecycle interacts with the network.

The four lifecycle methods you'll see in `main.dart` and the app lifecycle service:

- `sync.create()` — full init for a new login. Awaits settings/profile/purchases.
- `sync.restore()` — restore on app restart. Does **not** await settings/profile.
- `sync.suspend()` — app is going to background. Disconnect socket, cancel timers, flush MMKV.
- `sync.resume()` — app is foregrounding. Reconnect socket, invalidate syncs.

The "hard part" of the lifecycle is the suspend/resume pair, which is what the most recent sync commits were about.

## Where it lives

All four methods are in `_sync_lifecycle.dart` (802 LoC). Constants and the public surface are in `sync_service.dart`. The suspend/resume pair is interleaved with `_sync_socket.dart` (connection state) and `_sync_health.dart` (freshness reporting).

## `create()` — new login

Called from `AuthStateNotifier` after a successful QR scan or restore. Full sequence:

1. Initialize storage (`MMKVStorage.initialize()` etc.)
2. Construct API clients
3. Set `isInitialized = true` (not yet `isReady`)
4. Fetch settings, profile, purchases — **awaits** all three
5. Begin socket connection
6. Fetch sessions, machines, friends, etc. — fire-and-forget
7. When sessions and machines resolve → `isReady = true`

After `create()` returns, the UI is safe to use.

## `restore()` — app restart

Called from `AuthStateNotifier` when the user re-opens the app with a stored token. Similar to `create()` but:

- Settings/profile/purchases are **not** awaited — they're deferred to a background task.
- The user lands on the cached UI immediately, and the cached settings load behind it.

This is the reason `provider.notifier.refreshFromSync()` is called in a `Future<void>.microtask(...)` from `initState` — the data may not be ready when the screen mounts.

## `suspend()` — app to background

Triggered by `WidgetsBindingObserver.didChangeAppLifecycleState` when the app is paused.

```dart
// Pseudocode — actual code in _sync_lifecycle.dart
Future<void> suspend() async {
  // 1. Disconnect socket (unless rapid-cycling; see below)
  if (!recentlyResumed()) {
    await socketIoClient.disconnect();
  }
  // 2. Cancel all InvalidateSync retry timers
  for (final sync in allInvalidateSyncs) sync.dispose();
  // 3. Flush MMKV (sessions cache, message cache, drafts, outbox)
  await MessageCacheService.flushPendingWrites();
  await MessageOutbox.flushPendingWrites();
  await DraftStorage.flush();
  // 4. Mark suspended
  _suspendTime = DateTime.now();
}
```

The "flush MMKV" step is what makes the cold-start after a force-kill show the last seen messages.

## `resume()` — app to foreground

Triggered on `didChangeAppLifecycleState` resumed.

```dart
// Pseudocode
Future<void> resume() async {
  final wasRecent = _suspendTime != null &&
      DateTime.now().difference(_suspendTime!) < Duration(seconds: 2);
  _suspendTime = null;

  if (!wasRecent) {
    // 1. Reconnect socket
    socketIoClient.connect();
    // 2. Mark all InvalidateSyncs dirty
    for (final sync in allInvalidateSyncs) sync.invalidate();
  }
  // else: keep socket connected; skip the invalidate cascade.
}
```

## The rapid-cycling guard

If the user backgrounds the app for 200ms (notification panel pull, accidental swipe) and foregrounds it again, you do **not** want to:

1. Disconnect the socket (slow reconnect when the data is right there)
2. Re-fire every `InvalidateSync` (cascades of REST calls)

That's the "rapid cycling" or "short-suspend" problem. The guard works like this:

```
if (time since last resume < 2s):
    skip the suspend socket disconnect
else:
    disconnect on suspend
```

The exact value (2s) is a constant in `_sync_lifecycle.dart`. The whole `wasRecent` flag in the resume path is about this.

### The recent (May 2026) history of this code

The git log shows the rapid-cycling guard has been tweaked multiple times in the last week:

```
2d19860f fix(ci): attach Linux x64 binary to GitHub releases
e130ca02 revert(sync): drop short-suspend resume cascade skip (caused message loss)
89375dc9 fix(sync): honor socket-connected override in resume short-suspend skip
81dc2a26 perf(sync): skip resume fetch cascade after short suspends; fail permanently-gone sessions
5b52e0bc refactor(ui): extract shared widgets and standardize design tokens
```

The history:

1. `81dc2a26` — added a "skip resume fetch cascade after short suspends" optimization. Smart in theory.
2. `e130ca02` — **reverted** it because it caused message loss. The skip was too aggressive.
3. `89375dc9` — partially re-introduced it, but only when the socket is **actually** still connected (via the `testSocketConnectedOverride` test hook, but also in production code).

The lesson: any change to suspend/resume needs e2e coverage for message continuity. The tests to be aware of:

- `test/integration/session_reconnection_e2e_test.dart`
- `test/integration/lifecycle_midsend_localid_e2e_test.dart` (in particular — localId survives suspend/resume mid-send)
- `test/integration/session_lifecycle_e2e_test.dart`

When touching lifecycle code, run all three.

## `clear()` — logout

Triggered by `AuthStateNotifier` on logout. Sequence:

1. `suspend()` first (disconnect, cancel timers, flush)
2. Wipe in-memory state
3. `MMKVStorage.wipeUserData()` — clears all user-scoped MMKV keys
4. `TokenStorage.clear()` — wipes JWT
5. `isInitialized = false`, `isReady = false`
6. Notify every notifier via `authStateNotifier` → `loadFromSync` / `clear`

After `clear()`, the app is in the unauthenticated state and shows the QR screen.

## `isInitialized` vs `isReady`

Two booleans. They're not the same.

- `isInitialized = true` after `create()` or `restore()` returns. Storage, API clients, the basic structure are up.
- `isReady = true` only after sessions and machines have resolved. UI can use them.

Some screens need `isReady`; most just check `isInitialized` because they handle empty state gracefully.

`loadFromSync()` on a notifier is a **no-op** when `!isInitialized`. So the standard subscription template is safe to wire up before `create()` is called.

## The "app suspend races with in-flight `invalidateAndAwait()`" bug

From `ROADMAP.md`:

> **InvalidateSync disposed crash** | Fatal | 55 | Shipped in v1.0.0-154901 (1ba4ebc)
> App suspend races with in-flight `invalidateAndAwait()`; `dispose()` now completes normally instead of throwing `StateError`.

The fix is in `InvalidateSync.dispose()`: it must complete normally even if a fetch cycle is mid-flight. The implementation uses a sentinel/flag to detect "I was disposed while running" and resolves the cycle cleanly. See [Chapter 6](06-invalidate-sync.md) for the InvalidateSync internals.

## Files to read next

- `lib/core/services/_sync_lifecycle.dart` — all four lifecycle methods
- `lib/core/services/_sync_socket.dart` — connection state machine
- `lib/core/services/_sync_health.dart` — freshness reporting
- `lib/core/services/app_lifecycle_service.dart` — `WidgetsBindingObserver` glue
- `test/integration/session_reconnection_e2e_test.dart` — e2e reconnect

## Gotchas

- `isReady` is a getter, not a stream. If you need to react to it changing, watch `connectionNotifierProvider` or `syncStateNotifierProvider`.
- `suspend()` is async. The `WidgetsBindingObserver` callback is sync. The app lifecycle service does `unawaited(sync.suspend())`.
- The rapid-cycling guard threshold (2s) is hard-coded. If you change it, you need to update the tests.
- The "skip invalidate cascade" optimization was reverted once. Be careful reintroducing it.
- `clear()` does **not** delete the user's account or server-side data. It only clears local state and the JWT.
- `MMKVStorage` is shared across users on the same install (in the dev-flavor scenario). `clear()` only wipes *user-scoped* keys; non-user keys (like the custom server URL) survive.
