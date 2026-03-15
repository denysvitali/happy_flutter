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
- Dio + NativeAdapter (Cronet on Android, cupertino_http on iOS) for HTTP
- Socket.IO for real-time updates
- MMKV for storage (SharedPreferences on web), FlutterSecureStorage for secrets
- NaCl/libsodium (legacy) + AES-256-GCM (new data) for encryption
- Sentry for error tracking
- Go Router v17 for navigation
- i18n via Flutter's built-in localization (`flutter: generate: true`)

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

**Build Flavors (Android only — iOS has no flavor separation):**
- `development` — appId `.dev` suffix
- `preview` — appId `.preview` suffix
- `production` — base appId

## Architecture

**Feature-Based Clean Architecture:**

```
lib/
├── main.dart              # App entry point
├── core/
│   ├── api/               # ApiClient (Dio), SocketIoClient, per-domain API classes
│   ├── encryption/        # NaCl (legacy), AES-256-GCM (new), key derivation
│   ├── i18n/              # Internationalization helpers
│   ├── models/            # Manual fromJson/toJson/copyWith (16 model files)
│   ├── providers/         # Riverpod NotifierProvider state (app_providers.dart barrel)
│   ├── routing/           # GoRouter setup (createRouter())
│   ├── rpc/               # RPC layer
│   ├── services/          # Auth, Sync, storage, logging, push, TTS, etc.
│   ├── theme/             # Colors, typography, design tokens
│   ├── ui/                # Lower-level widgets (avatars, tab_bar, shimmer, diff)
│   ├── components/        # Higher-level (AppCard, AppEmptyState, sidebar, settings)
│   ├── widgets/           # Additional shared widgets
│   └── utils/             # InvalidateSync, path/version/message utils, ANSI parser
└── features/
    ├── auth/              # QR auth, device linking, backup restore
    ├── chat/              # Chat screen, input, markdown, tool views, autocomplete
    ├── command_palette/   # Modal command search
    ├── dev/               # Dev logs, encryption debug, network inspector
    ├── inbox/             # Friends, friend search, inbox
    ├── sessions/          # Session list, new session, machine/path/profile pickers
    ├── settings/          # Theme, language, voice, features, profiles, usage, etc.
    ├── artifacts/         # Artifact list, detail, edit, create
    ├── machine/           # Machine detail
    ├── sftp/              # SFTP with own models/providers/screens
    ├── terminal/          # Terminal connect and screen
    ├── user/              # User profile
    └── zen/               # Zen home, new, view, priority
```

### State Management

**Riverpod v3 with manual NotifierProvider** — `@riverpod` code generation is NOT used. All notifiers extend `Notifier<T>`.

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
| `chatActionNotifierProvider` | `void` (pure action dispatcher) |
| `loggerNotifierProvider` | `LoggerState` (debounced, 200ms timer) |
| `loggerServiceProvider` | `LoggerService` (plain `Provider`, not `NotifierProvider`) |

**Notable:** `AuthStateNotifier` acts as a coordinator — on auth changes it calls `loadFromSync()`/`clear()` on all other providers.

**`_shared.dart`** contains an `unset` sentinel (`const Object()`) used in `copyWith` methods to distinguish "not provided" from `null`.

**Immutable updates:** Always use spread copies: `{...state, id: value}`, `[...state.list, item]`

### The Sync Singleton

Three top-level globals (each in their own file):

```dart
sync           // Sync singleton — lib/core/services/sync_service.dart
logger         // LoggerService — lib/core/services/logger_service.dart
socketIoClient // SocketIoClient — lib/core/api/socket_io_client.dart
```

**`Sync` is a true singleton** via `factory Sync() => _instance`. Calling `Sync()` always returns the same instance.

**Provider bridge pattern:** Screens subscribe to `sync.onDataChanged` (debounced 100ms) and call:
- `provider.notifier.loadFromSync()` — reads in-memory state (instant)
- `provider.notifier.refreshFromSync()` — server fetch, then reads

Guard on `sync.isInitialized` — `loadFromSync()` is a no-op when `false`. Note: `sync.isReady` is separate (set after sessions+machines resolve).

**InvalidateSync fields (13 total):** `sessionsSync`, `settingsSync`, `profileSync`, `purchasesSync`, `machinesSync`, `pushTokenSync`, `nativeUpdateSync`, `artifactsSync`, `friendsSync`, `friendRequestsSync`, `feedSync`, `todosSync`, `sessionGitStatusSync`. Note: `messagesSync` is a `Map<String, InvalidateSync>` (per-session).

