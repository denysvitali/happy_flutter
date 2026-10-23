# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Rules

- **Always commit and push** after completing changes — do not wait for the user to ask
- **Use conventional commits** — prefix messages with `feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`, etc.
- **Check CI status** after pushing using GitHub Actions MCP tools — aim for green CI
- **Releases are automatic** — every commit to `main` produces a GitHub Release (`v1.0.0-<build#>`) with the signed production APK and Linux x64/ARM64 Flatpaks and optional archives. Never tag or cut releases manually; landing a fix on `main` ships it.
- **Linux Flatpak builds use GNOME 49** — `packaging/flatpak/` and `scripts/build-flatpak.sh` compile Flutter plugins and Rust inside the SDK. Flatpak owns updates; never enable the tarball updater inside its sandbox. GitHub bundles currently require installing each new release; there is no hosted app update remote.
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
- `ci-flake-triage` — match red CI against the known-flake corpus before diagnosing
- `contract-test` — scaffold/extend core-messaging `localId` contract tests
- `loki-trace` — cross-service log correlation via `trace_id` / `app_launch_id`
- `ui-audit-batch` — one scoped UI-quality batch (theming, extraction, deprecations)

## Current Priorities

See @ROADMAP.md for live priorities, production bugs, and implementation status.
Keep messaging reliability and canonical `localId` contracts as P0.

## Core Invariants

- **Idle visual work is bounded** — covered/unfocused chats defer projection,
  not delivery. Tool clocks obey visibility; loading motion settles and honors
  reduced motion. CPU telemetry measures the local process, not machine vitals.

- **Har is process-scoped** — flavor `har` uses ACP text/tool events and
  cancellation. Launch `codex/gpt-6-luna` (default), explicit
  `codex/gpt-6.1-sol`, or `grok/grok-4.7`, with host execution and approvals
  disabled. Require the
  installed binary and explicitly disabled Boxy on the local daemon. Lock
  provider/permission controls after launch; model changes use the running
  session's `set_model` RPC while idle, never respawn. Publish the selection
  and refresh send baselines only after confirmation. A stopped conversation may
  attempt saved startup only with `happy-private-v1` durable checkpoint metadata;
  the daemon validates locked private evidence, and sending requires a fresh
  same-checkpoint runtime confirmation after cursor/history reconciliation.
  Unqualified or unresolved effects remain blocked, never blindly replayed.
  Flutter profiles forward only explicit `HAR_PROXY_URL` and
  `HAPPY_HAR_BINARY`; profile environment credentials are not secure-storage
  fields, so `HAR_API_KEY` is not forwarded. Images, provider switching,
  reasoning/speed/context controls and startup resume are unavailable.

- **OpenCode owns its model catalog** — flavor `opencode` offers only
  `metadata.opencodeModels` (`{id,name}` entries) plus Default. Confirmed
  selection is `metadata.model`; advertised IDs travel unchanged in
  `meta.model` and switch in place before the next prompt. Saved conversations
  restore through the existing daemon path. ACP tools reuse the tool cards,
  and `metadata.plan` supplies the task banner. Effort, images, child anchors,
  and context/usage telemetry are unavailable.

