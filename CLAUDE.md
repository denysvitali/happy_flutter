# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Rules

- **Always commit and push** after completing changes — do not wait for the user to ask
- **Use conventional commits** — prefix messages with `feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`, etc.
- **Check CI status** after pushing using GitHub Actions MCP tools — aim for green CI
- **Always use `rg` (ripgrep)** when searching for code, symbols, or strings
- **Never create documentation files** (*.md, README updates) unless explicitly requested
- **Treat chat send reliability as a P0 surface** — preserve one canonical `localId` across optimistic UI, REST send, retry, socket forwarding, and merge
- **When touching core messaging code, add or update contract tests first** — repeated identical sends, optimistic replacement, retry identity, and out-of-order delivery are mandatory coverage
- **This app wraps Claude Code** — happy_flutter is a Flutter mobile client for Claude Code sessions. When the user references "Read", "Write", "Bash", "tool output", "ReadFile", agent tool names, or anything that sounds like the Claude Code agent or CLI itself, they mean the **happy_flutter app's rendering / interaction with that tool**, not the Claude Code harness. Debug Flutter widgets, screens, models, providers, and Sync code — never reach for Claude Code internals.

## Production Issues / GlitchTip

- **Use GlitchTip for app issue checks** when asked about app crashes,
  production errors, regressions, or latest issues.
- **Scope:** organization `default`, project `happy_flutter`.
- If GlitchTip tools are not loaded, run `tool_search` for
  `glitchtip latest issues`.
- To list active app issues:

```text
mcp__glitchtip__.list_issues(
  organization_slug: "default",
  project_slug: "happy_flutter",
  query: "is:unresolved",
  sort: "-last_seen",
  limit: 15
)
```

- To list latest events including resolved issues, omit `query`:

```text
mcp__glitchtip__.list_issues(
  organization_slug: "default",
  project_slug: "happy_flutter",
  sort: "-last_seen",
  limit: 10
)
```

- For actionable issues, call
  `mcp__glitchtip__.get_latest_event(issue_id: <id>)` and inspect tags,
  release, environment, device, breadcrumbs, and stack data.
- Do not resolve or ignore GlitchTip issues unless the user asks for that
  action, or the task is explicitly to close verified fixed issues.

## Current Priorities

See @ROADMAP.md for production bugs, immediate fixes, and sprint priorities. Key items as of Apr 2026:
- **P0**: Core messaging invariants (contract tests for `localId` identity, out-of-order delivery)
- **Fixes needed**: InvalidateSync disposed crash (55 fatal/day), Null check operators (chat load + general), back button error rate (37.5%)
- **Quick wins**: Guard offline machine in session creation, clear stale profile references

## Core Invariants

- **One tap, one logical message**
- **One canonical `localId` across UI, sync, HTTP, socket, retry, and merge**
- **Repeated text like `continue` is never identity**
- **Optimistic replacement is by `localId`, not by text or position**

## Verification Expectations

- **Core messaging changes require targeted contract tests**
- **Run Flutter commands through `mise`**
- **Assert invariants: no duplicate logical message, no orphan optimistic row, no lost retry identity**

## Documentation Notes

- **`CLAUDE.md` is the authoritative agent guide**

## Project Overview

Happy Flutter is **happy's mobile app**, built with Flutter.

**Tech Stack:**
- Flutter 3.41.x (pinned via `.mise.toml` → flutter 3.41.9, Dart 3.11.5, Java 21)
- Riverpod v3 (manual NotifierProvider, no code generation)
- Dio + NativeAdapter (Cronet on Android, cupertino_http on iOS) for HTTP
- Socket.IO for real-time updates
- MMKV for storage (SharedPreferences on web), FlutterSecureStorage for secrets
- NaCl/libsodium (legacy) + AES-256-GCM (new data) for encryption
- Sentry for error tracking
- Go Router v17 for navigation
- i18n via Flutter's built-in localization (`flutter: generate: true`)

