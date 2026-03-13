# Architecture Review

**Date:** 2026-03-13
**Agent:** A1 — Architect & Tech Lead

---

## Current Architecture

Happy Flutter uses a **feature-based layered architecture** with Riverpod v3 for state management and a Sync singleton as the central data hub.

```
lib/
├── main.dart                    # App entry, GoRouter routes
├── core/
│   ├── api/                     # Dio HTTP clients, Socket.IO
│   ├── encryption/              # NaCl + AES-256-GCM crypto
│   ├── models/                  # Manual fromJson/toJson/copyWith
│   ├── providers/               # Riverpod NotifierProviders
│   ├── services/                # Auth, Sync, Storage singletons
│   ├── routing/                 # GoRouter configuration
│   ├── theme/                   # Design tokens (AppSpacing, AppRadius)
│   ├── ui/                      # Low-level widgets
│   ├── components/              # High-level widgets
│   ├── widgets/                 # App-level widgets (ErrorBoundary, AuthGate)
│   └── utils/                   # InvalidateSync, logging
└── features/
    ├── auth/                    # QR auth, device linking
    ├── chat/                    # Chat screen, messages, tools, markdown
    ├── sessions/                # Session list, creation, management
    ├── settings/                # Settings screens
    ├── inbox/                   # Feed, friends, notifications
    ├── artifacts/               # Artifact management
    ├── machine/                 # Machine management
    ├── zen/                     # Zen mode
    └── terminal/                # Terminal features
```

### Data Flow (Current)

```
Presentation (Widgets/Screens)
    ├── ref.watch(provider)          ← Riverpod providers
    ├── sync.sendMessage()           ← Direct sync calls (VIOLATION)
    └── sync.onDataChanged.listen()  ← Manual stream subs (VIOLATION)
         ↓
Riverpod Providers (NotifierProvider)
    └── loadFromSync() / refreshFromSync()
         ↓
Sync Singleton (3,700 lines — god object)
    ├── API clients (Dio)
    ├── Storage (MMKV)
    ├── WebSocket (Socket.IO)
    └── Encryption (isolates)
```

---

## Critical Findings

### 1. Sync Singleton — God Object (CRITICAL)

`sync_service.dart` is 3,700+ lines managing sessions, messages, machines, artifacts, settings, profiles, friends, feed, todos, encryption, WebSocket, and API calls. This violates single-responsibility and makes testing extremely difficult.

**Evidence:** The Sync class directly instantiates API clients (`SessionsApi()`, `KvApi()`, `PushApi()`) with no dependency injection or repository abstraction.

### 2. Direct Widget-to-Sync Coupling (CRITICAL)

Screens bypass the Riverpod layer and call sync methods directly:

| Screen | Direct Sync Calls |
|--------|-------------------|
| `chat_screen.dart` | 28+ calls (sendMessage, deleteSession, applySettings, etc.) |
| `new_session_screen.dart` | 3 calls (createSession, createWorktree, applySettings) |
| `artifacts_list_screen.dart` | Stream subscription to `sync.onDataChanged` |
| `sessions_screen.dart` | Stream subscription to `sync.onDataChanged` |

### 3. Business Logic in Presentation Layer (CRITICAL)

Screens contain operations that belong in notifiers or use cases:
- `chat_screen.dart`: Message sending, session aborting, settings application
- `new_session_screen.dart`: Session creation workflow, worktree creation
- `artifact_detail_screen.dart`: Artifact deletion

### 4. Missing Repository Pattern (HIGH)

No abstraction layer exists between notifiers/sync and API clients. APIs are instantiated directly throughout `sync_service.dart`.

### 5. Manual Stream Subscriptions (HIGH)

Screens subscribe to `sync.onDataChanged` in `initState()` instead of using `ref.watch()`. This requires manual `dispose()` cleanup and creates coupling.

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

1. **Phase 1 — Extract business logic from screens into notifiers** (P0)
   - Move `sync.sendMessage()` calls to `ChatNotifier`
   - Move `sync.createSession()` to `SessionsNotifier`
   - Replace `sync.onDataChanged.listen()` with `ref.watch()`

2. **Phase 2 — Create repository interfaces** (P1)
   - `SessionsRepository`, `MessagesRepository`, `ArtifactsRepository`
   - Inject via Riverpod provider overrides for testing

3. **Phase 3 — Break Sync into focused managers** (P2)
   - `SessionManager`, `MessageManager`, `ArtifactManager`
   - Each manages its own state, API calls, and encryption
   - Reduces god object from 3,700 lines to focused modules

4. **Phase 4 — Add use case layer for complex operations** (P3)
   - `SendMessageUseCase`, `CreateSessionUseCase`
   - Only where orchestration across multiple repositories is needed
