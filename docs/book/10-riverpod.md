# 10. Riverpod v3 (manual)

The app uses Riverpod v3 with **manual** `NotifierProvider`s. **There is no `@riverpod` codegen.** No `*.g.dart` files for providers. No `riverpod_generator` in the build pipeline. Every notifier is a hand-written class extending `Notifier<T>`.

This is a deliberate choice. Codegen is great for boilerplate-heavy state; the app's state is small per notifier and the boilerplate is fine.

## Where it lives

- Barrel: `lib/core/providers/app_providers.dart` (16 lines, just exports)
- Per-domain notifiers: `lib/core/providers/*_notifier.dart` (15 files)
- Mixin: `lib/core/providers/_shared.dart` (the `unset` sentinel)
- Test overrides: `ProviderContainer(overrides: [...])` (standard Riverpod)

## The two notifier shapes

### Shape 1: `Notifier<T>` (state-bearing)

```dart
class SessionsNotifier extends Notifier<Map<String, Session>> {
  @override
  Map<String, Session> build() {
    // Initial state. Called once when the provider is first read.
    return const {};
  }

  void loadFromSync() {
    // Read from sync and emit. No await.
    if (!sync.isInitialized) return;
    state = sync.sessions;  // immutable update via spread or copyWith
  }

  Future<void> refreshFromSync() async {
    // Fetch from server + read. Called in initState via microtask.
    await sync.sessionsSync.invalidateAndAwait();
    loadFromSync();
  }
}

final sessionsNotifierProvider = NotifierProvider<SessionsNotifier, Map<String, Session>>(
  SessionsNotifier.new,
);
```

The `build()` method is called once when the provider is first read. It returns the initial state. The `state` setter emits a new value to all listeners.

### Shape 2: `Notifier<void>` (action dispatcher)

```dart
class ChatActionNotifier extends Notifier<void> {
  @override
  void build() {
    // state is void. build() is for any side-effect setup.
  }

  Future<void> sendMessage({
    required String sessionId,
    required String text,
    required LocalId localId,
    // ... other params
  }) async {
    await sync.sendMessage(
      localId: localId,
      sessionId: sessionId,
      text: text,
      // ...
    );
  }
}

final chatActionNotifierProvider = NotifierProvider<ChatActionNotifier, void>(
  ChatActionNotifier.new,
);
```

The `state` is `void`. The notifier is a **pure action dispatcher** — its `state` is irrelevant. Screens call methods on it. This is how the app avoids "screen calls `sync.method()`" coupling.

## The catalogue (19 providers)

| Provider | Type | State | Purpose |
|---|---|---|---|
| `authStateNotifierProvider` | `Notifier<AuthState>` | `AuthState` | **The coordinator.** On auth change, calls `loadFromSync`/`clear` on every other notifier. |
| `sessionsNotifierProvider` | `Notifier<Map<String, Session>>` | sessions | Session list |
| `machinesNotifierProvider` | `Notifier<Map<String, Machine>>` | machines | Machine list |
| `settingsNotifierProvider` | `Notifier<Settings>` | `Settings` | App settings |
| `profileNotifierProvider` | `Notifier<Profile?>` | profile | Current profile |
| `artifactsNotifierProvider` | `Notifier<Map<String, DecryptedArtifact>>` | artifacts | Decrypted artifacts |
| `friendsNotifierProvider` | `Notifier<FriendsState>` | friends | Friends list + requests |
| `currentSessionNotifierProvider` | `Notifier<Session?>` | current session | The session the chat screen is displaying |
| `sessionGitStatusNotifierProvider` | `Notifier<Map<String, GitStatus>>` | git status | Per-session git status |
| `chatActionNotifierProvider` | `Notifier<void>` | (actions) | Chat action dispatcher |
| `loggerNotifierProvider` | `Notifier<LoggerState>` | log state | 200ms debounced log buffer |
| `loggerServiceProvider` | `Provider<LoggerService>` | (service) | The `LoggerService` itself, plain `Provider`, *not* `NotifierProvider` |
| `connectionNotifierProvider` | `Notifier<ConnectionStatus>` | connection | Socket connection state |
| `networkNotifierProvider` | `Notifier<NetworkStatus>` | network | OS network status |
| `syncStateNotifierProvider` | `Notifier<SyncState>` | sync state | Top-level sync state |
| `sidebarNotifierProvider` | `Notifier<SidebarState>` | sidebar | Sidebar collapse/expand |
| `offlineDictationNotifierProvider` | `Notifier<DictationState>` | dictation | On-device dictation |
| `derivedViewProviders` | `Provider<...>` (derived) | derived | Derived views (sorted sessions, etc.) |
| `appProviders` (barrel) | (re-exports) | (n/a) | Convenience re-exports |

