# Roadmap

This roadmap tracks upcoming features and improvements for **happy_flutter**.

**Last Updated**: 2026-07-24

### July 2026 performance and design pass

- Scoped background workflow refresh to visible/recent online sessions with
  deduplication, unsupported-capability caching, and exponential backoff.
- Added aggregate frame, startup, message-fetch, optimistic-row, and chat-list
  OpenTelemetry metrics.
- Isolated chat header/activity, message-pane, and composer rebuild regions.
- Added actionable stuck-agent notifications with Nudge, Abort, and Reply.
- Added explicit reconnect/stopping UX, clearer composer configuration labels,
  quieter session-card hierarchy, full-screen code reading, and tablet
  auto-selection.
- Added injectable message and workflow repository boundaries.

## P0: Core Messaging & Session Reliability

The app lives or dies on one invariant:

`one user tap -> one stable localId -> one optimistic row -> one persisted message -> one retry identity -> one final merged message`

The current test count is not enough if this contract can break without failing CI. Before adding more feature work, the core send path needs explicit contract coverage.

### Immediate Test Priorities

| Task | Status | Description |
|------|--------|-------------|
| Canonical message identity contract tests | In Progress | Add a dedicated suite that asserts a single `localId` survives optimistic UI, REST send, socket forwarding, outbox retry, server ack, and merge. |
| Repeated identical send tests | In Progress | Cover `continue`/same-text repeated sends and prove they produce distinct `localId`s and distinct logical messages. |
| Optimistic replacement invariants | Done | Added contract coverage asserting that server-acked messages replace the exact optimistic placeholder by `localId`, never by text similarity or list position, including repeated identical user text. |
| Retry identity invariants | Done | Added contract coverage proving explicit retry preserves the original `localId` and logical message, while a fresh user resend creates a new `localId` and a second logical message. |
| Out-of-order delivery tests | Done | Coverage for REST success before a later socket echo, REST success before a later fetch overlap (`message_deduplication_e2e_test.dart`), socket echo before REST (`socket_echo_before_rest_e2e_test.dart`), and socket echo before a tail/history fetch plus duplicate socket re-broadcast sequencing — including broadcast-then-fetch overlap (`socket_echo_before_fetch_e2e_test.dart`). |
| Core messaging state-machine tests | Done | FSM contract suite at `test/fsm/message_state_machine_contract_test.dart` pins `draft -> sending -> sent/pending/failed -> merged` for both the typed `MessageStateTransitions` spec (Draft→Sending, Sending→Sent/Pending/Failed, Pending→Sent/Failed, Failed→Sending, Sent→Merged) and the `MessageStateMachine.apply` event-log projection. Every legal transition asserts `localId` identity; illegal/no-op transitions (double-optimistic, optimistic-after-merge, retry-on-merged/sending/null, fail-on-merged, missing-localId, ack/merge without serverId) are pinned as strict no-ops or `ArgumentError`s. End-to-end lifecycle walk and two-identical-`continue`-sends-with-distinct-localIds are covered. |
| User-visible core E2E scenarios | Not Started | Add E2E coverage for rapid follow-ups, background/resume mid-send, disconnected socket with successful REST persistence, and follow-up sends while the agent is still thinking. |
| Invariant telemetry | Not Started | Emit counters/logs for unmatched optimistic rows, duplicate `localId`s, unknown acked `localId`s, and retry-created duplicates. |

### Production Bugs (from GlitchTip, May 2026)

