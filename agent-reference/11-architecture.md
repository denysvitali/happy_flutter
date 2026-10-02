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
│   ├── services/          # Auth, Sync (27 part files), storage, logging, push, TTS
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

Session ToDos in `metadata.todos` can have `parentId` and `agentId`.
Children inherit the nearest ancestor's agent unless assigned explicitly.
Completed items remain visible until a later add; that add expires completed
leaves while keeping completed ancestors of visible children. Preserve these
fields in tool snapshot parsing and show the hierarchy and agent in chat and
Tasks. The Tasks screen offers an agent filter.

Codex sub-agent conversations use stable `Agent` tool-call anchors keyed by
their child thread ID. Their emitted messages carry `isSidechain`, `agentId`,
and `parentToolUseId` so the existing sidechain grouper keeps each agent's
conversation separate from the parent chat, including when spawn items are
missing or arrive late. ToDo `agentId` assignments alone are not transcript
linkage.

`AgentConversationScreen` owns subscriptions, workflow resolution, scrolling,
and TTS; `widgets/agent_conversation_header.dart` and
`widgets/agent_conversation_message.dart` own its presentation. Workflow detail
uses `WorkflowRunHeader` and `WorkflowPhaseSection`, keeping fetch/projection
state in `WorkflowRunScreen`. Codex patch parsing lives in
`tools/views/codex_patch_data.dart`, with rendering split between the list view
and `codex_patch_detail.dart`; the original view exports `FileChange`.

**Notable:** `AuthStateNotifier` acts as a coordinator — on auth changes it calls `loadFromSync()`/`clear()` on all other providers.

Codex model catalogs are scoped to machine, profile, and project directory
with a five-minute cache. Opening the picker or tapping Refresh bypasses
the Happy caches; Codex still applies its own upstream refresh policy.
Filter hidden models without dropping models that have no reasoning effort.
Profile-defined models remain authoritative. Fence async catalog commits
against runtime resets and UI context changes; preserve choices on transient
refresh failures and show the notice inside the picker.

**`_shared.dart`** files in feature directories contain an `unset` sentinel (`const Object()`) used in `copyWith` methods to distinguish "not provided" from `null`.

**Immutable updates:** Always use spread copies: `{...state, id: value}`, `[...state.list, item]`

### The Sync Singleton

Three top-level globals: `sync` (Sync singleton), `logger` (LoggerService), `socketIoClient` (SocketIoClient).

**`Sync` is a true singleton** (`factory Sync() => _instance`). The main file `lib/core/services/sync_service.dart` is ~1,700 lines (it holds the public field surface), split across ~27 `_sync_*.dart` part files (`_sync_messaging*`, `_sync_socket*`, `_sync_data*`, `_sync_lifecycle`, `_sync_operations*`, `_sync_health`, `_sync_test_helpers`, etc.). When adding methods, place them in the part file matching the concern.

**Provider bridge pattern:** Screens subscribe to `sync.onDataChanged` (debounced 100ms):
- `provider.notifier.loadFromSync()` — reads in-memory state (instant). Use on every `onDataChanged` callback.
- `provider.notifier.refreshFromSync()` — server fetch + read. Use once in `initState` with `microtask`.

Guard on `sync.isInitialized` — `loadFromSync()` is a no-op when `false`. `sync.isReady` is separate (set after sessions+machines resolve).

**ChatScreen exception:** Subscribes to BOTH `sync.onDataChanged` AND `sync.onSessionMessagesChanged`, uses `setState()` with local `_refreshFromSync()` for paginated message lists. Do not apply the standard template here.

Mission Control has no cross-session activity feed: the former Live wire
duplicated the Focus queue and was removed. Focus queue rows let the title
wrap to two lines and keep workspace plus the latest update on one detail
line (two for errors).

Chat list projection drops empty/redacted reasoning, empty non-streaming
assistant text and sidechain scaffolding before grouping and row spacing.
Keep the source rows available for activity resolution and chain recovery.

Chat message refreshes use a fixed 50ms coalescing window: never restart it
for every token, which can starve rendering during continuous output. The
activity bar distinguishes delivery, waiting for a response, and thinking.
Read the unfiltered message tail for empty reasoning signals and use live
`presence`, not the catalog's `active` flag, for agent liveness. Keep request
status keyed by canonical `localId`; failed/outbox sends retain their own
recovery UI. The client cannot stream text that the server has not emitted.
Sparse first-open history backfill is limited to one older page while the chat
is visible; subsequent history loads follow user scrolling.

**InvalidateSync fields (9):** `sessionsSync`, `settingsSync`, `profileSync`, `purchasesSync`, `machinesSync`, `pushTokenSync`, `nativeUpdateSync`, `artifactsSync`, `sessionGitStatusSync`. `messagesSync` is `Map<String, InvalidateSync>` (per-session). `createTestSync()` in `test/helpers/test_helpers.dart` is the authoritative list — never hand-roll the field list in a test.

