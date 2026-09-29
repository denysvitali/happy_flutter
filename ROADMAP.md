# Roadmap

This roadmap tracks upcoming features and improvements for **happy_flutter**.

**Last Updated**: 2026-09-29

Keep this file to live priorities, open production bugs, and status. Git history
has the fixes.

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
| Out-of-order delivery tests | Done | Coverage for REST success before a later socket echo, REST success before a later fetch overlap (`message_deduplication_e2e_test.dart`), socket echo before REST (`socket_echo_before_rest_e2e_test.dart`), socket echo before a tail/history fetch plus duplicate socket re-broadcast sequencing (`socket_echo_before_fetch_e2e_test.dart`), and a hidden-chat socket seq jump recovering from its pre-burst cursor without duplicating the overlapping row. Cached windows persisted by older builds also get one bounded repair overlap after upgrade (`socket_inline_message_e2e_test.dart`). |
| Core messaging state-machine tests | Done | FSM contract suite at `test/fsm/message_state_machine_contract_test.dart` pins `draft -> sending -> sent/pending/failed -> merged` for both the typed `MessageStateTransitions` spec (Draft→Sending, Sending→Sent/Pending/Failed, Pending→Sent/Failed, Failed→Sending, Sent→Merged) and the subset implemented by the `MessageStateMachine.apply` event-log projection (no explicit Draft/Pending entry or separate Sent intermediate). Every legal transition asserts `localId` identity; illegal/no-op transitions (double-optimistic, optimistic-after-merge, retry-on-merged/sending/null, fail-on-merged, missing-localId, ack/merge without serverId) are pinned as strict no-ops or `ArgumentError`s. End-to-end lifecycle walk and two-identical-`continue`-sends-with-distinct-localIds are covered. |
| User-visible core E2E scenarios | In Progress | Sync integration suites cover rapid follow-ups, background/resume, disconnected sockets with REST persistence, and sends while thinking. Widget regressions cover queued-to-delivered state, permission tap/retry/navigation races, and opening the first newly joined Live wire session. Device/browser coverage connecting the app to the real Go server and deterministic provider remains outstanding. |
| Invariant telemetry | In Progress | Triage 2026-08-27 (issues 8592/8594) closed the third `unmatched_optimistic` false-positive hole: the invariant now requires an in-process mint (`_sentAtMs`), so socket echoes of seeded, non-resident ids (re-broadcasts, other devices' sends, evicted rows) stay silent. Audit 2026-08-25 fixed the production build-267200 burst (~198 `unmatched_optimistic`): the `fetchMessages` pre-page loop acked known-but-not-resident history ids before merging their page; it now seeds identity/outbox state only, so history is never treated as a send ack (`test/services/message_ack_cache_truncation_test.dart`). Triage 2026-08-26 (issue 8566) fixed the sibling false positive: a 24-attempt outbox retry acked right after the session was archived (resident rows cleared), correctly delivering the message but tripping `unmatched_optimistic` — `recordAck` now takes `sessionResidentRowCount` and suppresses the violation when the client holds zero rows for the session (restart / idle-shrink / archived clear); duplicate and unknown-acked checks are unaffected (`test/utils/message_invariant_monitor_test.dart`). Earlier audits removed foreign-history unknown-ack noise and shipped restart-safe seeding, per-localId ack dedupe, all four counters, denominators, and the send tap→ack histogram; the `> 0` Prometheus alert rules remain under the monitoring HA item. |

### Open production bugs (GlitchTip)

"Verify" rows shipped in source and await rollout evidence.

| Issue | Severity | Count | Status | Description |
|-------|----------|-------|--------|-------------|
| Live wire shows old sessions/messages as new | User-visible misinformation | Screenshot: 17 rows at one refresh time | Fix in source; verify after rollout | Snapshot diffs treated sessions loaded into the active collection and cached previews hydrated after mount as new events, then stamped them with observation time. Live wire now requires activity after its mounted baseline and within two hours, and displays the source activity timestamp. |
| Startup-resume teardown null check (3604 / 8785) | Fatal / warning | 2,086 / 2 | Fix in this source batch; verify after build 286800 rollout | The Sep-23 286800 event has no Dart symbols. GlitchTip breadcrumbs show the RPC returned `handler_offline`; Jaeger records a Session Info pop at 19:55:53 in the same app launch. The catch then evaluated `context.l10n` before `_showError` could check `mounted`. The localized message now resolves before the async gap; the underlying disconnected-machine save still surfaces an error when the screen is present. |
| Pending sidechain results exceed cap (8880–8883) | Warning with visible tool-output loss | 4 recent fingerprints | Fix in this source batch; verify drop counter after rollout | Results whose parent Task has left the resident message window cannot be rendered. The merge path now drops only those orphan sidechain results before they evict results waiting for resident tool calls; a result still queues when its Task remains resident. |
| Readiness-deferred send reaches terminal session | Failed-send recovery | Regression coverage added | Fix in this source batch; verify after rollout | A terminal lifecycle update now moves readiness-deferred sends to the dead-letter retry bucket, preserving the canonical `localId` and encrypted payload for explicit retry. |
| Model pick absent from active custom profile (8875) | Warning / model fallback | 5 | Open — profile and picker state need reconciliation | Build 286800 selected `cloudflare/stealth/union-alpha[1m]` for a custom Claude gateway profile whose `models` list does not contain that model. The safety guard uses the profile default rather than sending an unowned model; verify profile hydration and picker eligibility before changing the fallback. |
| Spawn preparation deadline (8874) | Error | 1 | Open — server-side preparation path | Build 286800 timed out posting `/v1/sessions/:id/spawn-init` while preparing a session. The Flutter client reports the RPC failure; this event does not identify a client-side defect. |
| Committed batch prefix misses live notification | P0 | 2 store deadlines / audit 24h; loss not proven | Source fix `happy-cli-go a9ef61a`; verify rollout | Failed later chunks used to discard prior committed results; retry deduplication suppressed their notification. Deterministic contract now covers prefix fanout and retry identity. |
| Expected machine-refresh suspension reported as error (8771/8772) | Error telemetry | 6 lifetime | Source fix `b2c46d1c` / `3373d1a5`; verify rollout | Build 277800 cancellation is now typed and logged without an error span; cached machines and retry state survive. True deadline failures remain errors. |
| Machine RPC timeout / slow ping (3702/3627) | Warning | Current-build recurrence | Open — verify Bash cleanup and deployed routing | Build 277900 Bash ACK timeout at 30s correlates with server Redis retries. Go `f513cc9` fixes independently reproduced descendant pipe hangs; causality for the live RPC remains unproven. See September 8 audit. |
| Send target resolution / default-profile respawn (5198) | Warning | 161 issue total | Open — P1 investigation | Build 276300: 3.16s target resolution versus 64ms POST; Loki correlates capability RPC forward retry. Verify profile identity and routing separately. |
| Stack overflow (8750) | Error | 1 | Open — exact-build symbols expired | Build 275100 already contains d3185a0e. CI run 33612731392 artifact 9839878457 returns HTTP 410; release assets contain no matching Dart symbols. Native addresses cannot safely be mapped using another build. |
| Home UTF-16 rendering crash recurrence | Error | 4 events on 279300 | Fixed in source; awaiting CI and device rollout | Issues 8777/8779 on Sep 9 share a trace after returning from Codex usage to Home and retrying. Symbolized stack confirms paragraph layout failure. Fixed unsafe UTF-16 cuts in session previews, tool hints, and profile initials; added emoji/grapheme regression coverage. Exact source widget is absent from the production stack; Loki trace query returned no logs. |
| Session says running but daemon has no process | Warning when blocked; recovered history is info | 6 warnings / 5 sessions on 273300, issue 8679 count 4 through build 273700, plus the earlier 27-event burst | Daemon/server fix 4f66380; Flutter telemetry fix on main; post-deploy verification pending | Issues 8623/8626/8654/8674/8675 span multiple sessions. Same-window daemon logs show metadata-version CAS races, failed lifecycle marks, stale-session reconciliation, and zero live processes. The latest 8679 event at 17:41 UTC was recoverable: Loki shows restore, send acceptance, and a response. Local graceful restarts wrote an exact handoff marker that the replacement daemon ignored while startup respawn was disabled. happy-cli-go 4f66380 resumes only recent exact handoffs, fences late host-PID and canceled-generation writes, and removes message-ingest lifecycle claims. Flutter keeps `hasLifecycleError` terminal across readiness/send gates and now logs restorable history at info while retaining warnings for sessions with no restore target. A runtime epoch/lease remains useful defense-in-depth; close the issues only after clean post-deploy evidence. |
| `[Perf] sessions UI state compute` at extreme catalogs | Warning | 2 (one device, 463–465 sessions) | Open — needs its own measured pass | Issues 8589/8590 (2026-08-27): `trigger=single changed=1` 209 ms and `trigger=sessions_and_messages changed=3` 211 ms at 465 sessions. The single path pays a 465-entry map copy + ordering/MissionControl reconcile; the all-sessions path walks every entry (~0.45 ms each) even when only 3 changed — incremental reconciliation is the fix shape, not a same-day patch. Re-check the fleet tail via `app.sessions.ui_state_compute` by `session_count_bucket` before designing. |
| `[machineRPC] SLOW method=ping/get-codex-models/rpc-capabilities` | Warning | 254 / 271 / 80 since 2026-06-13 | Open — daemon-side, observability signal | Wedged/slow daemons answering machine RPCs above the slow threshold. `ping` slowness is the designed wedged-daemon detector (12 s pre-flight probe, 2026-06-09 fix); `get-codex-models` slowness feeds the coalescing model-catalog cache. No client defect; candidate for demoting per-session repeats to a rate-limited summary once the daemon fleet updates. |
| CryptoSecretBox.decrypt failed | Warning | 27 | DEK refresh implemented (`913d667f`); telemetry retained | Audit 2026-06-09: leading hypothesis is DEK decryption failing in `fetchSessions` → client silently falls back to legacy NaCl master secret → AES-256-GCM messages then fail MAC check (`stage=sodium`, `envelope=aesV0`). Added once-per-session Sentry capture (`dek_fallback_session` tag) when DEK decryption falls back, so fallback sessions can be correlated with `decrypt_scope=session:<id>:messages` failures. DEK refresh after rotation is now implemented (`913d667f`); use the retained telemetry to check for any remaining fallback/decryption failures. |
| RenderBox was not laid out (release StateError) | Error | 38 unresolved groups | Web focus guard added; old native reports unattributed | 34 web groups share the focus-geometry stack shape; the 286500 map identifies reading-order traversal. Historical maps expired, so exact old-build mapping is unavailable. Four native groups (3547/3526/3524/3520) remain unverified; three lack event bodies. |

### Performance (from GlitchTip)

| Metric | Value | Target | Notes |
|--------|-------|--------|-------|
| App cold start (`essential_ready`) | Build 272600 mean 0.17s, p95 0.25s (68 samples); 30d fleet mean 0.90s, p95 2.34s | < 3s avg | Target met. The previous 4.6s Sentry baseline is obsolete. OTel uses delta temporality on per-launch streams, so aggregate one-shot histogram samples with `sum_over_time`, not `rate`/`increase`. |
| Successful send end-to-end | Build 272600 mean 4.32s, p95 reaches 30s bucket (841 observations) | < 1s p95 when runtime is ready | Server POST `/v3/sessions/{id}/messages` p95 is about 35ms with no 500s. The delay is before/around the POST: readiness waits, restore/respawn, FIFO serialization, and outbox handoff. Split the histogram by `ready`, `restored`, `queued`, and `backgrounded` phases. |
| App RSS | Build 272600 p95 2.02GB in the 101–250 session bucket; one launch averages 2.01GB in chat with 34 resident rows | < 768MB p95 | Image cache (~0.005MB), encryption cache (~0.05MB), and resident-row count rule out the three instrumented suspects on the outlier. Add Dart heap, external/native allocation, retained tool-output bytes, workflow projection bytes, and route-transition snapshots. |
| fetchMessages p95 | avg 33–50ms (Prometheus, 2026-07-28) | < 5s | Was "up to 54s"; `app_fetch_messages_seconds` now shows 0.033s visible / 0.050s background. Target met — the 54s figure predates the pagination work. |
| Chat UI-isolate stalls (2026-09-29) | 2,769 frozen frames / 24h from one Android phone (build 291200, 201 sessions), 2,399 `blocker=untracked` `stall_phase=vsync` on chat, median 160 ms | none untracked | Build/raster stay under 12 ms; the isolate is blocked before build. `chat.refresh_from_sync`, `chat.build_list_items` and `socket.new_message` now register with `MainIsolateStallTracker`; re-read `blocker` labels after rollout. Sync FFI crypto calls (`native_core.*_sync`) are tracked too, and a vsync wait within 3 s of attach is labelled `post_resume` (Android thaws the process late; home-route 1.2–1.3 s stalls with 0 sessions match this). Separately, `GET /v2/sessions` spent 15.5 s in `http.transport.headers_ms` against 12 ms of server work, and a 200-row message page spent 5.7 s in body transfer (server 37 ms): first-page size on slow links is the open lever. No Linux OS label exists on frame metrics yet. |
| Deferred init | avg 2.5s | < 1s | `app.deferred_init` histogram (the Sentry `app.deferredInit` transaction agrees). Still the largest startup cost — audit what's loaded eagerly. |
| Sessions frozen-frame p95 | 388 ms on `home` / 7d (69 frozen frames); build 245500 Mission Control max 175 ms | < 100 ms, no growth by session bucket/view | `session_count_bucket` proved the build-245500 recurrence was at 200 sessions; `sessions.mission_control.model` disproved grouping as the remaining bottleneck. Frame metrics now also label `sessions_view`, and `app.ui.frozen_frame_build` / `app.ui.frozen_frame_raster` split future freezes into UI-build versus GPU-raster cost. Re-baseline after lazy workspaces and bounded activity animation reach production. |
| Current frozen-frame rate | Build 272600 0.0093% of frames, p95 0.74s; about 4x 272400 and 3x 272500 | < 0.001%, p95 < 100ms | Early 272600 data is dominated by one 251+ session launch. Chat contributes most events; `message-detail` and home contain the longest frames. Re-check after a full build window and correlate `frozen_frame_build`/`raster` with RSS and tool-output size. |
| Foreground battery draw | 838 mAh over 3 h 40 m foreground (228 mA avg) on one Android device, 2026-08-15; background 14 mAh over 15 h 36 m (0.90 mA) | no rendering while the UI is at rest | Background draw is already negligible; the cost is foreground. Over the same 24 h the fleet rendered 814,125 frames (769,790 on `chat`, 44,331 on `home`) — ~62 fps averaged across the entire foreground window, i.e. the UI never idles. **Driver identified**: `buildChatStatusChips` hardcoded `pulse: true` on the ready/"Online" app-bar chip, so a 1.5 s repeating `AnimationController` ticked at 60 fps for as long as any chat stayed open — the resting state, i.e. ~all foreground time. Fixed by `pulse: false` for the steady online state, matching `SessionStatus.isPulsing` (pulse only for transient thinking/permission-required) and the sidebar/voice-bar `ConnectionStatus.connecting` convention. `app.ui.window_frames` / `app.ui.render_windows` (shipped in 258200) split every 30 s window by `activity` (`idle` = zero pointer events and zero Sync change) and `window_fps_bucket` to confirm the fix and catch any remaining idle renderer. Re-baseline frame count once 2582xx reaches the fleet. |

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
| Persist messages to MMKV | Done | `MessageCacheService` caches the last 200 messages per session in MMKV. Warm in-memory rows paint first; native cache read/decrypt/JSON and routine save preparation run in workers. Writes debounce for 5s with a 15s ceiling, skip unchanged revisions, and flush synchronously on suspend. Linux checks once after startup and compacts MMKV off-isolate when the mapped file is materially sparse. |
| Offline message outbox | Done | `MessageOutbox` service persists failed sends to MMKV with exponential backoff retry (1s→2s→4s→max 30s). Restored on startup via `restoreAndFlush()`. Audit 2026-08-03 found the flat ~40s budget dead-lettered sends during brownouts longer than a minute (4 messages permanently lost, zero signal); shipped in d8dba9ac: failure-class-aware budgets (transient retries ~4h, permanent dead-letters after 3), reconnect/foreground/cold-start re-arm of transient dead letters, and a `dead_lettered` counter + Sentry capture (see the audit section). |

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
| Audio recording | Done | Voice input for chat implemented |

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
| Settings | Done | Language, voice, agents & tools, features, profiles, usage, developer, machines, changelog, Claude Connect; declarative hub with search; theme picker inline; server settings reachable from the hub (20 screens) |
| Tool Rendering | Done | 29 tool-specific views (incl. Codex MCP prompt view), KnownTools registry (60+ variants), PermissionFooter, elapsed time, auto-collapse, tool error display |
| Logging | Done | `LoggerService` (5000-entry circular buffer), `DevLogsScreen` (filter/search/copy/clear), Sentry forwarding, `RemoteLogger`, `ErrorBoundary`, `ErrorSnackbarManager` |
| UI Components | Done | Shimmer loading, command palette, diff view, tab bar, avatars, status bar theming |
| Dev Tools | Done | Dev logs, encryption debug, network inspector, notification test, session debug |
| i18n | Partial | Framework in place (`flutter: generate: true`). **English only** — one ARB file, `l10n/app_en.arb` (note: `arb-dir: l10n` in `l10n.yaml`, not `lib/l10n`), generated into `lib/l10n_generated/`. No other locale exists yet; adding one means adding `l10n/app_<code>.arb`. |
| CI/CD | Done | Multi-job pipeline (analyze, test + coverage, builds, release, web deploy), caching, automatic per-commit releases to GitHub (Dart obfuscation dropped 2026-08-26 — open-source app), Codecov |
| Native | Partial | TTS and audio recording implemented; video call and push stubs; biometric auth not started |

---

## Next Steps

1. **Note**: Releases are automatic — every commit to `main` publishes a GitHub Release. A fix on `main` has shipped; there is no tagging step.
2. **P0**: Finish the contract-test rows above (identity, repeated sends, real-server E2E).
3. **Verify after rollout**: the "Verify" rows in Open production bugs.
4. **Open investigations**: model/profile mismatch (8875), default-profile respawn (5198), `CryptoSecretBox.decrypt failed` telemetry, resident-row memory (RSS 1.8GB).
5. **Later**: sidebar navigation for tablet/desktop.

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Guard offline machine in NewSessionDialog | Done | Implemented with offline feedback, preflight reachability, and regression tests. |
| Streaming cursor in assistant bubble | Low | Makes AI response feel continuous vs discrete jumps |