| Issue | Severity | Count | Status | Description |
|-------|----------|-------|--------|-------------|
| InvalidateSync disposed crash | Fatal | 55 | Shipped in v1.0.0-154901 (1ba4ebc) | App suspend races with in-flight `invalidateAndAwait()`; `dispose()` now completes normally instead of throwing `StateError`. |
| Null check operator (chat load) | Fatal | 9 | Shipped in v1.0.0-154901 (51f1189) | `session!.permissionMode!` and `selectedProfile!.defaultModelMode` force-unwraps in `_loadInitialSettings` when async gap allowed session/profile to become null. Fixed with safe pattern-matching (`case final x?`). Residual GlitchTip events (HAPPY_FLUTTER-17O/3C0/382) are historical aggregate; no new shape identified in audit 2026-05-22. |
| Null check operator (general) | Error | 12 | Shipped in v1.0.0-154901 (51f1189) | Same root cause as above. |
| Isolate unsendable Future | Error | 3 | Shipped in v1.0.0-152XXX+ (7b69d1b, 84ff0c2) | `Isolate.run` closure was capturing `this` in offline TTS / AES decrypt isolates; switched to top-level worker with sendable POD args. |
| ttsUseOffline unknown settings key | Fatal | 1 | Shipped in v1.0.0-XXXX (e051f35); telemetry b7cee41 on main | Settings dispatcher dropped unknown legacy keys instead of throwing; Sentry breadcrumb now captures dropped keys for context. |
| sherpa-onnx not initialized (TTS fallback noise) | Warning | 4 | Fix on main (9135fbd), shipped automatically on the next `main` commit | `OfflineTtsService` now records FFI probe failures and short-circuits to system TTS via typed `OfflineTtsException`; one info breadcrumb per process replaces ~one Sentry capture per `speak()`. |
| Sidechain orphans absorbed | Warning | 100+ | Fix on main (35db8c4), shipped automatically on the next `main` commit | Sentry capture gated to `triedFetchOlder && hasMoreOlder && count≥5`; normal happy-path absorption now local-info-only. |
| Resume sessions sync timeout | Error | 6 | Fix on main (0621440), shipped automatically on the next `main` commit | `TimeoutException` on resume is now caught and logged at info; underlying sync still completes via `onDataChanged`. |
| Resume conversation progress timeout | Warning | 6 | Fix on main (0621440), shipped automatically on the next `main` commit | Safety-timer fallback demoted from Sentry warning to local info log. |
| Ref used in disposed widget (sessions dismissible) | Error | 1 | Fix on main (6a4776b), shipped automatically on the next `main` commit | `ref.read` and `context.l10n` hoisted before `showDialog` await in `session_dismissible.dart` so swipe-and-unmount can't trigger StateError. |
| Back button error rate | Error | 3/8 (37.5%) | Fixed on main (ec102e5, 2bca2c8, bd011fd), shipped automatically on the next `main` commit | `StandardComponentType.backButton` `ui.action.click` transaction (GlitchTip transaction-group id 29). Two root causes addressed: (1) `PopScope` races where `canPop` was evaluated at build time but the callback ran later — fixed in `sessions_screen.dart`, `chat_screen.dart`, `edit_artifact_screen.dart`, and `voice_language_settings_screen.dart` by reading current state at callback time and adding `_pendingNav` / `_isPopping` guards; (2) bare `context.pop()` on deep-linked screens with an empty stack — fixed with `safePop()` helper in `lib/core/utils/safe_pop.dart` that checks `context.mounted` + `context.canPop()` and falls back to a named route, with widget tests in `test/core/utils/safe_pop_test.dart`. Transaction group last received an error 2026-04-03, before both fixes landed; no new occurrences as of audit 2026-05-22. |
| ANR (foreground `nativePollOnce` + background `__sfvwrite`) | Fatal | 2 | Open — awaiting next event with body | First ANRs ever captured 2026-06-09 (HAPPY_FLUTTER-3D6/3D7), but event bodies were lost server-side: GlitchTip's worker scheduler died silently ~2026-05-28, daily Postgres partitions ran out 2026-06-04, and every event until 2026-06-09 18:30 UTC was DLQ'd with `no partition of relation issue_events_issueevent found for row` (issues got metadata only). Server recovered when the payload-cap deploy restarted the worker; k2-gitops 5ca1e85 adds a daily `maintain_partitions` CronJob safety net; pipeline verified end-to-end with a test event. Next ANR will arrive with a full thread dump — diagnose the main-thread blocker then. |
| CryptoSecretBox.decrypt failed | Warning | 27 | Telemetry on main, shipped automatically on the next `main` commit | Audit 2026-06-09: leading hypothesis is DEK decryption failing in `fetchSessions` → client silently falls back to legacy NaCl master secret → AES-256-GCM messages then fail MAC check (`stage=sodium`, `envelope=aesV0`). Added once-per-session Sentry capture (`dek_fallback_session` tag) when DEK decryption falls back, so fallback sessions can be correlated with `decrypt_scope=session:<id>:messages` failures. Next: confirm correlation in GlitchTip, then fix key refresh (cached `_sessionDataKeys` is never refreshed after rotation). |
| Stale profile in ChatScreen | Warning | 9 | Shipped in v1.0.0-154901 (51f1189) | `_loadInitialSettings` now catches `StateError` from `firstWhere` and falls back to no profile, clearing the stale `savedProfileId` from `DraftStorage`. |
| Machine offline on session create | Warning | 33 | Fix on main, shipped automatically on the next `main` commit | NewSessionDialog disables offline machines and gates the create button (`newSessionCreateBlocker`). Remaining failure mode — machine heartbeat fresh but daemon wedged (60 s `SocketAckTimeoutException` on `spawn-happy-session`, seen 2026-06-09) — addressed with a 12 s pre-flight `ping` probe in `createSession` (`ensureMachineReachable`); daemon-side `ping` handler added in happy-cli-go (old daemons answer `Method not found`, which also proves liveness). |
| Spawn readiness timeout (single Loki WARN) | Warning | 1 / 24h | Fix on main, shipped automatically on the next `main` commit | `sendMessage` waited the full 15 s spawn-readiness budget without seeing presence come online, then sent anyway. Promoted the warn to a structured `Sentry.captureMessage` (`sessionId` / `spawnedAt` / `waitMs` / `recentlySpawned` hint fields, level `warning`) and bumped an OTel counter (`app.session.spawn_timeout` via `PowerDiagnosticsOtelReporter.recordAppError`) so the single occurrence becomes a rate-able signal. Magic numbers (15 000 / 30 000) replaced with `Sync.recentlySpawnedWaitMs` and `Sync.recentlySpawnedFlagMs`; all four `_sessionSpawned*` map writes funnelled through a single `_registerSpawn(sessionId, {profileId, modelMode, agent, at})` helper so `wasRecentlySpawned` anchors on the same time regardless of entry path (recovered `found.createdAt` vs. local `DateTime.now()`). Regression test: `test/services/sync_service_spawn_readiness_timeout_test.dart`. |
| RenderBox was not laid out (release StateError) | Error | 3 | Open — awaiting symbolicated event | New issues 2026-06-09 (HAPPY_FLUTTER-3D4/3D2/3CU): `StateError: Bad state: RenderBox was not laid out: <obfuscated>#…` thrown by Flutter 3.41 `RenderBox.size` in release builds (box.dart:2304). Likely unmasked by 12028a45 (Sentry filtering removed) rather than newly introduced. App-level `.size` readers (`session_cards.dart` Hero shuttle, `tool_view_widgets.dart` CollapsibleOutput) already guard `hasSize`; framework Hero `_boundingBoxFor` is the main unguarded candidate (session-avatar Hero is the only Hero pair). Debug symbols upload to Sentry since 12028a45, so the next occurrence will carry a symbolicated stack — pin the culprit then. |
| fetchMessages dropped (output filter) | Warning | ~180 | Fix on main, shipped automatically on the next `main` commit | Audit found every unresolved issue in this cohort comes from old builds (`1.0.0+97201` / `+1`) whose parser predated the top-level `dataType=tool-result` handler and the per-page summarizer dedupe. Current parser already routes the production-shape envelope (`callId`+`id`+`output`+`isError`+`parentUuid`+`permissions`+`type`) through `_isToolResultEnvelope`/`_addToolResultEnvelope`; added a contract test pinning the exact production shape and a telemetry split so known-skip categories (`assistant content list is empty`, `unrecognized output content block`, `user content block type=X not handled`, `pi result with no tool rows`) log at info-level while unknown `dataType`s stay at warning. |

