# Roadmap

This roadmap tracks upcoming features and improvements for **happy_flutter**.

**Last Updated**: 2026-10-04

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
| User-visible core E2E scenarios | In Progress | Sync integration suites cover rapid follow-ups, background/resume, disconnected sockets with REST persistence, and sends while thinking. Widget regressions cover queued-to-delivered state, permission tap/retry/navigation races. Device/browser coverage connecting the app to the real Go server and deterministic provider remains outstanding. |
| Invariant telemetry | In Progress | Triage 2026-08-27 (issues 8592/8594) closed the third `unmatched_optimistic` false-positive hole: the invariant now requires an in-process mint (`_sentAtMs`), so socket echoes of seeded, non-resident ids (re-broadcasts, other devices' sends, evicted rows) stay silent. Audit 2026-08-25 fixed the production build-267200 burst (~198 `unmatched_optimistic`): the `fetchMessages` pre-page loop acked known-but-not-resident history ids before merging their page; it now seeds identity/outbox state only, so history is never treated as a send ack (`test/services/message_ack_cache_truncation_test.dart`). Triage 2026-08-26 (issue 8566) fixed the sibling false positive: a 24-attempt outbox retry acked right after the session was archived (resident rows cleared), correctly delivering the message but tripping `unmatched_optimistic` — `recordAck` now takes `sessionResidentRowCount` and suppresses the violation when the client holds zero rows for the session (restart / idle-shrink / archived clear); duplicate and unknown-acked checks are unaffected (`test/utils/message_invariant_monitor_test.dart`). Earlier audits removed foreign-history unknown-ack noise and shipped restart-safe seeding, per-localId ack dedupe, all four counters, denominators, and the send tap→ack histogram; the `> 0` Prometheus alert rules remain under the monitoring HA item. |

### Open production bugs (GlitchTip)

"Verify" rows shipped in source and await rollout evidence.

| Issue | Severity | Count | Status | Description |
|-------|----------|-------|--------|-------------|
| Post-resume HTTP header stalls | P1 freshness / responsiveness | Two correlated Oct-4 requests on build 300500 | Open — isolate client transport timing | At 12:21 and 14:02 UTC, Loki socket-resume logs precede successful sessions/messages GETs taking 17.55s / 15.63s. Jaeger traces `36703c40991f2dc251c90968a8104cc3` / `b5a2b327b18572ea7800c447011fd42f` show 17.52s / 15.60s header waits versus 31.6ms / 13.1ms server handlers; the latter dispatch and headers are both active lifecycle. Header timing includes DNS, connection, TLS, scheduling and server wait: exact cause remains unproven. Existing pool recovery has not eliminated this observed delay. |
| Offline machine handler blocks provider-switch send (8921–8923) | P1 blocked delivery | One Oct-3 incident; initial attempt plus two logged retry failures | Open — machine routing / handler readiness | Build 300200 at 10:16 UTC reports `handler_offline` for `spawn-happy-session`; the message is explicitly not sent. Preserve the current configuration-before-delivery guard and canonical retry identity. Build 300500 also reports Oct-4 session creation failure and recurring usage-handler failures, with server handler-not-registered warnings; a separate launch has 15s usage / 12s ping ACK timeouts. This establishes disruption, not message loss or a missing retry guard. |
| DNS/transport outage delays sends (8916–8918 / 5054) | P1 latency; delivery recovered | One Oct-1 incident; 5054 has 7 lifetime events | Client recovery implemented; verify CI and rollout | Build 297900: foreground send hit its 12s deadline, POST attempts hit 20s deadlines, history GET hit 38s, and a machine refresh reported Cronet `ERR_NAME_NOT_RESOLVED`. Loki confirms the original `localId` was ACKed at 14:36:18 UTC as seq 116; the server already had it, and the outbox marked it delivered roughly 51s after the send. Online-to-online link changes now renew the HTTP pool and reconnect the socket. DNS/connection failures and pre-header deadlines retire only their current pool; concurrent writes drain safely and retries preserve identity; this incident does not establish message loss. Server Loki queries returned no logs, so server-side timing remains unverified. |
| History response body times out (5048) | P1 history loading | 6 lifetime events | Adaptive page recovery implemented; verify rollout | Oct-1 build 297800 requested 500 messages after seq 14494. Headers arrived in 138ms, but the request timed out at 30.26s. Body timeouts now halve large older-history pages, recomputing after_seq against the same end boundary within one 40s budget. Failed pages cannot advance the cursor; runtime changes cannot commit old results. Transport telemetry includes received bytes even for partial bodies. |
| Slow daemon catalog/usage/spawn RPCs (3632 / 3794 / 3661) | P1 responsiveness | 367 / 46 / 99 lifetime events as of Oct-4 | Client latency amplification fixed; upstream timing still needs investigation | Latest events: Codex models took 10.59s on build 300200 (Oct-2), usage took 5.92s on build 300500 (Oct-4), and spawn took 24.01s on build 300200 (Oct-3). Correlate daemon execution and server forwarding using the recorded machine/request IDs. Usage requests now coalesce and only unsupported methods trigger Bash fallback; offline/forwarding failures return actionable retry feedback. Capability discovery, encryption, ACK and decode share one RPC deadline, and model probes are capped at 20s. These counts are lifetime totals, not recent incident rates; upstream cold-catalog/spawn work can still take seconds. |
| Browser Rust core disabled by timing panic (8914) | Performance fallback | 1 event, build 291200 | Fix in source; verify web CI and rollout | The deployed WASM panic stack reaches the literal `time not implemented on this platform`: sidechain planning called unsupported `std::time::Instant::now()`, then `NativeCore` disabled all Rust paths for that page. Crypto, JSON, sidechain and terminal stage timers now use `web_time::Instant`; web CI exercises the release WASM sync bridge. |
| Startup-resume teardown null check / offline save (8785) | Warning | 3 lifetime events; latest build 293200 | UI fix shipped; bounded offline-handler retry added | The Sep-30 event and Loki show `handler_offline` for `session-startup-resume-set` after leaving Session Info. Build 293200 contains the context-lifetime fix `6ab112fc`; this recurrence reports an unreachable machine handler, not proof of another localization crash. The idempotent setting now retries one retryable offline/forwarding failure with the identical payload, within its original 15s budget; permanently unavailable handlers still surface failure. The localized failure message already resolves before the async gap. |
| Pending sidechain results exceed cap (8880–8883, 8907–8909) | Warning / potential tool-output loss | Historical sidechain bursts | Preservation fixes on main; verify rollout | Results whose parent Task has left the resident message window cannot be rendered. The merge path now drops only those orphan sidechain results before they evict results waiting for resident tool calls; a result still queues when its Task remains resident. Sidechain entries are evicted ahead of main-chain results, and the drop counter now labels `chain=main` versus `chain=sidechain` so eviction is not mistaken for main-chain output loss. |
| Determinate progress-bar ancestor null check (3604) | Widget error | 2,087 lifetime events; latest build 291100 | Local controller theme fix; verify CI and rollout | Exact-build release symbols match build ID `7a3ef9309cb306703fa36f07b9379a40`. The Sep-28 stack resolves to `Element.widget` → `findAncestorWidgetOfExactType` → `LinearProgressIndicator._controller` in its determinate build branch. The existing owned widget controller covered only indeterminate bars. A local ProgressIndicatorTheme now supplies the owned controller for determinate bars too; route removal and theme replacement have regression coverage. |
| Terminal-session stale spawn refusal (8910 / 8911) | Misleading failed-send state | One Sep-26 incident | Existing fix 4da4e59b; CI 36776180687 passed | An RPC stale-spawn refusal falls back to posting the canonical message to the parked session, allowing the daemon to restart it. It no longer emits a restore failure or flashes Failed on a delivered message. |
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

### Performance (Prometheus and trace evidence)

| Metric | Value | Target | Notes |
|--------|-------|--------|-------|
| App cold start (`essential_ready`) | Oct-4 build 300500 mean 1.41s across 2 launches; build 300400 mean 1.51s across 1 | < 3s avg | Latest cumulative per-launch snapshots observed in the 24h range ending 14:13:41 UTC; use `last_over_time`, never sum repeated exports. These are small launch samples, not a fleet baseline. |
| Successful send tap to ACK | Oct-4 build 300500 direct-send p95 estimates 99ms / 220ms across 23 / 24 observations; restore-path p95 4.25s / 450ms across 6 / 4 observations | < 1s p95 when runtime is ready | Keep `path` and `outcome` dimensions. Direct delivery is fast; one launch has a restore tail. These successful-send samples exclude the blocked provider-switch incident above. |
| App RSS | Oct-4 per-launch p95 estimates: build 300500 1,257MB / 446MB (118 / 90 samples); build 300400 372MB (62 samples), all 101–250 sessions | < 768MB p95 | The outlier launch has mean 911 / p95 1,874 resident rows; image/encryption caches average 0.185MB / 1.53MB. Profile retained/native memory before assigning causality. Heap/external metrics currently emit unavailable zeros, not measurements. Latest cumulative snapshots from two versus one launches cannot establish a build regression. |
| Historical fetchMessages average (July 28) | avg 33–50ms (Prometheus, 2026-07-28) | < 5s | Was "up to 54s"; `app_fetch_messages_seconds` now shows 0.033s visible / 0.050s background. Historical baseline only; current post-resume header stalls are tracked above. |
| Chat UI-isolate stalls (2026-10-04) | Build 300500: 22 launch-lifetime freezes across 2 launches, 11 untracked vsync (chat 8, message detail 3) and 11 post-resume | none untracked | Latest cumulative snapshots seen in the 24h range: per-launch p95 estimates 1.525s / 1.825s (13 / 9 freezes). Post-resume is a three-second classification heuristic, not causal attribution. Profile foreground chat/detail stalls and resume work; these are not strict 24h event increments. Jaeger's 12.5s `chat.sync.await` example is background refresh with cached content, not a 12.5s initial render. |
| Deferred init | Oct-4 build 300500 mean 1.33s across 2 launches; build 300400 mean 1.40s across 1 | < 1s | Lower priority than transport and frozen frames. GlitchTip transaction aggregates are stale (latest deferred-init transaction Aug-29; Sep-27–Oct-4 trend empty); use current Prometheus launch snapshots. |
| Sessions frozen-frame p95 | 388 ms on `home` / 7d (69 frozen frames); build 245500 Mission Control max 175 ms | < 100 ms, no growth by session bucket/view | `session_count_bucket` proved the build-245500 recurrence was at 200 sessions; `sessions.mission_control.model` disproved grouping as the remaining bottleneck. Frame metrics now also label `sessions_view`, and `app.ui.frozen_frame_build` / `app.ui.frozen_frame_raster` split future freezes into UI-build versus GPU-raster cost. Re-baseline after lazy workspaces and bounded activity animation reach production. |
| Historical frozen-frame rate (build 272600) | Build 272600 0.0093% of frames, p95 0.74s; about 4x 272400 and 3x 272500 | < 0.001%, p95 < 100ms | Early 272600 data is dominated by one 251+ session launch. Chat contributes most events; `message-detail` and home contain the longest frames. Re-check after a full build window and correlate `frozen_frame_build`/`raster` with RSS and tool-output size. |
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
4. **P1 investigations**: DNS/transport recovery with preserved outbox identity (8916–8918), history response-body timeout (5048), slow/offline daemon RPCs (3632/3794/3661/8785). Progress-bar 3604 and WASM 8914 latest reports predate their fixes; verify updated-device/web behavior before calling them regressions.
5. **Other open investigations**: model/profile mismatch (8875), default-profile respawn (5198), `CryptoSecretBox.decrypt failed` telemetry, resident-row memory (RSS 1.8GB).
6. **Later**: sidebar navigation for tablet/desktop.

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Guard offline machine in NewSessionDialog | Done | Implemented with offline feedback, preflight reachability, and regression tests. |
| Streaming cursor in assistant bubble | Low | Makes AI response feel continuous vs discrete jumps |
