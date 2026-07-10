# Architecture Review

**Date:** 2026-04-30 (refresh of 2026-03-13 review)
**Agent:** A1 — Architect & Tech Lead

## July 2026 implementation update

- Repository boundaries now exist for sessions, machines, settings, artifacts,
  messages, and workflows. Message and workflow actions depend on injectable
  interfaces; `Sync` remains their compatibility implementation during the
  incremental migration.
- Workflow refresh policy is scoped and stateful rather than walking every
  known session on each refresh.
- Chat message, activity/header, and composer invalidation are independently
  revisioned. Session replacement still takes the conservative full rebuild.
- `StuckAgentSentinel` observes off-screen thinking sessions and raises a
  one-shot actionable notification after a no-progress threshold.

---

## Current Architecture

Happy Flutter uses a **feature-based layered architecture** with Riverpod v3 for state management and a Sync singleton as the central data hub.

```
lib/
├── main.dart                    # App entry, theme wiring, AuthGate
├── core/
│   ├── api/                     # Dio HTTP clients, Socket.IO, per-domain API classes
│   ├── encryption/              # NaCl/libsodium (legacy) + AES-256-GCM (new)
│   ├── i18n/                    # Localization helpers
│   ├── models/                  # Manual fromJson/toJson/copyWith
│   ├── providers/               # Riverpod NotifierProviders (one file per notifier)
│   ├── routing/                 # GoRouter (~64 routes in app_router.dart)
│   ├── rpc/                     # RPC layer
│   ├── services/                # Auth, Sync (split across ~20 part files), Storage, push, TTS
│   ├── theme/                   # Design tokens (AppSpacing, AppRadius, AppFontSize, etc.)
│   ├── ui/                      # Low-level widgets
│   ├── components/              # High-level widgets
│   ├── widgets/                 # App-level widgets (ErrorBoundary, AuthGate)
│   └── utils/                   # InvalidateSync, SyncSubscriptionMixin, logging
└── features/
    ├── auth/                    # QR auth, device linking
    ├── changelog/               # In-app changelog
    ├── chat/                    # Chat screen, messages, tools, markdown
    ├── command_palette/         # Modal command search
    ├── dev/                     # Dev logs, encryption debug, network inspector
    ├── inbox/                   # Feed, friends, notifications
    ├── sessions/                # Session list, creation, pickers
    ├── settings/                # Settings screens
    ├── artifacts/               # Artifact management
    ├── machine/                 # Machine detail
    ├── sftp/                    # SFTP feature
    ├── terminal/                # Terminal features
    ├── user/                    # User profile
    └── zen/                     # Todo/zen mode
```

### Data Flow (Current)

```
Presentation (Widgets/Screens)
    ├── ref.watch(provider)                      ← preferred path
    ├── SyncSubscriptionMixin                    ← deduped sync subscriptions
    │     ├── subscribeToDataChanged(...)
    │     ├── subscribeToDomains([SyncDomain])   ← scoped invalidation
    │     └── subscribeToSessionMessagesChanged
    └── sync.sendMessage() / createSession()...  ← still present in chat + new_session
         ↓
Riverpod Providers (NotifierProvider)
    └── loadFromSync() / refreshFromSync()
         ↓
Sync Singleton (~1,000 LoC main file + ~20 _sync_*.dart part files)
    ├── API clients (Dio)
    ├── Storage (MMKV)
    ├── WebSocket (Socket.IO)
    └── Encryption (isolates)
```

---

## Critical Findings

### 1. Sync Singleton — Still a God, but Decomposed (HIGH, was CRITICAL)

`sync_service.dart` itself is now ~1,000 lines, but the class is split across ~20 `_sync_*.dart` part files (`_sync_messaging*`, `_sync_socket*`, `_sync_data*`, `_sync_lifecycle`, `_sync_operations*`, `_sync_health`, `_sync_isolate_helpers`, `_sync_test_helpers`, etc.). Concerns are visually separated but the runtime object is still one class managing sessions, messages, machines, artifacts, settings, profiles, friends, feed, todos, encryption, WebSocket, and API calls.

**Evidence:** API clients (`SessionsApi()`, `KvApi()`, `PushApi()`) are still constructed directly inside Sync. No DI / repository abstraction has been introduced yet.

**Status:** Decomposition into part files is good for navigation; runtime decomposition into focused managers (Phase 3 below) has not started.

### 2. Direct Widget-to-Sync Coupling (HIGH, was CRITICAL — improved)

