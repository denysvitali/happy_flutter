# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Rules

- **Always commit and push** after completing changes — do not wait for the user to ask
- **Use conventional commits** — prefix messages with `feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`, etc.
- **Check CI status** after pushing using GitHub Actions MCP tools — aim for green CI
- **Releases are automatic** — every commit to `main` produces a GitHub Release (`v1.0.0-<build#>`) with the signed production APK and Linux x64 archive. Never tag or cut releases manually; landing a fix on `main` ships it.
- **Never run tests locally** — the full test suite consumes large amounts of RAM and can crash the device. Always rely on CI for test execution.
- **Always use `rg` (ripgrep)** when searching for code, symbols, or strings
- **Do not create new documentation files** (`*.md`, `README` updates) unless explicitly requested.
- **Update existing documentation when code changes**: keep `README.md`, affected docs, `AGENTS.md`, and `CLAUDE.md` up to date.
- **Treat chat send reliability as a P0 surface** — preserve one canonical `localId` across optimistic UI, REST send, retry, socket forwarding, and merge
- **When touching core messaging code, add or update contract tests first** — repeated identical sends, optimistic replacement, retry identity, and out-of-order delivery are mandatory coverage
- **This app wraps Claude Code** — happy_flutter is a Flutter mobile client for Claude Code sessions. When the user references "Read", "Write", "Bash", "tool output", "ReadFile", agent tool names, or anything that sounds like the Claude Code agent or CLI itself, they mean the **happy_flutter app's rendering / interaction with that tool**, not the Claude Code harness. Debug Flutter widgets, screens, models, providers, and Sync code — never reach for Claude Code internals.

## Project Skills

Repo-local skills in `.claude/skills/` encode recurring workflows — prefer them over ad-hoc approaches:

- `glitchtip-triage` — production-issue audit (GlitchTip → Loki → stale-build check → ROADMAP)
- `update-goldens` — regenerate golden screenshots via CI and commit LFS PNGs
- `ci-flake-triage` — match red CI against the known-flake corpus before diagnosing
- `contract-test` — scaffold/extend core-messaging `localId` contract tests
- `loki-trace` — cross-service log correlation via `trace_id` / `app_launch_id`
- `ui-audit-batch` — one scoped UI-quality batch (theming, extraction, deprecations)

## Inspecting a Session's Wire Data (CLI)

- **Session ids are opaque hex strings** (e.g. `c948d14cf2c6fc0573379cbb1`). They are *not* git SHAs and are distinct from the `claudeSessionId` (UUID) and `machineId` (UUID) shown in the metadata. If a pasted hex id fails `git rev-parse` / `git cat-file`, treat it as a session id, not a commit.
- Use the **`happy` CLI** (the binary on PATH is `happy` — not `haply`) to decrypt and dump a session's metadata, messages, sidechains, and process state. This is the fastest way to see the raw wire shape behind a UI rendering bug (a workflow run's `workflowProgress` / sidechain `children`, encrypted message bodies, tool-call input/result):

```bash
happy debug session <session-id>                                       # human-readable; 20 oldest messages
happy debug session <session-id> --tail                                 # most recent messages
happy debug session <session-id> --messages 500                         # widen the window (cap it — full transcripts are large)
happy debug session <session-id> --json --no-process --no-diagnostics   # raw JSON bodies for jq/rg
happy debug session <session-id> --all --remote                         # everything, incl. owning daemon/machine
```

  Useful flags: `--last-message`, `--no-messages`, `--no-process`, `--no-diagnostics`, `--remote`. Sibling verbs under `happy debug`: `bundle` (redacted tarball for bug reports), `doctor`, `logs`, `status`, `config`, `repair-sessions`.

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
- **Codex follow-ups are explicit** — `message-steered` and `message-queued`
  agent events tell the chat timeline whether an active-turn update was
  accepted or retained for the next turn; user messages carry
  `meta.codexDeliveryMode` (`active-turn` or `next-turn`) when the composer
  explicitly selects the destination
- **Linking deep links are requests, never approvals** — lifecycle handlers
  stage `happy://` links; only an explicit in-app fingerprint confirmation may
  release account key material.