### Performance (from GlitchTip)

| Metric | Value | Target | Notes |
|--------|-------|--------|-------|
| App cold start (`root /`) | avg 4.6s, p95 9.3s | < 3s avg | Includes deferred init (1.9s avg). Profile on real device to find bottlenecks. |
| fetchMessages p95 | up to 54s (outlier sessions) | < 5s | Sessions with very large message histories. Consider pagination limits or incremental fetch. |
| Deferred init | avg 1.9s | < 1s | `app.deferredInit` transaction — audit what's being loaded eagerly. |

### Engineering Rule

For core chat flows, no layer may invent a second message identity when a canonical `localId` already exists. UI, sync, retry, and merge code must all use the same identifier.

## Project Context

- **Flutter Version**: 3.41.x via mise (3.41.9 / Dart 3.11.5 / Java 21)

---

## Priority Levels

- **P0**: Critical - Blocking features or security issues
- **P1**: High - Core functionality users expect
- **P2**: Medium - Enhanced user experience
- **P3**: Low - Nice to have, polish features

---

## P1: High Priority

*All P1 items completed.*

---

## P2: Enhanced Features

### 3. Offline & Performance

| Task | Status | Description |
|------|--------|-------------|
| Persist messages to MMKV | Done | `MessageCacheService` caches last 200 messages per session in MMKV. Loaded on app start via `_restoreAllCachedMessages()`. Debounced writes (500ms) via `_scheduleSaveMessages()`. |
| Offline message outbox | Done | `MessageOutbox` service persists failed sends to MMKV with exponential backoff retry (1s→2s→4s→max 30s, max 3 retries). Restored on startup via `restoreAndFlush()`. |

### 4. Optimistic Mutations

| Task | Status | Description |
|------|--------|-------------|
| Optimistic mutation layer | Done | `OptimisticMutation<T>` primitive in `lib/core/utils/optimistic_mutation.dart` (apply → act → rollback-on-error, tested in `test/utils/optimistic_mutation_test.dart`). Adopted for the destructive high-traffic paths: session delete (`SessionsNotifier.optimisticDelete` / `optimisticBatchDelete` — swipe-dismiss, session info, chat dialogs, batch select) and artifact delete (`ArtifactsNotifier.optimisticRemove` — detail screen pops immediately, rolls back + snackbar on failure). Message send already has its own optimistic path (`localId` contract). |