Direct `sync.<method>()` calls from screens have been reduced. Current state:

| Screen | `sync.` references | Notes |
|--------|--------------------|-------|
| `chat_screen.dart` | ~14 | Down from 28+. Still the largest violator (`sendMessage`, `deleteSession`, `applySettings`, abort, etc.). |
| `new_session_screen.dart` | ~6 | `createSession`, `createWorktree`, `applySettings`. |
| Most other screens | 0 raw `sync.onDataChanged.listen` | Migrated to `SyncSubscriptionMixin` (see below). |

### 3. Business Logic in Presentation Layer (HIGH)

Screens still contain operations that belong in notifiers or use cases:
- `chat_screen.dart`: message send, abort, delete, settings application
- `new_session_screen.dart`: session creation + worktree workflow
- `artifact_detail_screen.dart`: artifact deletion

### 4. Repository Migration (MEDIUM, in progress)

Injectable repository interfaces now cover the main domains. Some repository
implementations still delegate to `Sync`, and API clients are still constructed
inside the sync/managers layer, so the runtime decomposition remains incomplete.

### 5. Manual Stream Subscriptions — Mostly Fixed (RESOLVED for non-chat)

Introduced `SyncSubscriptionMixin` in `lib/core/utils/sync_subscription_mixin.dart`. It centralizes:
- `subscribeToDataChanged(ref, cb)` — global stream with counter-based dedup
- `subscribeToDomains([SyncDomain.x, ...], cb)` — per-domain scoped subscriptions (newer API; reduces wakeups)
- `subscribeToSessionMessagesChanged(sessionId, cb)` — chat-only

10+ screens already use the mixin (sessions, inbox, machine_detail, machines settings, artifacts list/detail, zen home/new/view, session_debug). `ChatScreen` is still the documented exception because it manages paginated messages with local `setState`.

---

## Good Patterns (Preserve)

| Pattern | Location | Assessment |
|---------|----------|------------|
| GoRouter routing | `app_router.dart` | Centralized, named routes, clean transitions |
| Error boundary | `error_boundary.dart` | Proper error handling, Sentry chaining |
| Auth gate | `auth_gate.dart` | Clean auth/unauth separation |
| Theme management | `main.dart` | Settings-driven, system brightness aware |
| Provider triple-check | `sessions_notifier.dart` | Reference + content equality before state update |
| Design tokens | `app_tokens.dart` | Comprehensive spacing, radius, typography |

---

## Recommended Target Architecture

```
Presentation Layer (Widgets/Screens)
    └── ref.watch(provider)
         ↓
State Management Layer (Riverpod Notifiers)
    └── Uses repositories / use cases
         ↓
Domain Layer (Use Cases — optional for simple operations)
    └── Business rules, orchestration
         ↓
Repository Layer (Abstract interfaces)
    └── Coordinates local + remote data sources
         ↓
Data Layer
    ├── API clients (Dio, Socket.IO)
    ├── Local storage (MMKV)
    └── Encryption (isolates)
```

### Migration Path

1. **Phase 1 — Extract business logic from screens into notifiers** (P0, **partially done**)
   - Stream subscriptions: ✅ centralized via `SyncSubscriptionMixin` for non-chat screens. `subscribeToDomains` provides scoped invalidation.
   - Direct `sync.method()` calls: 🟡 reduced significantly across most features, but `chat_screen.dart` (~14) and `new_session_screen.dart` (~6) still call Sync directly. Move remaining `sync.sendMessage` / abort / delete / `createSession` / `createWorktree` calls behind `chatActionNotifierProvider` and `SessionsNotifier`.

2. **Phase 2 — Create repository interfaces** (P1, **substantially complete**)
   - `SessionsRepository`, `MachinesRepository`, `SettingsRepository`,
     `ArtifactsRepository`, `MessagesRepository`, and `WorkflowsRepository`
   - Providers are Riverpod-overridable; remaining work is removing legacy
     direct calls and moving concrete implementations fully out of `Sync`.

3. **Phase 3 — Break Sync into focused managers** (P2, **part-file decomposition only**)
   - Sync has been split into ~20 part files (textual decomposition); runtime is still one class.
   - Next step: extract part files into independent classes (`SessionManager`, `MessageManager`, `ArtifactManager`) that compose into Sync, each owning its state, API calls, and encryption.

4. **Phase 4 — Add use case layer for complex operations** (P3, **not started**)
   - `SendMessageUseCase`, `CreateSessionUseCase`
   - Only where orchestration across multiple repositories is needed