**Environment:** This project uses [mise](https://mise.jdx.dev/) to pin Flutter / Dart / Java. Activate once with `mise install`; then either prefix every command with `mise exec --` (e.g. `mise exec -- flutter test`) or run `direnv allow` so the right `flutter` / `dart` / `java` land on PATH automatically when you `cd` into the repo. Replaces the previous `devenv shell` shim, which depended on the nix store and kept getting GC'd.

## Common Commands

```bash
# Dependencies
mise exec -- flutter pub get

# Analysis (errors block CI; warnings/infos do not)
mise exec -- flutter analyze

# Testing
mise exec -- flutter test
mise exec -- flutter test test/services/sync_service_test.dart

# Golden screenshots — update after UI changes
mise exec -- flutter test test/golden/golden_test.dart --update-goldens

# Code generation (after changing freezed/json_serializable models or ApiClient public API)
mise exec -- flutter pub run build_runner build --delete-conflicting-outputs

# Build APK (flavors: development, preview, production)
mise exec -- flutter build apk --debug --flavor development
mise exec -- flutter build apk --release --flavor production

# Run on device/emulator
mise exec -- flutter run
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
│   ├── models/            # freezed/json_serializable + a few manual models
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
    ├── changelog/         # In-app changelog viewer
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

**`_shared.dart`** files in feature directories contain an `unset` sentinel (`const Object()`) used in `copyWith` methods to distinguish "not provided" from `null`.

**Immutable updates:** Always use spread copies: `{...state, id: value}`, `[...state.list, item]`

### The Sync Singleton

Three top-level globals: `sync` (Sync singleton), `logger` (LoggerService), `socketIoClient` (SocketIoClient).

**`Sync` is a true singleton** (`factory Sync() => _instance`). The main file `lib/core/services/sync_service.dart` is ~1,000 lines, split across ~20 `_sync_*.dart` part files (`_sync_messaging*`, `_sync_socket*`, `_sync_data*`, `_sync_lifecycle`, `_sync_operations*`, `_sync_health`, `_sync_test_helpers`, etc.). When adding methods, place them in the part file matching the concern.

**Provider bridge pattern:** Screens subscribe to `sync.onDataChanged` (debounced 100ms):
- `provider.notifier.loadFromSync()` — reads in-memory state (instant). Use on every `onDataChanged` callback.
- `provider.notifier.refreshFromSync()` — server fetch + read. Use once in `initState` with `microtask`.

Guard on `sync.isInitialized` — `loadFromSync()` is a no-op when `false`. `sync.isReady` is separate (set after sessions+machines resolve).

**ChatScreen exception:** Subscribes to BOTH `sync.onDataChanged` AND `sync.onSessionMessagesChanged`, uses `setState()` with local `_refreshFromSync()` for paginated message lists. Do not apply the standard template here.

**InvalidateSync fields (13):** `sessionsSync`, `settingsSync`, `profileSync`, `purchasesSync`, `machinesSync`, `pushTokenSync`, `nativeUpdateSync`, `artifactsSync`, `friendsSync`, `friendRequestsSync`, `feedSync`, `todosSync`, `sessionGitStatusSync`. `messagesSync` is `Map<String, InvalidateSync>` (per-session).

**Lifecycle handling:** `Sync.suspend()` disconnects socket (unless rapid cycling detected), cancels all timers, flushes MMKV. `Sync.resume()` reconnects socket and invalidates syncs. Rapid lifecycle cycling (resume→suspend within 2s) keeps socket connected to avoid reconnect cascades.

See @docs/SYNC_PATTERNS.md for subscription template and details.

### Navigation

Routes defined in `lib/core/routing/app_router.dart` (not `main.dart`). ~64 flat `GoRoute` entries. Use named routes:

```dart
context.goNamed('chat', pathParameters: {'sessionId': id});
```

For non-URL data (e.g., `message-detail`), pass `Map<String, dynamic>` via `state.extra`.

**Page transitions:**
- `_fadePage` — top-level tab destinations
- `_slideUpPage` — creation/modal flows
- `_slidePage` — detail screens with iOS-style swipe-back on all platforms

**`SessionsScreen`** is a stateful tab shell rendering `SettingsScreen` inline (not via GoRouter's `ShellRoute`).

**Auth gating:** Every route wraps its child in `AuthGate`. The router only redirects `/` → `/sessions` for authenticated users.

### Key Services

| Service | Purpose |
|---------|---------|
| `ApiClient` | Dio + NativeAdapter (Cronet/cupertino_http). Timeouts: connect 30s, receive 60s, send 30s |
| `SocketIoClient` | Socket.IO on `/v1/updates`, websocket only, 2–10s reconnect delays |
| `LoggerService` | 5000-entry circular buffer, ANSI color debug output, Sentry forwarding |
| `MessageCacheService` | Last 200 messages per session in MMKV, 500ms debounced writes |
| `MessageOutbox` | Failed sends in MMKV, exponential backoff 1s→30s, max 3 retries |

Some domains have both `XxxService` (production) and `XxxApi` (injectable for tests). `XxxApi` classes accept optional `ApiClient? client` for test injection.

### Storage

| Class | Backend | Purpose |
|-------|---------|---------|
| `MMKVStorage` | MMKV / SharedPreferences (web) | Settings, drafts, sessions cache |
| `ServerConfigStorage` | MMKV `'server-config'` | Custom server URL (persists across logouts) |
| `TokenStorage` | FlutterSecureStorage | JWT and auth keys |
| `APIKeyStorage` | FlutterSecureStorage | Per-profile API keys |

`Storage().initialize()` inits all. SharedPreferences → MMKV migration runs once on first init.

## Models

**`freezed` + `json_serializable`** for most core models (`session`, `message`, `machine`, `artifact`, `usage`, `auth`, `kv`, `local_settings`, `purchases`, `api_update`, `claude_usage_limits`) since the freezed migration (a1e03c3f); a few simpler models (`profile`, `todo`, `friend_request`, `settings_update`) remain manual `fromJson`/`toJson`/`copyWith`. Timestamps are integers (milliseconds), not `DateTime`.

**NEVER hand-edit `*.g.dart` or `*.freezed.dart` files.** After changing any annotated model, regenerate with `mise exec -- flutter pub run build_runner build --delete-conflicting-outputs` and commit the regenerated output together with the source change.

**Exception:** `Settings` uses mutable public fields (`var`, not `final`) and roundtrips through `toJson()`/`fromJson()` in `updateSetting`. Nested config classes within Settings use `final` fields normally.

**`Session.presence`** is always a `String` (`'online'` or `'offline'`), never `null`. Absence on wire maps to `'offline'`.

**`WireParsers`** utility handles lenient type coercion for JSON fields (numbers vs numeric strings from different backends).

## UI Conventions

**Design tokens** in `lib/core/theme/app_tokens.dart`: `AppSpacing` (xxs=2 to xxxl=32), `AppRadius` (xs=4 to pill=100), `AppFontSize` (xxs=10 to lg=16), `AppDuration` (fast=150ms to slower=500ms), `AppTouchTarget` (min=44, comfortable=48), `AppBreakpoint` (tablet=600, desktop=960), `AppScreenPadding` (standard, compact, settings, listItem).

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

**Unit, widget, and integration tests.** Integration tests in `test/integration/` cover session spawning, message deduplication, routing, pagination, cold starts, reconnection, and concurrent sends (~18 e2e files). They use `mock_sync_server.dart` and `fake_session_encryption.dart` helpers, plus replay fixtures under `test/integration/jsonl_replay/`.

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
mise exec -- flutter test test/golden/golden_test.dart --update-goldens
```

Then commit the updated PNGs. Do not leave stale goldens — they will cause false test failures for other contributors.

**Git LFS:** Golden PNGs are tracked via Git LFS (see `.gitattributes`). Contributors must have `git-lfs` installed (`git lfs install`). The golden test file is `test/golden/golden_test.dart`.

**Viewport:** Phone viewport set via `tester.view.physicalSize = Size(390*2, 844*2)` with `devicePixelRatio = 2.0`.

## Coding Standards

- **Strict typing:** `implicit-casts: false`, `implicit-dynamic: false`
- **Line length:** 80 chars max; file size: 800 lines max (exclude `*.g.dart`)
- **CI-blocking errors:** `missing_required_param`, `missing_return`, `must_be_immutable`
- **Prefer:** const constructors, final fields, single quotes, spread collections
- **Avoid:** `print` — use `logger.info/warning/error()`; use `unawaited()` for fire-and-forget
- **Platform code:** Conditional exports: `platform_io.dart`/`platform_stub.dart`, `mmkv_storage_native.dart`/`mmkv_storage_web.dart`, `sodium_loader_native.dart`/`sodium_loader_web.dart`, `sentry_*.dart`
- **Sync part files:** `lib/core/services/_sync_*.dart` — add new methods to the appropriate part file
- **Models:** `freezed` + `json_serializable` for core models, manual `fromJson`/`toJson`/`copyWith` for a few simple ones (see Models section). Never hand-edit generated files — run build_runner. Timestamps are integers (milliseconds), not `DateTime`
- **Error handling:** Log via `logger.warning`/`logger.error`. For data loss/corruption risks, also call `Sentry.captureException`

**Analysis:** `test/**/*.dart` excluded. CI runs `flutter analyze --no-fatal-infos --no-fatal-warnings` (errors only block build).

## Dependency Overrides

`pubspec.yaml` has `dependency_overrides` — check the inline comments there for the current set (as of Jun 2026: `shared_preferences_android`, `mmkv_platform_interface`, `flutter_secure_storage_linux`, `go_router`).

## Additional Documentation

| Doc | Purpose |
|-----|---------|
| @docs/SYNC_PATTERNS.md | Sync subscription templates and InvalidateSync usage |
| @ROADMAP.md | Production bugs, sprint priorities, feature status |
| @docs/ARCHITECTURE.md | Architecture review (Sync god object, known issues) |
| `docs/` | 15+ internal docs on security, protocol, UI/UX, etc. |