### 5. Sidebar Navigation

| Task | Status | Description |
|------|--------|-------------|
| Collapsible sidebar | Not Started | Tab bar exists but no sidebar for tablet/desktop layouts. Referenced in multiple RN components. |

---

## P3: Polish Features

### 6. Native Platform Integrations

| Task | Status | Description |
|------|--------|-------------|
| WebRTC/LiveKit | Partial | `video_call_service.dart` exists with stubs |
| Push notifications | Partial | Service exists, notification test screen in dev tools |
| Biometric auth | Not Started | Face ID, Touch ID, fingerprint |
| Audio recording | Not Started | Voice input for chat |

**References**:
- React Native: `@livekit/react-native-webrtc`, `expo-camera`, `expo-notifications`, `expo-local-authentication`

### 7. CI/CD Enhancements

| Task | Status | Description |
|------|--------|-------------|
| Test coverage reporting | Done | CI runs `flutter test --coverage` with Codecov upload on every push. |

---

## Progress Tracking

| Category | Status | Notes |
|----------|--------|-------|
| Authentication | Done | QR auth, device linking, account restore, backup key |
| Encryption | Done | AES-256-GCM (new), NaCl/libsodium (legacy), key derivation |
| Chat | Done | Full markdown, syntax highlighting, code blocks, TTS |
| Chat Input | Done | Draft auto-save, @file autocomplete, /command autocomplete, permission mode selector, profile selector, abort |
| Storage | Done | MMKV with migration, drafts, permission modes, FlutterSecureStorage for secrets |
| State | Done | 16 providers, all notifiers implemented |
| WebSocket | Done | Socket.IO with reconnect, inline message fast path, 100ms debounce |
| API | Done | All endpoints with 250+ tests |
| Sessions | Done | Date headers ("Today", "Yesterday"), session cards, status indicators |
| Session Creation | Done | Optimistic placeholder, 60s `_sessionSpawnedAt` registry, 3-attempt recovery in `sendMessage` |
| Settings | Done | Theme, language, voice, features, profiles, usage, developer, server, machines, changelog, Claude Connect (21 screens) |
| Tool Rendering | Done | 29 tool-specific views (incl. Codex MCP prompt view), KnownTools registry (60+ variants), PermissionFooter, elapsed time, auto-collapse, tool error display |
| Logging | Done | `LoggerService` (5000-entry circular buffer), `DevLogsScreen` (filter/search/copy/clear), Sentry forwarding, `RemoteLogger`, `ErrorBoundary`, `ErrorSnackbarManager` |
| UI Components | Done | Shimmer loading, command palette, diff view, tab bar, avatars, status bar theming |
| Dev Tools | Done | Dev logs, encryption debug, network inspector, notification test, session debug |
| i18n | Partial | Framework in place (`flutter: generate: true`). **English only** — one ARB file, `l10n/app_en.arb` (note: `arb-dir: l10n` in `l10n.yaml`, not `lib/l10n`), generated into `lib/l10n_generated/`. No other locale exists yet; adding one means adding `l10n/app_<code>.arb`. |
| CI/CD | Done | 7-job pipeline (analyze, test + coverage, golden, build-debug, build-release, build-web, deploy-web), caching, automatic per-commit releases to GitHub with obfuscation, Codecov |
| Native | Partial | TTS, video call stubs, push stubs — WebRTC/biometric/audio not started |

---

## Next Steps

1. **Note**: Releases are automatic — every commit to `main` publishes a GitHub Release with the production APK. A fix that is on `main` has shipped; there is no manual tagging step and no release backlog.
2. **This sprint**: Verify GlitchTip `StandardComponentType.backButton` error rate stays at 0% now that the PopScope/safePop fixes (ec102e5, 2bca2c8, bd011fd) have shipped
3. **This sprint**: Guard session creation against offline machines (UX warning/disable)
4. **This sprint**: Investigate `CryptoSecretBox.decrypt failed` warnings (27 events)
5. **Next sprint**: Optimistic mutation layer for instant UI feedback
6. **Next sprint**: Profile and reduce cold start time (avg 4.6s → target < 3s)
7. **This quarter**: Sidebar navigation for tablet/desktop

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Guard offline machine in NewSessionDialog | Low | Disable create button or show warning when machine offline — eliminates 33 warnings/day |
| Streaming cursor in assistant bubble | Low | Makes AI response feel continuous vs discrete jumps |