## Immutable updates

Always use spread or `copyWith`:

```dart
// Add a session
state = {...state, session.id: session};

// Remove a session
state = {...state}..remove(session.id);

// Update one field
state = state.copyWith(theme: 'dark');
```

The `Settings` model is the one exception — it has mutable public fields (`var`, not `final`) and round-trips through `toJson()`/`fromJson()` in `updateSetting`. Nested config classes within `Settings` use `final` fields normally.

## The `_shared.dart` `unset` sentinel

For `copyWith` calls that need to distinguish "not provided" from `null`:

```dart
// lib/core/providers/_shared.dart
const Object unset = Object();
```

Some notifiers use this for `copyWith` methods on local state. It's a notifier convention, not a model convention. Don't propagate it to the data models.

## The standard screen subscription pattern

Screens subscribe to data changes via `sync.onDataChanged`. The standard pattern is in [Chapter 11](11-screen-subscription.md). The short version:

```dart
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

The `SyncSubscriptionMixin` ([Chapter 11](11-screen-subscription.md)) wraps this.

## Test overrides

In tests, you usually don't want the real notifier. Override it:

```dart
final container = ProviderContainer(overrides: [
  sessionsNotifierProvider.overrideWith(() => _FakeSessionsNotifier()),
]);
```

A fake notifier stubs `build()`, `loadFromSync()`, and `refreshFromSync()`. Always `container.dispose()` in `tearDown`.

## When to use `ref.read` vs `ref.watch`

- `ref.watch` — in `build` methods. Rebuilds when the provider changes.
- `ref.read` — in event handlers, in `initState`, in callbacks. Does not subscribe.
- `ref.listen` — for side-effects (e.g. show a snackbar when something happens).

The codebase uses `ref.watch` for state reads, `ref.read` for action calls. `ref.listen` is used sparingly, mostly in `main.dart` for top-level effects (e.g. show a dialog when auth fails).

## The `authStateNotifier` coordination

`AuthStateNotifier` is special. On every auth change, it calls `loadFromSync()` or `clear()` on **every other notifier**. This is the "everything reloads on login/logout" pattern. The implementation is at the bottom of `auth_state_notifier.dart`.

> **Why this matters:** if you add a new notifier, you must register it in `AuthStateNotifier` (or the auth flow won't refresh it on login). Search `auth_state_notifier.dart` for `loadFromSync` and `clear` to find the registration pattern.

## Provider scope

All providers are global (no `ProviderScope.autoDispose` defaults). The app is single-window on mobile. The only "scoped" providers are the few in `lib/features/*/` that wrap them with `Consumer`-level state. If you want auto-dispose, do it explicitly per-provider.

## What this is NOT

- Not `AsyncNotifier`. The app doesn't use `AsyncValue` for state. State is the resolved value; loading is implicit (empty list, etc.). There is a `derived_view_providers.dart` that does some derived computation.
- Not `StreamProvider`. Streams are accessed directly (`sync.onDataChanged.listen(...)`) or via the mixin.
- Not `FutureProvider`. The few `Future<void>` actions are in `chat_action_notifier`, which is a `Notifier<void>`.

## Files to read next

- `lib/core/providers/app_providers.dart` — the barrel
- `lib/core/providers/sessions_notifier.dart` — a representative state-bearing notifier
- `lib/core/providers/chat_action_notifier.dart` — a representative action dispatcher
- `lib/core/providers/auth_state_notifier.dart` — the coordinator
- `lib/core/providers/_shared.dart` — the `unset` sentinel
- `test/core/providers/` — the notifier tests

## Gotchas

- The barrel is short. If you add a notifier, decide whether to add it to the barrel.
- `AuthStateNotifier` is the coordinator. If you add a notifier, register it there.
- The `unset` sentinel is for *notifier* `copyWith`, not for *model* `copyWith`. The models don't use it.
- `Settings` is the one model with mutable public fields. Don't be surprised.
- `loggerServiceProvider` is a `Provider<LoggerService>`, not a `NotifierProvider<...>`. Different shape.
- `derived_view_providers.dart` provides derived state (sorted sessions, etc.). It composes other providers; it doesn't fetch.
- The codebase does not use `AsyncValue`. Don't introduce it without good reason.
- The codebase does not use `autoDispose` by default. Don't add it without thinking.