Exhausted sessions or machines refreshes remain visible through
`Sync.hasUnrecoveredCriticalSyncFailure` and `SyncProgressBar` until a later
successful refresh. A failed cold-start fetch is not an authoritative empty
catalog.

**Lifecycle handling:** `Sync.suspend()` disconnects socket after a 2s grace (deferred timer; cancels if resumed sooner), cancels all timers, flushes MMKV. `Sync.resume()` reconnects the socket and invalidates syncs; it also forces a fresh connection when a socket still claims `connected` after >45s backgrounded (zombie — the server-side session dies ~45s after heartbeats stop). Rapid lifecycle cycling (resume→suspend within 2s) keeps socket connected to avoid reconnect cascades. A 15s reconnect watchdog armed on resume re-arms itself while disconnected (cancelled on connect/suspend), and `Sync.forceReconnect()` is the manual "Reconnect now" entry point (offline banner) — it dials fresh and arms the same watchdog.

See `docs/SYNC_PATTERNS.md` for subscription template and details.

HTTP pools renew on native link handoffs, DNS/connection failures and
pre-header deadlines. Retired pools drain active writes; failures from an old
pool cannot retire its replacement. Older-history body timeouts halve large
pages against the same end cursor under one 40s deadline. Partial-body byte
counts remain transport diagnostics, not complete response sizes. Machine RPC
capability discovery, encryption, ACK and decode share one caller deadline.
Startup-resume settings opt into one bounded idempotent routing retry; usage
reads coalesce, and only unsupported methods fall back to Bash.

HTTP suspension cancellations carry `HttpCancellationReason.appSuspended`.
They remain failed refresh attempts with cached state preserved, but do not
produce error spans or machine-fetch errors. Deadlines, disposal and arbitrary
caller cancellation remain errors. HTTP response sizes use consumed adapter
bytes or a declared size; unknown decoded JSON sizes are omitted.

### Navigation

Routes defined in `lib/core/routing/app_router.dart` (not `main.dart`). ~30 flat `GoRoute` entries. Use named routes:

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
| `MessageCacheService` | Last 200 messages per session in MMKV, 5s debounced writes (15s ceiling), single queued encode isolate; the suspend flush uses that worker too (never UI-isolate encode); Linux compacts sparse MMKV once after startup |
| `MessageOutbox` | Failed sends in MMKV, exponential backoff 1s→30s, max 3 retries |
| `FrameMetricsService` | Aggregated build/raster/total frame metrics and frozen-frame reporting |
| `StuckAgentSentinel` | Actionable alert for off-screen thinking sessions with no progress |
| `DesktopUpdaterService` | Linux self-updater: GitHub Releases check (startup + 6h), auto-download, atomic bundle swap, restart prompt; mirrors `scripts/update-linux.sh` |

**Repository migration:** Sessions, machines, settings, artifacts, messages,
and workflows expose Riverpod-injectable repositories. Some concrete
implementations still delegate to `Sync`; preserve the facade while moving new
provider/action code behind repository interfaces.

Some domains have both `XxxService` (production) and `XxxApi` (injectable for tests). `XxxApi` classes accept optional `ApiClient? client` for test injection.

`provider_usage_api.dart` owns Kimi, MiniMax, Z.AI, Grok, and Qwen HTTP clients.
Their `*_usage_parser.dart` files interpret usage windows independently of
transport; `_provider_usage_response.dart` remains a private response-helper
part. Preserve each vendor's payload precedence, reset-time rules, and error
behavior when changing these boundaries.

### Storage

| Class | Backend | Purpose |
|-------|---------|---------|
| `MMKVStorage` | MMKV / SharedPreferences (web) | Settings, drafts, sessions cache |
| `ServerConfigStorage` | MMKV `'server-config'` | Custom server URL (persists across logouts) |
| `TokenStorage` | FlutterSecureStorage | JWT and auth keys |
| `APIKeyStorage` | FlutterSecureStorage | Per-profile API keys |

`Storage().initialize()` inits all. SharedPreferences → MMKV migration runs once on first init.

Production custom servers must use HTTPS, except for Tailscale endpoints in
the `100.64.0.0/10` CGNAT range. Debug builds also permit HTTP for loopback
(`localhost`, `127.0.0.1`, `::1`) development endpoints. Provider API keys are
cleared on sign-out so they cannot cross account boundaries.

Settings hydration markers describe the current cached snapshot, not the fact
that a profile was saved. Lazy snapshots still require secure-key reads.
Suspension flushes pending settings writes before background termination.
