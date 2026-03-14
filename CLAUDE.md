# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Rules

- **Always commit and push** after completing changes — do not wait for the user to ask
- **Always use `rg` (ripgrep)** when searching for code, symbols, or strings
- **Never create documentation files** (*.md, README updates) unless explicitly requested

## Project Overview

Happy Flutter is a **reimplementation of happy's mobile app** (React Native → Flutter).

**Tech Stack:**
- Flutter 3.38.7, Dart 3.10+
- Riverpod v3 (manual NotifierProvider, no code generation)
- Dio + NativeAdapter for HTTP
- Socket.IO for real-time updates
- MMKV for storage, NaCl/libsodium for encryption

**Environment:** This project uses [devenv](https://devenv.sh/) to pin Flutter. Run all commands via `devenv shell -- flutter <cmd>`.

**Source of Truth:** See `ROADMAP.md` for feature parity tracking.

## Common Commands

```bash
# Dependencies
devenv shell -- flutter pub get

# Analysis (errors block CI; warnings/infos do not)
devenv shell -- flutter analyze

# Testing
devenv shell -- flutter test
devenv shell -- flutter test test/services/sync_service_test.dart

# Golden screenshots — update after UI changes
devenv shell -- flutter test test/golden/golden_test.dart --update-goldens

# Code generation (after changing ApiClient public API)
devenv shell -- flutter pub run build_runner build

# Build APK (flavors: development, preview, production)
devenv shell -- flutter build apk --debug --flavor development
devenv shell -- flutter build apk --release --flavor production

# Run on device/emulator
devenv shell -- flutter run
```

**Build Flavors:** `development` (localhost), `preview` (staging), `production` (api.cluster-fluster.com)

## Architecture

**Feature-Based Clean Architecture:**

```
lib/
├── main.dart              # App entry, GoRouter, all routes
├── core/
│   ├── api/               # ApiClient (Dio), SocketIoClient, feature APIs
│   ├── encryption/        # NaCl crypto, AES-256-GCM for new data
│   ├── models/            # Manual fromJson/toJson/copyWith
│   ├── providers/         # Riverpod NotifierProvider state
│   ├── services/          # Auth, Sync singleton, storage
│   ├── theme/             # AppSpacing, AppRadius design tokens
│   ├── ui/                # Lower-level widgets (avatars, tab_bar, shimmer)
│   ├── components/        # Higher-level (AppCard, AppEmptyState)
│   └── utils/             # InvalidateSync, logging
└── features/
    ├── auth/, chat/, sessions/, settings/
    ├── inbox/, artifacts/, machine/, zen/, terminal/
```

### State Management

**Riverpod v3 with manual NotifierProvider** — `@riverpod` code generation is NOT used.

| Provider | State Type |
|----------|------------|
| `authStateNotifierProvider` | `AuthState` |
| `sessionsNotifierProvider` | `Map<String, Session>` |
| `machinesNotifierProvider` | `Map<String, Machine>` |
| `settingsNotifierProvider` | `Settings` |
| `connectionNotifierProvider` | `ConnectionStatus` |
| `currentSessionNotifierProvider` | `Session?` |
| `profileNotifierProvider` | `Profile?` |
| `artifactsNotifierProvider` | `Map<String, DecryptedArtifact>` |
| `friendsNotifierProvider` | `FriendsState` |
| `feedNotifierProvider` | `FeedState` |
| `todoStateNotifierProvider` | `TodoListState` |
| `sessionGitStatusNotifierProvider` | `Map<String, GitStatus>` |

**Immutable updates:** Always use spread copies: `{...state, id: value}`, `[...state.list, item]`

### The Sync Singleton

Three top-level globals in `sync_service.dart`:

```dart
sync           // Sync singleton — central data hub
logger         // LoggerService — 5000-entry circular buffer
socketIoClient // Socket.IO transport
```

**Provider bridge pattern:** Screens subscribe to `sync.onDataChanged` and call:
- `provider.notifier.loadFromSync()` — reads in-memory state (instant)
- `provider.notifier.refreshFromSync()` — server fetch, then reads

Guard on `sync.isInitialized` — `loadFromSync()` is a no-op when `false`.

See @docs/SYNC_PATTERNS.md for subscription template and details.

### Navigation

All routes defined in `main.dart`. Use named routes:

```dart
context.goNamed('chat', pathParameters: {'sessionId': id});
```

For non-URL data (e.g., `message-detail`), pass `Map<String, dynamic>` via `state.extra`.

**Note:** `SessionsScreen` is a tab shell rendering `InboxScreen` and `SettingsScreen` inline.

### Key Services

| Service | Pattern | Purpose |
|---------|---------|---------|
| `ApiClient` | Singleton | Dio + NativeAdapter; `validateStatus: (_) => true` — check status manually |
| `SocketIoClient` | Singleton | Socket.IO on `/v1/updates`, `['websocket']` only |
| `AuthService` | Singleton | QR authentication, Ed25519 signatures |
| `storage.Storage` | Singleton | MMKV (default + 'server-config' instances) |

**Service/API duality:** Each domain has a `XxxService` singleton (production) and injectable `XxxApi` class (tests).

## Models

**Manual `fromJson`/`toJson`/`copyWith`** — no `json_serializable` or `freezed`. Timestamps are integers (milliseconds), not `DateTime`.

**Exception:** `Settings` uses mutable public fields and roundtrips through `toJson()`/`fromJson()` in `updateSetting`.

**`Session.presence`** is always a `String` (`'online'` or `'offline'`), never `null`. Absence on wire maps to `'offline'`.

## UI Conventions

**Design tokens** from `lib/core/theme/app_tokens.dart`:
- `AppSpacing.xs/sm/md/lg/xl/xxl/xxxl` (4/8/12/16/20/24/32 px)
- `AppRadius.xs/sm/md/lg/xl/pill` (4/8/12/16/20/100 px)

**Component sets:**
- `lib/core/components/` — higher-level (AppCard, AppEmptyState, AppLoadingIndicator)
- `lib/core/ui/` — lower-level (avatars, tab_bar, shimmer, diff, sidebar)

**IMPORTANT — `hide TabBar`:** When importing custom `TabBar` from `lib/core/ui/tab_bar/tab_bar.dart`:

```dart
import 'package:flutter/material.dart' hide TabBar;
```

**Screen types:**
- `ConsumerStatefulWidget` + `ConsumerState` — screens with local state
- `ConsumerWidget` — stateless screens

## Testing

**No integration tests** — only unit and widget tests.

**Provider tests:** Use `ProviderContainer` directly. Always `container.dispose()` in `tearDown`.

**Storage overrides:** `SettingsNotifier.updateSetting` touches MMKV. Use overrides in tests:

```dart
ProviderContainer(overrides: [
  settingsNotifierProvider.overrideWith(() => _StorageFreeSettingsNotifier()),
])
```

**Sync tests:** `Sync` can be `new`-ed in tests, but set all `InvalidateSync` fields before calling `handleUpdate`.

**Widget tests:** Call `TestWidgetsFlutterBinding.ensureInitialized()` at top of `main()`. Include `requestOptions: RequestOptions(path: '')` in mock `Response` objects.

### Golden Screenshots

Golden screenshots in `test/golden/goldens/` are **showcase images** used in the README and to track visual regressions. They **must always be kept up-to-date** when the UI changes.

**After any UI change that affects visual output**, run:

```bash
devenv shell -- flutter test test/golden/golden_test.dart --update-goldens
```

Then commit the updated PNGs. Do not leave stale goldens — they will cause false test failures for other contributors.

**Git LFS:** Golden PNGs are tracked via Git LFS (see `.gitattributes`). Contributors must have `git-lfs` installed (`git lfs install`). The golden test file is `test/golden/golden_test.dart`.

## Coding Standards

- **Strict typing:** `implicit-casts: false`, `implicit-dynamic: false`
- **Line length:** 80 characters max
- **CI-blocking errors:** `missing_required_param`, `missing_return`, `must_be_immutable`
- **Prefer:** const constructors, final fields, single quotes, spread collections
- **Avoid:** `print` — use `logger.info/warning/error()`; `unawaited()` for fire-and-forget
- **Web build disabled** — `sodium` and `mmkv` are not web-compatible
- **Platform code:** `lib/platform_io.dart` (native) / `lib/platform_stub.dart` (stubs) via conditional exports

**Analysis:** `test/**/*.dart` excluded. CI runs `flutter analyze --no-fatal-infos --no-fatal-warnings` (only errors block build).

## Additional Documentation

- Sync patterns: @docs/SYNC_PATTERNS.md
- Feature parity: @ROADMAP.md
