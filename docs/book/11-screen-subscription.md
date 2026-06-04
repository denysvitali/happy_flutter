# 11. Screen Subscription

How a screen subscribes to the `Sync` singleton and re-renders when data changes. The codebase has three patterns; one is the default, one is the modern preference, and one is the documented exception.

## Pattern 1: Raw `onDataChanged.listen` (legacy)

```dart
class SessionsScreen extends ConsumerStatefulWidget {
  // ...
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  // ...
}
```

This is the "standard" pattern. It works but has problems:

- It fires for **every** data change, not just the data this screen cares about. A session-list screen rebuilds when friends change.
- It has no dedup. If a screen re-mounts, two listeners may run.
- It's verbose. Every screen has the same 8 lines.

10+ screens still use this pattern. If you're writing a new screen, **don't use it** — use Pattern 2.

## Pattern 2: `SyncSubscriptionMixin` (modern)

```dart
class SessionsScreen extends ConsumerStatefulWidget with SyncSubscriptionMixin {
  // ...
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  @override
  void initState() {
    super.initState();
    mixin.subscribeToDataChanged(ref, () {
      if (!mounted) return;
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
    });
  }

  // No dispose needed — the mixin handles it
}
```

`SyncSubscriptionMixin` (in `lib/core/utils/sync_subscription_mixin.dart`) provides:

- `subscribeToDataChanged(ref, cb)` — global stream with counter-based dedup
- `subscribeToDomains([SyncDomain.x, ...], cb)` — per-domain scoped subscriptions (newer)
- `subscribeToSessionMessagesChanged(sessionId, cb)` — chat-only

The dedup is the key feature. If a screen re-mounts (e.g. navigation), the mixin detects the existing subscription and doesn't create a new one. The `dispose` is automatic.

### Domain-scoped subscriptions

```dart
mixin.subscribeToDomains(
  [SyncDomain.sessions, SyncDomain.machines],
  () {
    // Called only when sessions OR machines invalidate, not on every data change
    ref.read(sessionsNotifierProvider.notifier).loadFromSync();
  },
);
```

The `SyncDomain` enum (in `sync_service.dart`) lists the eight domains. When a `SyncDomain.x` invalidation completes, the mixin re-fires the callback. This is the most efficient pattern when the screen only cares about a subset of data.

### The dedup mechanism

`SyncSubscriptionMixin` keeps a per-mixin map of subscription keys. When `subscribeToDataChanged` is called with the same key (default: the closure's identity), the existing subscription is reused. The `dispose` cancels the subscription if and only if this is the last subscriber.

This solves the "screen re-mounts during navigation, double listener" problem.

## Pattern 3: `ChatScreen` (the documented exception)

`ChatScreen` is the only screen that does **not** use either pattern. It has its own subscription:

```dart
@override
void initState() {
  super.initState();
  // ...
  _dataSubscription = sync.onDataChanged.listen((_) {
    if (!mounted) return;
    _refreshFromSync();
  });
  _messagesSubscription = sync.onSessionMessagesChanged.listen((sessionId) {
    if (!mounted) return;
    if (sessionId == widget.sessionId) {
      _refreshFromSync();
    }
  });
}
```

`ChatScreen` is the exception because:

1. It manages **paginated** message lists locally with `setState`, not via the global `loadFromSync` pattern. The standard pattern would re-fetch the whole list on every data change, which is wrong.
2. It cares about **per-session** message changes. The `onSessionMessagesChanged` stream carries the session id, and the listener filters.
3. It also cares about other data changes (e.g. the session itself updating) — hence the dual subscription.

If you need a similar dual subscription for another screen (e.g. a session detail view that shows both session and messages), the pattern is the same: subscribe to `onDataChanged` for the session-level data, subscribe to `onSessionMessagesChanged` filtered by the session id for the message list.

## The template (decision tree)

```
Is the screen's data paginated or local-state-heavy (e.g. message lists)?
  YES → ChatScreen pattern (onDataChanged + onSessionMessagesChanged, setState)
  NO  → Does the screen care about ALL data changes or a specific subset?
          ALL       → SyncSubscriptionMixin.subscribeToDataChanged
          SUBSET    → SyncSubscriptionMixin.subscribeToDomains([...])
```

In practice, the answer for 90% of screens is `subscribeToDomains([...])`.

## The "isReady" gate

Some screens check `sync.isReady` before they do anything:

```dart
@override
Widget build(BuildContext context) {
  if (!sync.isReady) {
    return const SplashScreen();
  }
  // ... normal build
}
```

`isReady` becomes `true` only after sessions and machines have resolved. Until then, the screen shows a splash. This is appropriate for screens that depend on machines or sessions being available.

For most screens, `isInitialized` is sufficient. The `loadFromSync()` call is a no-op when `!isInitialized`, so the subscription is safe to wire up before `create()` is called.

## The "refreshFromSync" microtask

```dart
Future<void>.microtask(() async {
  await ref.read(xNotifierProvider.notifier).refreshFromSync();
});
```

This runs *after* the first `build()`, so the widget tree is mounted. The `refreshFromSync` call is the one that does a server fetch. After it returns, the notifier has fresh data and the UI updates.

The `microtask` is important. Without it, the `ref.read` would happen during `initState`, which can cause issues with `ProviderContainer` initialization order. The microtask defers it to after the first frame.

## What happens when auth changes

`AuthStateNotifier` is the coordinator. On auth change (login or logout), it calls `loadFromSync()` or `clear()` on every other notifier. The screen subscriptions automatically re-fire.

For logout specifically, the in-memory state is wiped, the MMKV user data is wiped, and the UI navigates to the QR screen. For login, the state is initialized from the new session and the UI navigates to the sessions list.

The screen subscriptions themselves don't need to do anything special on auth change. The mixin handles it.

## Files to read next

- `lib/core/utils/sync_subscription_mixin.dart` — the mixin
- `lib/core/services/sync_service.dart` — the `SyncDomain` enum
- `lib/features/sessions/sessions_screen.dart` — a representative mixin user
- `lib/features/chat/chat_screen.dart` — the documented exception
- `docs/SYNC_PATTERNS.md` — the official quick-reference

## Gotchas

- `ChatScreen` is the *only* documented exception. If you find yourself wanting to deviate from the mixin pattern, check if `ChatScreen` is a model.
- The mixin's dedup is keyed by closure identity. If you create a new closure on every build (e.g. inline `() { ... }`), the dedup fails. Hoist the closure to a method or use a const key.
- `subscribeToDomains` fires when the **invalidation cycle** for that domain completes, not on every data change. If you need every change, use `subscribeToDataChanged`.
- `onSessionMessagesChanged` emits the **session id** as the event payload. The chat screen is the primary consumer; if you subscribe, filter by the session id.
- The microtask in `initState` is **not optional**. Without it, `refreshFromSync` can race with `ProviderContainer` initialization.
- The mixin's `dispose` cancels the subscription if and only if this is the last subscriber. If you have two screens subscribing to the same domain, navigating away from one keeps the subscription alive for the other.
- `sync.isReady` is a getter, not a stream. If you need to react to it changing, watch `connectionNotifierProvider` or `syncStateNotifierProvider`.
- The microtask pattern is the same in widget tests. The `pumpAndSettle` after the widget mount allows the microtask to run.