- **Prime Agent switches model in place** — flavor `prime-agent` lists the
  models the running agent publishes in `metadata.primeagentModels`. A pick
  travels in the next message's `meta.model`. The Effort slider uses only
  `metadata.primeagentEfforts`; `meta.reasoning_effort` applies before the next
  prompt, separate from the model ID. Confirmed effort is `reasoningEffort`.
  A running session is never respawned for a model, effort, or profile change. Stopped sessions may restore only
  with a valid `metadata.primeAgentSessionFile` transcript basename and a
  machine/project target. Send and Retry require confirmed same-session
  restore before delivery and preserve `localId`; failed restore never falls
  back to the dead process. Legacy sessions without a saved transcript need
  a new conversation. Stale permissions remain expired. New sessions do not
  inherit the global last-used model.
  Native Prime children use ACP `Agent` anchors. Preserve reported
  `agentMetadata` on calls, any child text/thinking, and terminal results;
  each present map replaces the previous snapshot, including `{}` to clear it.
  Child models and permissions never inherit parent defaults.
  happy-cli-go reads native child transcripts from Prime's existing daemon;
  group their linked sidechain steps under the corresponding Agent anchor.
  Prime context usage comes from the daemon's timestamped `context_size` and
  `context_window` snapshot, separate from cumulative billing counters. Null
  clears unknown values; zero occupancy is valid. Wire sequence orders snapshots
  across equal timestamps and clock changes; legacy usage uses timestamp order.
  Hide stale context after a model/provider change. Unknown capacity has no gauge.
  Child-step diagnostics expose bounded resident/grouping counts and reported
  bridge capability/revision. Missing capability is unknown. Logs/traces carry
  correlation IDs; metric labels never contain IDs, text, paths, or payloads.

- **ACP tool details show the real call** — ACP tool inputs gain
  Claude-compatible path aliases (`file_path`, `target_directory`) for the tool
  views. The arguments as sent stay in `wireInput`; Tool Details renders that,
  never the aliased copy. Har delegation arrives as an `Agent` call whose child
  tool calls and results are sidechain rows linked by `parentToolUseId`.

- **ACP tool details show the real call** — ACP tool inputs gain
  Claude-compatible path aliases (`file_path`, `target_directory`) for the tool
  views. The arguments as sent stay in `wireInput`; Tool Details renders that,
  never the aliased copy. Har delegation arrives as an `Agent` call whose child
  tool calls and results are sidechain rows linked by `parentToolUseId`.

- **Archive overrides survive catalog refreshes** — inactivity, archive
  confirmation, and omission from a fetch must not clear explicit session
  hiding; only unarchive or runtime reset clears it.

- **Answer previews are ephemeral** — encrypted `message-stream` snapshots
  from happy-cli-go overlay only the visible chat. They never enter the
  durable cache, advance sequence cursors, or change user `localId` values.
  Persisted Codex `streamId` completes its preview; delayed snapshots cannot
  resurrect it. Leaving the chat, backgrounding, or resetting the runtime
  clears previews and their timers.
- **Stacked chats hand visibility back** — every mounted `ChatScreen` claims
  its session (`claimSessionVisibility`) and releases it in
  `onSessionInvisible`. Closing the top chat returns the visible slot to the
  chat underneath and probes its messages; a covered chat must never be left
  on screen without the slot, or resume and reconnect skip it.
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
- **Network recovery preserves writes** — retire stale HTTP pools after their
  active responses drain. Older-history retries keep the same end boundary
  when reducing page size; failed pages never advance the cursor. Machine RPC
  discovery, encryption, ACK and decode share one timeout; only explicitly
  idempotent mutations may automatically retry routing failures.
- **Codex speed is session-scoped** — composer Standard/Fast changes apply
  through the pending configuration restart on the next message. Keep speed
  independent of reasoning effort; the global Fast setting is a launch default.
  Ultra fast remains unavailable until the launcher supports its service tier.
- **Provider/model switches must succeed before delivery** — persist picker
  intent until the replacement spawn succeeds, including explicit Default.
  Failed switches preserve a failed row and its `localId`; Retry must apply
  the pending configuration before queuing delivery to the session.
- **Per-session sends are FIFO** — foreground sends and outbox retries share
  one serialized delivery lane; pending heads retain priority across backoff.
  Confirmed `sent` state is monotonic. Account/server buckets never auto-adopt
  legacy ownerless entries; retain and count them pending explicit recovery.
- **Explicit scrollback stays bounded** — retain the older window and live tail
  with a visible unloaded-history gap. Persist only the contiguous latest tail
  and its cursor, including retired-runtime shutdown flushes. Preserve full
  wire-sequence display groups; an indivisible oversize envelope fails pagination
  explicitly without cursor advancement or automatic refetch.