See @docs/SYNC_PATTERNS.md for subscription template and details.

### Navigation

Routes defined in `lib/core/routing/app_router.dart` (not `main.dart`). ~40 flat `GoRoute` entries. Use named routes:

```dart
context.goNamed('chat', pathParameters: {'sessionId': id});
```

For non-URL data (e.g., `message-detail`), pass `Map<String, dynamic>` via `state.extra`.

**Page transitions:**
- `_fadePage` — top-level tab destinations
- `_slideUpPage` — creation/modal flows
- `_slidePage` — detail screens with iOS-style swipe-back on all platforms

**`SessionsScreen`** is a stateful tab shell rendering `InboxScreen` and `SettingsScreen` inline (not via GoRouter's `ShellRoute`).

**Auth gating:** Every route wraps its child in `AuthGate`. The router only redirects `/` → `/sessions` for authenticated users.

### Key Services

| Service | Pattern | Purpose |
|---------|---------|---------|
| `ApiClient` | Singleton | Dio + NativeAdapter; `validateStatus: (_) => true` — check status manually. Timeouts: connect 30s, receive 60s, send 30s |
| `SocketIoClient` | Singleton | Socket.IO on `/v1/updates`, `['websocket']` only, reconnect 1–5s |
| `AuthService` | Singleton | QR auth, Ed25519 signatures, NaCl box encryption. No separate `AuthApi` |
| `LoggerService` | Singleton | 5000-entry circular `Queue`, ANSI color output in debug, Sentry forwarding |

**Service/API duality is partial:** Some domains have both `XxxService` (production) and `XxxApi` (injectable for tests) — e.g., `KvService`/`KvApi`, `UsageService`/`UsageApi`. Others have only one or the other. `XxxApi` classes accept optional `ApiClient? client` for test injection.

### Storage

Multiple storage singletons, each backed by different engines:

| Class | Backend | Purpose |
|-------|---------|---------|
| `MMKVStorage` | MMKV (native) / SharedPreferences (web) | Settings, drafts, permission modes, sessions cache |
| `ServerConfigStorage` | MMKV `'server-config'` instance | Custom server URL (persists across logouts) |
| `TokenStorage` | FlutterSecureStorage | JWT and auth keys |
| `APIKeyStorage` | FlutterSecureStorage | Per-profile API keys (OpenAI, Azure, etc.) |
| `Storage` | Composes all above | Top-level singleton; `Storage().initialize()` inits all |

**Migrations:** SharedPreferences → MMKV migration runs once on first init. API keys migration from MMKV settings blob → FlutterSecureStorage runs once on first `getSettings()`.

## Models

**Manual `fromJson`/`toJson`/`copyWith`** — no `json_serializable` or `freezed`. Timestamps are integers (milliseconds), not `DateTime`.

**Exception:** `Settings` uses mutable public fields (`var`, not `final`) and roundtrips through `toJson()`/`fromJson()` in `updateSetting`. Nested config classes within Settings use `final` fields normally.

**`Session.presence`** is always a `String` (`'online'` or `'offline'`), never `null`. Absence on wire maps to `'offline'`.

**`WireParsers`** utility handles lenient type coercion for JSON fields (numbers vs numeric strings from different backends).

## UI Conventions

**Design tokens** from `lib/core/theme/app_tokens.dart`:

| Token Class | Values |
|-------------|--------|
| `AppSpacing` | `xxs`=2, `xs`=4, `sm`=8, `smd`=10, `md`=12, `lg`=16, `xl`=20, `xxl`=24, `xxxl`=32 |
| `AppRadius` | `xs`=4, `sm`=8, `md`=12, `lg`=16, `xl`=20, `pill`=100 |
| `AppFontSize` | `xxs`=10, `xs`=11, `sm`=12, `md`=13, `base`=14, `lg`=16 |
| `AppDuration` | `fast`=150ms, `normal`=250ms, `slow`=350ms, `slower`=500ms |
| `AppTouchTarget` | `min`=44, `comfortable`=48 |
| `AppBreakpoint` | `tablet`=600, `desktop`=960 |
| `AppScreenPadding` | `standard`, `compact`, `settings`, `listItem` (pre-composed `EdgeInsets`) |

Also: `AppLineHeight`, `AppCurve`, `AppElevation`, `AppShadow`, `AppBorder`.

**Widget layers:**
- `lib/core/components/` — higher-level (AppCard, AppEmptyState, sidebar, settings sections)
- `lib/core/ui/` — lower-level (avatars, tab_bar, shimmer, diff, status_bar)
- `lib/core/widgets/` — additional shared widgets

**IMPORTANT — `hide TabBar`:** When importing custom `TabBar` from `lib/core/ui/tab_bar/tab_bar.dart`:

```dart
import 'package:flutter/material.dart' hide TabBar;
```

**Screen types:**
- `ConsumerStatefulWidget` + `ConsumerState` — screens with local state or sync subscriptions (majority)
- `ConsumerWidget` — stateless read-only screens

## Testing

**No integration tests** — only unit and widget tests.

**Global test config:** `test/flutter_test_config.dart` runs before every test file — calls `TestWidgetsFlutterBinding.ensureInitialized()`, disables Google Fonts runtime fetching, loads Roboto Mono for golden screenshots.

**Provider tests:** Use `ProviderContainer` directly. Always `container.dispose()` in `tearDown`.

**Storage overrides:** `SettingsNotifier.updateSetting` touches MMKV. Use overrides in tests:

```dart
ProviderContainer(overrides: [
  settingsNotifierProvider.overrideWith(() => _StorageFreeSettingsNotifier()),
])
```

**MMKV stubbing in widget tests:** When a widget indirectly touches MMKV, register a `_FakeMMKVPlatform` on `MMKVPluginPlatform.instance` before widget creation.

**Sync tests:** `Sync()` returns the singleton — set all InvalidateSync fields before calling `handleUpdate`. Use `createTestSync()` from `test/helpers/test_helpers.dart`.

**Mock HTTP responses:** Always include `requestOptions: RequestOptions(path: '')`. Use `mockResponse<T>()` helper from `test/helpers/test_helpers.dart`.

**API tests:** Use `mockito` with generated `.mocks.dart` files adjacent to each test file.

**Widget tests:** Wrap in `ProviderScope(overrides: [...])` inside `MaterialApp`. Stub notifiers override `build()`, `loadFromSync()`, and `refreshFromSync()`.

**Test helpers** in `test/helpers/test_helpers.dart`: `createTestSync()`, `mockResponse<T>()`.

### Golden Screenshots

Golden screenshots in `test/golden/goldens/` are **showcase images** used in the README and to track visual regressions. They **must always be kept up-to-date** when the UI changes.

**After any UI change that affects visual output**, run:

```bash
devenv shell -- flutter test test/golden/golden_test.dart --update-goldens
```

Then commit the updated PNGs. Do not leave stale goldens — they will cause false test failures for other contributors.

**Git LFS:** Golden PNGs are tracked via Git LFS (see `.gitattributes`). Contributors must have `git-lfs` installed (`git lfs install`). The golden test file is `test/golden/golden_test.dart`.

**Viewport:** Phone viewport set via `tester.view.physicalSize = Size(390*2, 844*2)` with `devicePixelRatio = 2.0`.

## Coding Standards

- **Strict typing:** `implicit-casts: false`, `implicit-dynamic: false`
- **Line length:** 80 characters max
- **CI-blocking errors:** `missing_required_param`, `missing_return`, `must_be_immutable`
- **Linter:** extends `package:flutter_lints/flutter.yaml` with ~90 additional rules
- **Prefer:** const constructors, final fields, single quotes, spread collections
- **Avoid:** `print` — use `logger.info/warning/error()`; `unawaited()` for fire-and-forget
- **Platform code:** Conditional exports for native vs web: `platform_io.dart`/`platform_stub.dart`, `mmkv_storage_native.dart`/`mmkv_storage_web.dart`, `sodium_loader_native.dart`/`sodium_loader_web.dart`, `sentry_*.dart`, `security_context_*.dart`, `user_certs_*.dart`

**Analysis:** `test/**/*.dart` excluded from analysis. CI runs `flutter analyze --no-fatal-infos --no-fatal-warnings` (only errors block build).

**CI pipeline** (`ci.yml`): 4 jobs — `analyze`, `test`, `build-debug`, `build-release`. Flutter 3.38.7, Java 17, NDK 28.2.13676358. Caches pub-cache and Gradle. Release builds use obfuscation + split-debug-info, create GitHub Releases on `v*` tags.

## Dependency Overrides

`pubspec.yaml` has `dependency_overrides` for compatibility with Flutter 3.38.7:
- `shared_preferences_android: 2.4.20` (2.4.18 and 2.4.21 lack `SharedPreferencesPlugin`)
- `sodium_libs: 3.4.6+3`

## Additional Documentation

- Sync patterns: @docs/SYNC_PATTERNS.md
- Feature parity: @ROADMAP.md
- Architecture docs: `docs/` directory (15+ internal docs)
