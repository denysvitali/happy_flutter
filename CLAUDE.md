# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Happy Flutter is a **reimplementation of happy's mobile app** (React Native) located at `../happy`. The goal is to achieve full feature parity with the original React Native implementation.

**Flutter Version**: 3.38.7 (Dart 3.10+) — pinned via devenv (see `.fvmrc`, `devenv.nix`)

**Source of Truth**: See `ROADMAP.md` for feature parity tracking against the React Native app at `../happy`.

## Common Commands

Flutter is **not on PATH directly** — all commands must be run via devenv:

```bash
# Get dependencies
devenv shell -- flutter pub get

# Analyze code (errors block CI; warnings/infos do not)
devenv shell -- flutter analyze

# Run all tests
devenv shell -- flutter test

# Run a specific test file
devenv shell -- flutter test test/services/sync_service_test.dart

# Regenerate mockito mocks (after modifying API classes used in tests)
devenv shell -- flutter pub run build_runner build

# Build APK (flavors: development, preview, production)
devenv shell -- flutter build apk --debug --flavor development
devenv shell -- flutter build apk --release --flavor production
```

## Architecture

**Feature-Based Clean Architecture:**

```
lib/
├── main.dart                    # App entry, router (GoRouter), all route definitions
├── core/
│   ├── api/                     # ApiClient (Dio+NativeAdapter), SocketIoClient, feature API classes
│   ├── encryption/              # NaCl crypto, session/machine/artifact encryption, key caching
│   ├── models/                  # Pure Dart models with manual fromJson/toJson/copyWith
│   ├── providers/               # Riverpod NotifierProvider state (all in app_providers.dart)
│   ├── services/                # Auth, sync (Sync singleton), storage, certificates
│   ├── theme/                   # app_tokens.dart: AppSpacing, AppRadius design tokens
│   ├── ui/                      # Lower-level shared widgets (avatars, tab_bar, shimmer, diff, sidebar)
│   ├── components/              # Higher-level shared components (AppCard, AppEmptyState, etc.)
│   └── utils/                   # InvalidateSync, logging, helpers
└── features/
    ├── auth/                    # Landing + QR authentication
    ├── chat/                    # Chat interface with message pagination
    ├── sessions/                # Session list (also embeds Inbox + Settings as inline tabs)
    ├── settings/                # App settings
    ├── inbox/                   # Notifications inbox
    ├── artifacts/               # Artifacts browser
    ├── machine/                 # Machine management
    ├── zen/                     # Todo/zen mode
    └── terminal/                # Terminal feature
```

## State Management

**Riverpod v3 with manual `NotifierProvider`** — `riverpod_annotation` is a dependency but `@riverpod` code generation is **not used**. All providers are manually declared in `lib/core/providers/app_providers.dart`.

| Provider | State |
|----------|-------|
| `authStateNotifierProvider` | `AuthState` |
| `sessionsNotifierProvider` | `Map<String, Session>` |
| `machinesNotifierProvider` | `Map<String, Machine>` |
| `settingsNotifierProvider` | `Settings` |
| `connectionNotifierProvider` | `ConnectionStatus` |
| `currentSessionNotifierProvider` | `Session?` |
| `profileNotifierProvider` | `Profile?` |
| `sessionGitStatusProvider` | `Map<String, GitStatus>` |
| `artifactsNotifierProvider` | `Map<String, Artifact>` |
| `friendsNotifierProvider` | `FriendsState` |
| `feedNotifierProvider` | `FeedState` |
| `todoStateNotifierProvider` | `TodoListState` |

**Immutable state updates**: always use spread copies (`{...state, id: value}`, `[...state.list, item]`).

## The Sync Singleton

`lib/core/services/sync_service.dart` — `Sync` is the **central in-memory data hub**. Three top-level globals are the canonical access points throughout the codebase:

```dart
sync          // Sync singleton — central data hub (sync_service.dart:3062)
logger        // LoggerService — 5000-entry circular buffer (logger_service.dart:217)
socketIoClient  // SocketIoClient — Socket.IO transport (socket_io_client.dart:242)
```

The `Sync` singleton:
- Holds all server state: sessions, machines, messages, profile, friends, feed, artifacts, todos
- Exposes `Stream<void> onDataChanged` and `Stream<String> onSessionMessagesChanged`
- Each data type has an `InvalidateSync` for debounced server fetches with exponential backoff (1s–5s, max 5 retries)
- `sync.create()` — full init for new login; awaits settings/profile before returning
- `sync.restore()` — restore on app restart; does NOT await settings/profile

**Provider bridge pattern**: Screens subscribe to `sync.onDataChanged` and call:
- `provider.notifier.loadFromSync()` — reads Sync in-memory state (instant, no network)
- `provider.notifier.refreshFromSync()` — triggers server fetch first, then reads

**Standard screen subscription template:**
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

Always guard on `sync.isInitialized` — `loadFromSync()` is a no-op when `false`.

## Navigation

All routes are defined in `main.dart` in `_buildRouter()`. `AuthGate` wraps every route child, redirecting unauthenticated users to `/`. Use named routes:

```dart
context.goNamed('chat', pathParameters: {'sessionId': id});
```

For routes that carry non-URL data (e.g., `message-detail`, `agent-conversation`), pass `Map<String, dynamic>` via `state.extra`.

**`SessionsScreen` is a tab shell** — it renders `InboxScreen` and `SettingsScreen` inline via its own tab bar. The `/inbox` and `/settings` routes are used only for direct deep-link navigation, not from the tab bar.

## Key Services