- **Merge fast paths validate the whole batch** — incoming IDs must be unique
  across the resident window and batch; ordering checks use final replacements.
- **Suspended outboxes stay suspended** — late retry failures must not rearm
  timers. Async restore/add completions are scoped to their runtime generation.
- **Settings mutations stay ordered** — single and batched provider updates
  share a persistence/sync queue; storage reads, hydration, and writes share
  another queue. Internal storage helpers must not re-enter the public queue.
  Server writes combine quick local edits for 2.5s with a 6s ceiling; a
  direct sync cancels that timer. Suspension cancels the timers while keeping
  pending edits for resume.
- **Draft ownership follows the session** — flush before changing sessions or
  controllers and before disposal; delayed loads cannot overwrite newer input.
  `DraftAutoSave` owns debouncing; `DraftStorage` must persist its final write
  immediately instead of scheduling a second MMKV timer.

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

## Coding Standards

- **Strict typing:** `implicit-casts: false`, `implicit-dynamic: false`
- **Line length:** 80 chars max; file size: 800 lines max (exclude `*.g.dart`)
- **CI-blocking errors:** `missing_required_param`, `missing_return`, `must_be_immutable`
- **Formatting:** run `scripts/format.sh` before committing; CI's `analyze` job fails on unformatted Dart. Generated files are excluded (codegen diffs them) — never `dart format` them by hand
- **Prefer:** const constructors, final fields, single quotes, spread collections
- **Avoid:** `print` — use `logger.info/warning/error()`; use `unawaited()` for fire-and-forget
- **Platform code:** Conditional exports: `platform_io.dart`/`platform_stub.dart`, `mmkv_storage_native.dart`/`mmkv_storage_web.dart`, `sodium_loader_native.dart`/`sodium_loader_web.dart`, `sentry_*.dart`
- **Sync part files:** `lib/core/services/_sync_*.dart` — add new methods to the appropriate part file
- **Models:** `freezed` + `json_serializable` for core models, manual `fromJson`/`toJson`/`copyWith` for a few simple ones (see Models section). Never hand-edit generated files — run build_runner. Timestamps are integers (milliseconds), not `DateTime`
- **Error handling:** Log via `logger.warning`/`logger.error`. For data loss/corruption risks, also call `Sentry.captureException`

**Analysis:** `test/**/*.dart` excluded. CI runs `flutter analyze --no-fatal-infos --no-fatal-warnings` (errors only block build).

## Additional Documentation

| Doc | Purpose |
|-----|---------|
| `docs/SYNC_PATTERNS.md` | Sync subscription templates and InvalidateSync usage |
| @ROADMAP.md | Production bugs, sprint priorities, feature status |
| @docs/AGENTS.md | Repository-local agent instructions for docs-specific overrides |
| `docs/ARCHITECTURE.md` | Architecture review (Sync god object, known issues) |
| `docs/` | 13 internal docs on security, protocol, UI/UX, sync, and operations, plus `docs/book/` (15 chapters) |

## Focused references

Read the reference for the area you will change before editing it; its constraints
remain mandatory within that scope. Open relevant sections rather than loading
every reference. Verify current behavior in source and configuration.

- [Inspecting a Session's Wire Data (CLI)](agent-reference/03-inspecting-a-session-s-wire-data-cli.md)
- [Production Issues / GlitchTip](agent-reference/04-production-issues-glitchtip.md)
- [Common Commands](agent-reference/10-common-commands.md)
- [Architecture](agent-reference/11-architecture.md)
- [Models](agent-reference/12-models.md)
- [UI Conventions](agent-reference/13-ui-conventions.md)
- [Testing](agent-reference/14-testing.md)
- [Dependency Overrides](agent-reference/16-dependency-overrides.md)
- [Logs & Metrics — Observability](agent-reference/18-logs-metrics-observability.md)

Keep instruction files below 24 KiB and the inherited project chain below 28 KiB.
Move details into focused references instead of raising the context limit.