- **Sync commits are runtime-scoped** — async work must verify the current
  account/runtime generation after every await before mutating state or cache.
- **Per-session sends are FIFO** — foreground sends and outbox retries share
  one serialized delivery lane; confirmed `sent` state is monotonic.

## Verification Expectations

- **Core messaging changes require targeted contract tests**
- **Run Flutter commands through `mise`**
- **Assert invariants: no duplicate logical message, no orphan optimistic row, no lost retry identity**

## Documentation Notes

- **`CLAUDE.md` is the authoritative agent guide**

## Project Overview

Happy Flutter is **happy's mobile app**, built with Flutter.

**Tech Stack:**
- Flutter 3.41.x (pinned via `.mise.toml` → flutter 3.41.9, Dart 3.11.5, Java 21, GNU Make 4.4.1)
- Riverpod v3 (manual NotifierProvider, no code generation)
- Dio + NativeAdapter (Cronet on Android, cupertino_http on iOS) for HTTP
- Socket.IO for real-time updates
- MMKV for storage (SharedPreferences on web), FlutterSecureStorage for secrets
- NaCl/libsodium (legacy) + AES-256-GCM (new data) for encryption
- Sentry for error tracking
- Go Router v17 for navigation
- i18n via Flutter's built-in localization (`flutter: generate: true`)