| Service | Pattern | Purpose |
|---------|---------|---------|
| `ApiClient` | Singleton | Dio + NativeAdapter (Cronet/cupertino_http). `validateStatus: (_) => true` — callers must check status manually |
| `SocketIoClient` | Singleton | Socket.IO on path `/v1/updates`, transport `['websocket']` only (no polling fallback) |
| `AuthService` | Singleton | QR authentication, Ed25519 signatures |
| `EncryptionService` | — | Thin shim over `Encryption`; `Sync` holds its own `Encryption` instance separately |
| `storage.Storage` | Singleton | MMKV (migrated from SharedPreferences) |

**Service/API duality**: every feature domain has both a `XxxService` singleton (production code) and an injectable `XxxApi` class (accepts `ApiClient?`, used in tests). `sync_service.dart` calls `ApiClient()` directly for some endpoints, bypassing both.

**Two MMKV instances**:
- Default (`MMKV.defaultMMKV()`) — user data, cleared on logout
- `MMKV('server-config')` — server URL, survives `Storage.clearAll()`

**Server URL priority**: user-stored custom URL (MMKV) → `--dart-define=HAPPY_SERVER_URL=<url>` → `https://api.cluster-fluster.com`

`WebSocketClient` in `websocket_client.dart` is legacy/unused — `SocketIoClient` is the real transport.

## Models

All models use **manual `fromJson`/`toJson`/`copyWith`** — no `json_serializable` or `freezed`. Timestamps are integers (milliseconds since epoch), not `DateTime`.

**Exception**: `Settings` uses mutable public fields (not `final`) and roundtrips through `toJson()`/`fromJson()` in `updateSetting` instead of a `copyWith`.

**`Session.presence`** is always a `String` after deserialization (`'online'` or `'offline'`), never `null`. Absence on the wire maps to `'offline'`.

Artifacts can't be filtered by `sessionId` without decryption — `sessionId` is in the encrypted header, not the wire model.

## UI Conventions

**Design tokens** — use these instead of literal pixel values:
- `AppSpacing.xs/sm/md/lg/xl/xxl/xxxl` (4/8/12/16/20/24/32 px)
- `AppRadius.xs/sm/md/lg/xl/pill` (4/8/12/16/20/100 px)
- Defined in `lib/core/theme/app_tokens.dart`

**Component sets**:
- `lib/core/components/` — higher-level, barrel-exported: `AppCard`, `AppEmptyState`, `AppLoadingIndicator`, `AppSectionHeader`, `AppStatusDot`, `AppTappable`
- `lib/core/ui/` — lower-level specialized: avatars, shimmer, diff, sidebar, tab_bar, status_bar

**IMPORTANT — `hide TabBar`**: Any file that imports the custom `TabBar` from `lib/core/ui/tab_bar/tab_bar.dart` must hide Flutter's built-in one:
```dart
import 'package:flutter/material.dart' hide TabBar;
```
Forgetting this produces a confusing "ambiguous import" compile error.

**Screen widget type**:
- `ConsumerStatefulWidget` + `ConsumerState` — when the screen needs local state and Riverpod
- `ConsumerWidget` — stateless screens that only read providers

**i18n**: `context.l10n` extension (or `AppLocalizations.of(context)`) — currently a handwritten stub with hardcoded English strings in `lib/core/i18n/app_localizations.dart`. `l10n.yaml` points to `/l10n/*.arb` at the repo root; the generator is configured but not yet wired up.

## Testing

**No integration tests** — only unit tests and a few widget tests.

**Provider tests** use `ProviderContainer` directly (no widget tree). Always `container.dispose()` in `tearDown`.

**Override storage-touching notifiers** — `SettingsNotifier.updateSetting` touches MMKV and will fail without a platform channel. Use an override:
```dart
ProviderContainer(overrides: [
  settingsNotifierProvider.overrideWith(() => _StorageFreeSettingsNotifier()),
])
```

**Sync tests**: `Sync` can be `new`-ed in tests, but all `InvalidateSync` fields must be manually set before calling `handleUpdate`:
```dart
instance.sessionsSync = InvalidateSync(() async {});
instance.settingsSync = InvalidateSync(() async {});
// ... all fields, see sync_service_test.dart setUp block
```

**Widget tests**: call `TestWidgetsFlutterBinding.ensureInitialized()` at the top of `main()`. When constructing a `Response` in mock stubs, always include `requestOptions: RequestOptions(path: '')` (Dio requires it).

**Mock generation**: Only `ApiClient` is mocked via `@GenerateMocks`. Each of the 5 API test files generates its own `*.mocks.dart`. After changing `ApiClient`'s public API, regenerate all:
```bash
devenv shell -- flutter pub run build_runner build
```

## Coding Standards

- **Strict typing**: `implicit-casts: false`, `implicit-dynamic: false`
- **Line length**: 80 characters max
- **Errors** (CI-blocking): `missing_required_param`, `missing_return`, `must_be_immutable`
- **Prefer**: const constructors, final fields, single quotes, spread collections
- **Avoid**: `print` statements — use `logger.info/warning/error()`; `unawaited()` for intentional fire-and-forget
- Analysis excludes `test/**/*.dart` — tests do not need to pass `flutter analyze`
- CI: `flutter analyze --no-fatal-infos --no-fatal-warnings` (only errors block the build)

## Security

- End-to-end encryption via NaCl/libsodium (`sodium` package); new session/machine data must use AES-256-GCM (`AES256Encryption`), not the legacy NaCl secretbox
- Ed25519 authentication signatures (`ed25519_edwards`)
- Certificate pinning note: `CertificateProvider` is currently a stub returning `null`; pinning relies on the platform CA store via `NativeAdapter`
- Credentials in `flutter_secure_storage`; app data in MMKV
- Web build is **disabled** — `sodium` and `mmkv` are not web-compatible