**Environment:** This project uses [mise](https://mise.jdx.dev/) to pin Flutter / Dart / Java / Make. Activate once with `mise install`; then either prefix every command with `mise exec --` (e.g. `mise exec -- flutter test`) or run `direnv allow` so the right `flutter` / `dart` / `java` / `make` land on PATH automatically when you `cd` into the repo.

## Common Commands

```bash
# Dependencies
mise exec -- flutter pub get

# Analysis (errors block CI; warnings/infos do not)
mise exec -- flutter analyze

# Testing (run in CI only — never locally)
mise exec -- flutter test
mise exec -- flutter test test/services/sync_service_test.dart

# Golden screenshots — update after UI changes (run in CI only)
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
│   ├── actors/            # SessionActor — serialized per-session command queue
│   ├── api/               # ApiClient (Dio), SocketIoClient, per-domain API classes
│   ├── components/        # Higher-level widgets (AppCard, AppEmptyState, sidebar)
│   ├── config/            # AppConfig compile-time/runtime config
│   ├── crdt/              # LWWRegister + settings CRDT merge
│   ├── dialogs/           # AppDialog, ConfirmDialog
│   ├── encryption/        # NaCl (legacy), AES-256-GCM (new), key derivation,
│   │                      #   processors/ (wire content → Message semantics)
│   ├── event_log/         # Append-only event log + message projection
│   ├── fsm/               # MessageStateMachine (draft→sending→sent→merged)
│   ├── i18n/              # Internationalization helpers
│   ├── models/            # freezed/json_serializable + a few manual models
│   ├── native_chat_list/  # Platform-view chat list bridge
│   ├── providers/         # Riverpod NotifierProvider state (app_providers.dart barrel)
│   ├── repositories/      # Injectable domain boundaries; Sync-backed during migration
│   ├── routing/           # GoRouter setup (createRouter())
│   ├── rpc/               # RPC layer
│   ├── services/          # Auth, Sync (21 part files), storage, logging, push, TTS
│   ├── sync/              # ArtifactManager, SettingsManager, sync exceptions/progress
│   ├── theme/             # Colors, typography, design tokens
│   ├── types/             # Identity + message-state value types
│   ├── ui/                # Lower-level widgets (avatars, tab_bar, shimmer, diff)
│   ├── utils/             # InvalidateSync, path/version/message utils, ANSI parser
│   ├── widgets/           # Additional shared widgets
│   └── wire/              # MessageEnvelope — structural wire shape
└── features/
    ├── artifacts/         # Artifact list, detail, edit, create
    ├── auth/              # QR auth, device linking, backup restore
    ├── changelog/         # In-app changelog viewer
    ├── chat/              # Chat screen, input, markdown, tool views, autocomplete
    ├── command_palette/   # Modal command search
    ├── dev/               # Dev logs, encryption debug, network inspector
    ├── inbox/             # Friends, friend search, inbox
    ├── loops/             # Recurring-prompt loops
    ├── machine/           # Machine detail
    ├── mcp/               # Remote Claude Code MCP server management
    ├── providers/         # AI backend providers + usage
    ├── sessions/          # Session list, new-session dialog, machine/path/profile pickers
    ├── settings/          # Theme, language, voice, features, profiles, usage, etc.
    ├── sftp/              # SFTP with own models/providers/screens
    ├── terminal/          # Terminal connect and screen
    ├── workflows/         # Workflow-run detail
    └── zen/               # Zen home, new, view, priority
```

Three widget layers exist (`core/ui`, `core/components`, `core/widgets`); the
split is not guessable from the names — see the UI Conventions section.

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

**`Sync` is a true singleton** (`factory Sync() => _instance`). The main file `lib/core/services/sync_service.dart` is ~1,700 lines (it holds the public field surface), split across 20 `_sync_*.dart` part files (`_sync_messaging*`, `_sync_socket*`, `_sync_data*`, `_sync_lifecycle`, `_sync_operations*`, `_sync_health`, `_sync_test_helpers`, etc.). When adding methods, place them in the part file matching the concern.

**Provider bridge pattern:** Screens subscribe to `sync.onDataChanged` (debounced 100ms):
- `provider.notifier.loadFromSync()` — reads in-memory state (instant). Use on every `onDataChanged` callback.
- `provider.notifier.refreshFromSync()` — server fetch + read. Use once in `initState` with `microtask`.

Guard on `sync.isInitialized` — `loadFromSync()` is a no-op when `false`. `sync.isReady` is separate (set after sessions+machines resolve).

**ChatScreen exception:** Subscribes to BOTH `sync.onDataChanged` AND `sync.onSessionMessagesChanged`, uses `setState()` with local `_refreshFromSync()` for paginated message lists. Do not apply the standard template here.

**InvalidateSync fields (9):** `sessionsSync`, `settingsSync`, `profileSync`, `purchasesSync`, `machinesSync`, `pushTokenSync`, `nativeUpdateSync`, `artifactsSync`, `sessionGitStatusSync`. `messagesSync` is `Map<String, InvalidateSync>` (per-session). `createTestSync()` in `test/helpers/test_helpers.dart` is the authoritative list — never hand-roll the field list in a test.

Exhausted sessions or machines refreshes remain visible through
`Sync.hasUnrecoveredCriticalSyncFailure` and `SyncProgressBar` until a later
successful refresh. A failed cold-start fetch is not an authoritative empty
catalog.

**Lifecycle handling:** `Sync.suspend()` disconnects socket after a 2s grace (deferred timer; cancels if resumed sooner), cancels all timers, flushes MMKV. `Sync.resume()` reconnects the socket and invalidates syncs; it also forces a fresh connection when a socket still claims `connected` after >45s backgrounded (zombie — the server-side session dies ~45s after heartbeats stop). Rapid lifecycle cycling (resume→suspend within 2s) keeps socket connected to avoid reconnect cascades. A 15s reconnect watchdog armed on resume re-arms itself while disconnected (cancelled on connect/suspend), and `Sync.forceReconnect()` is the manual "Reconnect now" entry point (offline banner) — it dials fresh and arms the same watchdog.

See @docs/SYNC_PATTERNS.md for subscription template and details.

### Navigation

Routes defined in `lib/core/routing/app_router.dart` (not `main.dart`). 57 flat `GoRoute` entries. Use named routes:

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
| `ApiClient` | Dio + NativeAdapter (Cronet/cupertino_http). Timeouts: connect 8s, receive 15s, send 30s |
| `SocketIoClient` | Socket.IO on `/v1/updates`, websocket only, 1–10s reconnect delays |
| `LoggerService` | 5000-entry circular buffer, ANSI color debug output, Sentry forwarding |
| `MessageCacheService` | Last 200 messages per session in MMKV, 2s debounced writes (5s ceiling), single queued encode isolate, flushed on suspend |
| `MessageOutbox` | Failed sends in MMKV, exponential backoff 1s→30s, max 3 retries |
| `FrameMetricsService` | Aggregated build/raster/total frame metrics and frozen-frame reporting |
| `StuckAgentSentinel` | Actionable alert for off-screen thinking sessions with no progress |

**Repository migration:** Sessions, machines, settings, artifacts, messages,
and workflows expose Riverpod-injectable repositories. Some concrete
implementations still delegate to `Sync`; preserve the facade while moving new
provider/action code behind repository interfaces.

Some domains have both `XxxService` (production) and `XxxApi` (injectable for tests). `XxxApi` classes accept optional `ApiClient? client` for test injection.

### Storage

| Class | Backend | Purpose |
|-------|---------|---------|
| `MMKVStorage` | MMKV / SharedPreferences (web) | Settings, drafts, sessions cache |
| `ServerConfigStorage` | MMKV `'server-config'` | Custom server URL (persists across logouts) |
| `TokenStorage` | FlutterSecureStorage | JWT and auth keys |
| `APIKeyStorage` | FlutterSecureStorage | Per-profile API keys |

`Storage().initialize()` inits all. SharedPreferences → MMKV migration runs once on first init.

Production custom servers must use HTTPS. Debug builds permit HTTP only for
loopback (`localhost`, `127.0.0.1`, `::1`) development endpoints. Provider API
keys are cleared on sign-out so they cannot cross account boundaries.

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

**Unit, widget, and integration tests.** Integration tests in `test/integration/` cover session spawning, message deduplication, routing, pagination, cold starts, reconnection, and concurrent sends (27 files, 20 of them `*_e2e_test.dart`). They use `mock_sync_server.dart` and `fake_session_encryption.dart` helpers, plus replay fixtures under `test/integration/jsonl_replay/`.

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

**Finder gotcha (rediscovered twice — broke tests both times):** `find.text(x, findRichText: true)` is an EXACT match. A header rendering title+subtitle in one RichText (e.g. `'Apply Changes  new_file.dart'`) won't match `'Apply Changes'` — use `find.textContaining(x, findRichText: true)`.

**Test helpers** in `test/helpers/test_helpers.dart`: `createTestSync()`, `mockResponse<T>()`.

### Golden Screenshots

Golden screenshots in `test/golden/goldens/` are **showcase images** used in the README and to track visual regressions. They **must always be kept up-to-date** when the UI changes.

**After any UI change that affects visual output**, update goldens via CI — do not run the golden update command locally (see the "Never run tests locally" workflow rule above). Commit the updated PNGs produced by the CI run. Do not leave stale goldens — they will cause false test failures for other contributors.

Use the `Happy Flutter CI/CD` workflow's `update_goldens` manual-dispatch
input to generate the PNG artifact when working directly on `main`. If the
workflow cannot be dispatched, include `[update-goldens]` in the triggering
commit message instead.

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

`pubspec.yaml` has **~30 `dependency_overrides`** in three groups, each with an
inline comment explaining the pin. Read those comments before touching any of
them — several encode Flutter-SDK constraints that a bump silently breaks:

1. **Platform-implementation pins** — `shared_preferences_android`,
   `mmkv_platform_interface`, `flutter_secure_storage_linux`, `go_router`,
   `dartastic_opentelemetry*`.
2. **Force-upgrade block (2026-06-15)** — unblocks transitive constraints
   flagged by `pub upgrade`. **Never force-bump a package whose latest release
   declares Dart 3.12**: overrides bypass pub's SDK check, so it resolves and
   then fails at compile time. mise pins Flutter 3.41 / Dart 3.11.
3. **Caps** — `cupertino_http` (3.x breaks `flutter build linux`),
   `jni`/`cronet_http`/`path_provider_android` (held by `sentry_flutter`'s
   hard pin on `jni` 0.14.2).

## Additional Documentation

| Doc | Purpose |
|-----|---------|
| @docs/SYNC_PATTERNS.md | Sync subscription templates and InvalidateSync usage |
| @ROADMAP.md | Production bugs, sprint priorities, feature status |
| @docs/AGENTS.md | Repository-local agent instructions for docs-specific overrides |
| @docs/ARCHITECTURE.md | Architecture review (Sync god object, known issues) |
| `docs/` | 13 internal docs on security, protocol, UI/UX, sync, and operations, plus `docs/book/` (15 chapters) |

## Logs & Metrics — Observability

Mobile client telemetry flows three ways: **Loki** for log streams, **Prometheus** for app/server metrics, **GlitchTip** for crash+issue tracking. The Flutter app ships OTel-flavored logs (`scope_name="happy_flutter"`, `scope_version=1.11.x`) via `LoggerService` → OTel collector → Loki.

### Loki (logs)

Service label is `service_name="happy-flutter"` (note the dash, not underscore). Logs carry per-launch identifiers `app_launch_id`, `trace_id`, `span_id` so you can correlate a user report with the exact launch and trace.

**Useful selectors:**

```logql
# All happy-flutter logs (last 1h)
{service_name="happy-flutter"}

# Errors only (compact output, no payload)
{service_name="happy-flutter"} | detected_level="ERROR"

# Warnings + errors
{service_name="happy-flutter"} | detected_level=~"ERROR|WARN"

# Filter by trace_id from a GlitchTip issue
{service_name="happy-flutter"} | trace_id="<hex>"

# Filter by launch
{service_name="happy-flutter"} | app_launch_id="<uuid>"

# Pipeline stage outcomes (raw/normalized/processed/grouped/merged/notified)
{service_name="happy-flutter"} |~ "stage=\\w+ outcome=(error|dropped)"
```

**Pipeline stage vocab:** `raw → normalized → processed → grouped → merged → notified`. Search by `stage=<name>` to follow a single socket payload through the ingestion pipeline.

**Volume policy (DEBUG):** successful `stage=notified outcome=ok` lines are logged once per 5-minute window; the rest of the window is folded into one INFO `outcome=summary suppressed=<n> sessions=<n>` line so the DEBUG sampler cannot discard the count. Every non-`ok` outcome is still logged verbatim, so `outcome=(error|dropped)` greps are unaffected. On top of that, `LoggerService` caps DEBUG **OTel export** at 60/min (120 burst) and samples 1-in-25 beyond it, reporting shed counts as `[logger] dropped … from OTel export`. The local 5000-entry ring buffer behind DevLogsScreen keeps full fidelity.

**Caveat:** `mcp__loki__loki_query` has a token cap (~10k tokens per call); on large queries the result is saved to `~/.claude/projects/.../tool-results/mcp-loki-loki_query-*.txt` and must be read in chunks. Use `head`/`tail`/`limit` to bound the response, and `filter` to reduce noise.

**`mcp__loki` not loaded?** Retry once, say out loud it's broken, then query Loki direct: `http://loki.monitoring.svc.cluster.local:3100` — same LogQL selectors via `/loki/api/v1/query_range`. Don't silently stall or work around it for turns.

### Prometheus (metrics)

App telemetry uses OTel metrics too. Useful base names: `app.*` (e.g. `app.deferredInit` duration, `app.chat.sync.await` stall). Server-side `happy-server` and `happy-daemon` metrics share the Prometheus instance. Example:

```promql
# Cold start duration (seconds, last 1h)
histogram_quantile(0.95, sum(rate(app_cold_start_seconds_bucket[5m])) by (le))

# fetchMessages p95
histogram_quantile(0.95, sum(rate(app_fetch_messages_seconds_bucket[5m])) by (le))
```

`mcp__prometheus__prometheus_search` accepts natural-language queries ("cold start time", "fetch messages latency") to discover metric names before writing PromQL.

### GlitchTip (crashes + issues)

Use for **fatal** bugs and issue triage — see the *Production Issues / GlitchTip* section above for the `mcp__glitchtip__` invocation recipe (organization `default`, project `happy_flutter`).

### Server-side Loki

The Rust daemon and Go server are also indexed in Loki:

- `service_name="happy-server"` — Go server
- `service_name="happy-daemon"` — happy-cli daemon

When chasing a Flutter-visible bug (e.g. `CryptoSecretBox.decrypt failed`, `fetchMessages dropped`, `machine offline`), cross-check the Flutter trace_id against the server-side logs for the same window — many "client" errors originate server-side.
