# Roadmap

This roadmap tracks upcoming features and improvements for **happy_flutter**.

**Last Updated**: 2026-08-13

### Cross-platform trust and interaction audit, 2026-08-08

A 15-pass review of the Flutter client and `happy-cli-go` covered messaging,
session lifecycle, RPC compatibility, security, accessibility, desktop UX,
performance, and diagnostics. The resulting implementation preserves one
canonical `localId` through failure and retry, makes no-payload retries
actionable, wires file autocomplete/unread/history recovery, renders the rich
shell/search tool views, and moves workflow/session/sub-agent projections off
whole-transcript or whole-collection rebuild paths. Message-cache preparation
now runs in its worker pipeline and auth restoration is protected from stale
post-logout continuations.

The app and daemon now negotiate scoped RPC capabilities, use typed error
envelopes, and share additive generated schema for permission and workflow
contracts. Unsupported optional features are disabled before use, negative
capability results are connection-generation scoped, malformed refreshes keep
last-known-good data, machine version skew is visible, and reconnect/status
surfaces expose safe localized diagnostics. RPC timing covers every call and
frame telemetry retains bounded tail buckets instead of averaging away jank.

Security-sensitive flows now fail closed for explicitly requested sandboxing,
show the actual per-session enforcement state, require exact permission
identities and acknowledge the applied scope, redact MCP secrets at the daemon
boundary, and use presence-only secret editing in Flutter. Account backup and
restore add guarded reveal/copy, destination confirmation, and clipboard
cleanup; support exports default to metadata-only redaction. Message-cache and
outbox payloads are sealed at rest with a device-protected AES-256-GCM key and
domain-bound associated data, including one-way migration of legacy plaintext.
Session stop and abort acknowledgements now reflect confirmed process or Pod
state, runtime identity is preserved during restore, timeout recovery never
adopts a same-path session, duplicate spawn requests share one result, creation
cannot be dismissed mid-flight, and queued initial messages retain their
identity until the agent is ready.

The command palette now lives under Router/Theme/Localizations with modal
semantics and focus restoration, indexes every session, and respects reduced
motion. Disabled settings rows publish disabled semantics; touch targets are
at least 44 px; pagination, connection, terminal-command, task, sandbox, and
status copy is localized. Unreachable SFTP/Friends prototypes were removed
from routing, the non-PTY terminal is accurately named **Run command**, and
session creation reports honest local/Kubernetes startup phases. Command output
is bounded on both sides of the wire, workflow snapshots omit unused source
paths, and session logs require an explicit support-bundle opt-in.

Operational follow-up outside these two repositories remains tracked below:
deploy the version-controlled alert/SLO rules in the monitoring configuration,
add native process-start anchors on Android and iOS, and only reintroduce a
Terminal or SFTP surface after the daemon has reconnectable PTY/file-stream
protocols. Those features are deliberately not simulated by the client.

### Session-scale performance audit, 2026-08-08

Prometheus confirms that the sessions collection (`current_route="home"`)
has a real frozen-frame tail: about 69 frozen frames over seven days and a
frozen-frame p95 of 388 ms, versus 250 ms in chat. A build-244400 Jaeger
`ui.jank` trace captured five frozen home-route frames in one window (262 ms
maximum, 767 ms total). This is not primarily server list-query time: the
inspected 18.9 s `GET /v2/sessions` client trace retried while happy-server
handled its 22-row request in 3.9 ms.

The client multiplied every message tick by the full session collection:
`SessionUiStateNotifier` rebuilt every entry and scanned up to 200 cached
messages per session; the retained sessions route kept refreshing underneath
opaque chat routes; list builds allocated repeated timestamp/unread maps; and
folder ordering rescanned and reallocated whole groups inside sort
comparators. Fixed by adding a targeted per-session notifier path for chat,
preserving unchanged entry identity and caching the unsettled-send scan by
message revision, suspending retained-list provider refreshes while covered,
adding an identity-complete sort fast path, removing lookup-map allocations,
and computing folder latest activity once per session.

The previous metrics could not correlate jank with collection size, and the
only slow-sort log was DEBUG-only (therefore absent from production Loki).
Frame/frozen-frame metrics and `ui.jank` traces now carry a bounded
`session_count_bucket` (traces also carry exact `session.count`), while
`app.sessions.ui_state_compute`, `app.sessions.sort`, and
`app.sessions.mission_control_model` measure the hot phases by collection
size, cache hit, trigger, and workspace count. Work over one frame emits a
rate-limited Loki warning; collections of 11+ sessions get one sampled phase
trace per 30 seconds.

**Mission Control follow-up.** Build 245500 reproduced the lag after the
collection-wide compute fix: with 200 sessions across 28 workspaces, five
sampled `sessions.mission_control.model` spans took only 0.1-1.3 ms, while the
same launch emitted a `home` `ui.jank` window with five frozen frames (175 ms
maximum, 642 ms total). The window rendered 2,326 frames in 28.9 seconds even
while idle. The remaining cost was rendering, not grouping: every workspace
was an eager child of one large `Column`, hot workspaces owned up to two
repeating status-dot tickers, and the outer list disabled repaint boundaries.
Mission Control now uses a lazy sliver workspace list with per-row repaint
boundaries, static workspace signals, and bounded focus-row pulses for
collections over 50 sessions. Frame metrics now carry `sessions_view`, while
frozen frames export separate build and raster histograms; `ui.jank` traces
carry the same view plus the longest frame's build/raster split.

**Steady-state projection follow-up, 2026-08-09.** Session collection and
ordering fingerprints are now prepared when notifier snapshots are published,
so visible list selectors no longer rebuild and hash whole maps. Targeted
preview/unread updates reuse ordering identity in O(1) when their timestamp is
unchanged. The app bar, sub-agent banner, and agents sheet share one bounded,
revision-keyed transcript projection instead of recursively walking the same
message tree per surface. Workflow detail/list polling now coalesces identical
RPCs, suppresses unchanged storage/notification fan-out, and caches transcript
projections by message revision. Command-palette session ordering uses one sort
per open and fuzzy queries reuse their preprocessed index. On the daemon side,
RPC handler registration publishes immutable lookup/capability snapshots;
parallel handler lookup is allocation-free and avoids the former RWMutex
reader contention.

**Chat-switch latency follow-up, 2026-08-09.** Production build 249900 still
showed build-dominated frozen frames up to 2.75 seconds. The affected launch
also queued hundreds of whole-snapshot message-cache saves; encode, queue, and
MMKV phases reached 4.0, 3.7, and 3.2 seconds respectively. Chat entry no
longer synchronously reads, decrypts, parses, or regroups the persisted cache:
it paints the existing in-memory projection first, then restores the cold
cache after yielding a frame. Native cache reads, JSON/AES preparation, and
routine writes run in workers; inputs are bounded to 200 rows before the
isolate copy, nested inline image bytes are stripped, and unchanged Sync
revisions never enter the worker queue. The suspend flush remains synchronous
as the process-kill durability fence. New low-cardinality histograms measure
tap-to-first-frame, tap-to-painted-content, complete cache reads, and every
write phase; trace-only session IDs preserve per-launch diagnosis without
metric-cardinality growth.

The same audit also separated two independent tails. Message-detail navigation
was eagerly walking, JSON-decoding, ANSI-parsing, and laying out entire tool
payloads; large results and sub-agent child lists are now collapsed and paged,
JSON nodes decode lazily, and clipboard serialization runs in a worker. Chat
visibility transfers message-queue ownership synchronously but starts cache,
regroup, and network convergence only after the seeded transcript's first
frame. Foreground session/cursor snapshots and settings maps serialize outside
the UI isolate, while suspend keeps the synchronous durability fence.

The unrelated socket tail came from repeated model-catalog RPCs and external
redials replacing Socket.IO's own active retry Manager. Codex catalogs now
coalesce per machine and use bounded positive/failure TTLs. Lifecycle,
connectivity, and watchdog reconnect requests preserve an opening/reconnecting
Manager instead of discarding its generation and stranding ACK callers.
Startup and resume no longer present that routine handshake as two simultaneous
outage banners. Socket recovery has an eight-second UI grace period, while the
visible chat's authoritative HTTP message probe now runs in parallel with the
sessions-catalog refresh instead of waiting behind it; a second post-catalog
probe preserves convergence for messages created during the first request.

### Live performance remediation, 2026-08-08

The next live sweep found a localized server incident that dominated perceived
latency: one `happy-server` instance reached a 26 s WebSocket queue-wait p95,
about 84% of messages waited over one second, and more than 1,800 messages were
dropped in five minutes. Loki tied the burst to one connection, while Jaeger
showed 0.9-2.7 s Postgres COMMIT stalls inside the affected window. The other
replicas remained below one second, which rules out ordinary fleet capacity and
points to per-connection head-of-line blocking amplified by database stalls.

The server remediation stores each message and allocates its sequence in one
ordered SQL statement, so a later committed sequence can no longer hide an
earlier message from `after_seq` pagination. The WebSocket path uses the same
store, admits only bounded per-connection work, rejects saturation immediately
with the canonical `localId`, and reports every rejection instead of silently
dropping it. Legacy clients and daemon-originated events receive a stable
transport identity before persistence. Runtime resources now include pod and
namespace identity so Prometheus, Jaeger, and Loki can identify the exact
workload without a cluster-side lookup.

On the client, capability probes are coalesced, bounded to four seconds, cached
with negative TTL/backoff, and short-circuited for definitively offline owners.
Deferred message probes are suppressed only when a newer successful fetch
covers the same cursor floor; newer socket evidence and gap repair still force
an authoritative request. Covered session-list routes detach their broad
Riverpod watches, preventing streaming chat updates from rebuilding a retained
200+ session Mission Control tree. Routine fetch and pipeline logs are folded
into bounded summaries.

The re-baseline now has build/environment identity on every app metric plus
bounded route-level HTTP latency, chat sync-wait, send-preparation phase, and
probe-coalescing telemetry. Native CPU, memory, battery, DNS/TLS subphases, and
a pre-fix mobile build split remain unavailable; the original sample contained
only four launches and about 84 minutes of data, so improvement claims must wait
for the new builds to roll out and accumulate a comparable window.

### Observability audit, 2026-08-03

A 26-agent audit across Loki, Prometheus and Jaeger covering the app,
`happy-server` and the kubernetes daemon. Headline: the client fleet is
healthy (pipeline zero-drop, frames at baseline, Jul-31 fixes holding), but
server-side write paths wedged again in a new shape, and 4 user messages were
permanently lost with zero signal during the brownouts.

**Postgres stall episodes (critical, new).** Four multi-hour bursts in 48h
(peak 202 errors/h, Aug 2 ~20:00 UTC) wedged every happy-server write path:
trace aab67f72 shows `AllocateSessionSeqMarkRunning` UPDATE at 29.997s →
pgconn timeout; machine-row writes (`UpdateMachineDaemonState` — 108k
heartbeats/48h — plus `BatchUpdateMachineActivity`) burned 61% of all DB
time. The Jul-31 sessions-row fix holds at p95 but never covered the
machine-row path. During bursts: ~29% of session creates fail, 13.3% of spawn
RPCs fail (archive/unarchive run a 10s deadline with no retry), 20 WS
messages dropped, fetchMessages p95 0.2s→3.1s, degraded sends on the current
build; 271/272 server ERRORs traced to one user with 22+ concurrent sessions.
Post-fix residual: CreateMessage 107 errors, seq allocation 56, pool_acquire
113. Next: bounded/retrying seq reservation on ws.message.store; spawn
archive/unarchive out of the critical path; one serialized writer per machine
row with statement timeout; capture pg_stat_activity/pg_locks during the next
burst; unstick happy-postgres-9-join (~82h incomplete, failover degraded).

**Outbox dead-letters (high, new, P0 breach).** Four sends from build 237901
went `dead=true` and were never delivered. The outbox budget (~40s: 3 retries
1s→30s) is shorter than the observed brownouts (30–75 min), so any stall over
a minute converts to permanent loss; the terminal attempt is uncounted (dead
branch returns before `recordOutboxFailure`), no dead-letter counter exists,
and the death WARN never reached Loki. **Fixed in d8dba9ac:** deliver now
returns a failure class — transient (timeout/network/5xx/429) retries ~4h at
a 30s-capped backoff, permanent (4xx/session-gone, body checked first because
the server folds NotFound into a bare 500) keeps the 3-attempt budget;
socket reconnect, foreground resume, and cold start re-arm transient dead
letters (permanent stays user-retry-only); `happy_flutter.outbox.dead_lettered`
OTel counter with reason + once-per-message Sentry capture; the terminal
attempt now counts toward `outbox.failures`; the existing "Failed — tap to
retry" row covered the UI state. Contract tests pin the transient budget past
3 attempts, revive selectivity + `localId` identity, counter diffs, and the
HTTP class matrix. Remaining: alert on `dead_lettered > 0` (see monitoring
item below).

**ErrorBoundary _TypeError burst (high, known-open, fresh evidence).** 87
ERRORs in 44 min from one resume on build 237901 (launch 43b8321a, 2026-08-02
20:57–21:41 UTC) — background >2 min → foreground with session refresh.
Breaks the zero-ERROR baseline on the dominant build; shape matches the
null-check family marked fixed in 51f1189. Next: pull the symbolicated stack
(symbols upload since 12028a45), reopen that fix or bisect the five
session-card/a11y commits for a force-unwrap on the resume path.

**Daemon fleet (high, known-open, four axes).** 113 restarts from etcd
lease-renewal failures (ongoing); checkout-base-dir blocking all spawns
outside it, recurring on the newest build 238201; 87 spawns ran unsandboxed
(boxy binary missing); old daemon emitted 50k-span rootless traces until
Aug 2. Next: apply the updated manifests (CHECKOUT_BASE_DIR, boxy, 07-30
process-lifetime-context fix, vcs.revision); lease-renewal retry with jitter
before shutdown.

**Push down (medium, known-open).** POST /v1/push/send-all → 501
(FCM_PROJECT_ID unset), 100% error rate; happy-agent retries ~75×/48h
emitting 40,821-span fan-out traces. Next: set FCM_PROJECT_ID + credentials,
replay one send-all; cap per-recipient spans.

**Monitoring HA + zero alerts (high, new).** Prometheus 1/2 ready,
Alertmanager 2/3, rook-ceph-osd-2 down; zero alert rules reference any happy
metric — every finding in this audit was found by manual sweep; push-only app
telemetry has no staleness detection. Next: recover the -0 pods (check
ceph/PVC first), then add happy.rules: dead-letter/invariant counters >0, WS
drops, spawn error rate, cold-start/fetchMessages burn rate, staleness.

**Invariant telemetry partial and misleading (medium, known-open).**
`unknown_acked_local_id` fired in the 7d window — likely a restart
false-positive (rowCount=1, no duplicate) but indistinguishable from a real
breach, and double-counted per ack; 3 of 4 planned counters absent, no
denominator. The 07-31 "all P0 invariant counters at zero" held only because
this event fell outside its 24h window. **Fixed in 6a9c9a7c:** `_sentLocalIds`
seeded from persisted rows (cache restore + every upserted batch) so
restart-time acks stop reading as unknown; recordAck deduped per localId
(REST-ack path and send-status path tapped the same ack); all four invariant
counters primed to zero at startup so the series always exist; sends/acks
denominator counters shipped; `app.message_send` tap→ack histogram added with
outcome labels. Remaining: the `> 0` alert rules (monitoring item below).

**Startup metrics unusable for the re-baseline (medium, new).** Per-launch
stream identity defeats rate()/increase() (NaN/0 — each launch's cumulative
series steps 0→1 once and rate() never counts the birth step); values anchor
at Dart `main()` not process start (50–250ms computable vs the 4.6s Sentry
baseline); `essential_ready` censored on the slowest launches. **Partially
fixed in 281fee77:** `essential_ready` is now recorded by a once-guarded
helper from whichever happens second (the startup future resolving or OTel
initializing), so the slow-launch tail is no longer censored; both cold-start
metric descriptions now say "Dart main()" instead of falsely claiming
"process start". Remaining: the recording rule / per-launch gauge for
cross-launch quantiles (Prometheus side), and a native process-start anchor
(needs Android + iOS platform-channel work; iOS has no CI build, so it needs
its own device-verified pass).

**Verified healthy.** Pipeline ~8,729 payloads/48h with zero drops/errors/
decrypt failures; frames p95 9.5ms, frozen frames 0.010%; lifecycle/socket
fixes hold (0 disposed-crashes, 0 zombie sockets across 447 lifecycle
cycles); Jul-31 sessions-row lock fix holds at p95 (CreateMessage 0.19s, seq
0.46s vs 28s pre-fix); ROADMAP WARN cohort (CryptoSecretBox, machine-offline,
sidechain orphans) drained to zero.

### Observability sweep, 2026-07-31

A 20-agent audit across Loki, Prometheus and Jaeger covering both this app
and `happy-cli-go`, followed by fixes in both repos. Headline: the app is
healthier than it feels — "slow" was mostly server-side, and "crashes today"
was a stale build.

**Crashes.** All 582 ERROR events in 24h came from one launch on the previous
build 237001 (the known session-create progress-animation disposal burst).
Build 237701 logged zero ERRORs across 30.7k lines and two launches. No new
crash shape. Treat the 237001 burst as drained — the fleet rolled over around
2026-07-31 00:00 UTC.

**Why it felt slow, in order.** (1) Postgres `sessions`-row lock contention on
the send path — chat sends stalling 28s, one `ws.message.store` insert lost.
Fixed in happy-cli-go: the seq block is now reserved in its own bounded,
retrying statement instead of holding the row lock across every insert and the
COMMIT, the lifecycle flip rides along in that statement, and the activity
touch goes through the batching cache — one write to the row per send instead
of three. (2) WS ingestion queue wait p95 84s. (3) MessageCache MMKV writes of
150–395ms, 232 in 24h — now dirty-tracked, coalesced and encoded off the UI
isolate. (4) Session-create p90 3.6s and a daemon heartbeat fanning out to 66
message fetches. (5) Send tail: 34% of catch-up polls ending
`timeout_or_inactive`.

**What held.** The `localId` contract survived every timeout — zero duplicate
messages, outbox 3/3 delivered with identity intact, all P0 invariant counters
at zero. Pipeline: 8,071 `notified=ok`, zero drops, zero decrypt failures.
Frame p95 ≤9.6ms; `fetchMessages` visible p95 437ms.

**Shipped in this app.** Per-launch metric stream identity so cold-start and
deferred-init quantiles are computable across launches (unblocks the
cold-start re-baseline below); bounded DEBUG OTel export with the
per-socket-payload pipeline logs collapsed to a counted summary;
`websocket.disconnect` spans emitted for app-initiated disconnects; inline
sidechain-orphan cap; `encryptionMissing` treated as a skip rather than a
pipeline error; remaining `NewSessionDialog` disposed-ref guards; real
frozen-frame duration alongside the jank window; widened post-send catch-up
budget with an attributed stop reason; a deadline-timed-out send that the
retry proves landed now reports "sent (slow)" instead of degraded.

**Open / not fixed, with reasons.** Two scout findings were measured and
disproved rather than fixed: `GET /v2/sessions/active` is not slow (p50 10ms;
the 3.56s was the enclosing daemon-heartbeat trace) and the session-scoped
websocket growth is not a server leak (all 46 connections heartbeat normally —
it is agent-child session lifetime). Spawn-RPC cancellation needs a new
server→daemon cancel event across both repos. Replica-agnostic spawn presence
needs a Redis-backed registration view; a drop counter landed instead so the
rate is alertable. Cache payload trimming was left alone because truncating
persisted tool output needs its own refetch cursor and contract tests.
Infrastructure-side and outside these repos: happy-server clock skew (~-0.9s)
distorting cross-service traces, the Firebase config gap on production builds,
and applying the updated daemon manifests to the cluster.

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

### Telemetry audit, 2026-07-28 (b5858b2f)

An audit against Prometheus / Jaeger / Loki found the signals were being
collected but several could not answer the question they exist to answer.
Fixed: cold-start first-frame stuck at 0s; `ErrorBoundary` log bodies carrying
no exception message (82 indistinguishable `_TypeError` events in 16 min);
stack-trace attributes truncated inside the VM crash header by a blanket
256-char cap; `websocket.disconnect` spans with no reason (13 connects vs 12
disconnects, unattributable); `ui.jank` spans landing in an `unknown` route
bucket; unbounded DEBUG export (18.4k records/24h from one device); and a
missing `deployment.environment` resource attribute.

Still open: the `_TypeError` burst of 2026-07-28 06:25–06:41 UTC (launch
`0bff0d24`, build `7a3ef930d273adeb3fa36f07e0880aa7`) has no diagnosable
stack. The next occurrence on a build after b5858b2f will carry both the
exception message and a full stack.

Follow-up audit on 2026-07-30 found Flutter log records inheriting stale
package-global OTel contexts after short navigation and cache spans had ended.
Log export now correlates only with the app's zone-scoped active span and
otherwise emits from `Context.root`, preventing unrelated warnings and errors
from being attached to expired traces. The same audit found agent HTTP polling
still inheriting the daemon's propagated spawn span, producing live Jaeger
traces with 3,500+ spans; happy-cli-go now removes that span from the
process-lifetime context while preserving baggage. The collector also
canonicalizes OTLP `severity_text` from its numeric severity so Loki level
queries no longer split between Go's lowercase and Flutter's uppercase values.

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
| Core messaging state-machine tests | Done | FSM contract suite at `test/fsm/message_state_machine_contract_test.dart` pins `draft -> sending -> sent/pending/failed -> merged` for both the typed `MessageStateTransitions` spec (Draft→Sending, Sending→Sent/Pending/Failed, Pending→Sent/Failed, Failed→Sending, Sent→Merged) and the `MessageStateMachine.apply` event-log projection. Every legal transition asserts `localId` identity; illegal/no-op transitions (double-optimistic, optimistic-after-merge, retry-on-merged/sending/null, fail-on-merged, missing-localId, ack/merge without serverId) are pinned as strict no-ops or `ArgumentError`s. End-to-end lifecycle walk and two-identical-`continue`-sends-with-distinct-localIds are covered. |
| User-visible core E2E scenarios | Not Started | Add E2E coverage for rapid follow-ups, background/resume mid-send, disconnected socket with successful REST persistence, and follow-up sends while the agent is still thinking. |
| Invariant telemetry | In Progress | Audit 2026-08-03 found 1 of 4 counters shipped (`unknown_acked_local_id`) but restart-blind and double-counting per ack, with the other three absent and no denominator. Client-side fixes shipped in 6a9c9a7c (restart-safe seeding, per-localId ack dedupe, all four counters primed to zero, sends/acks denominators, `app.message_send` tap→ack histogram); the `> 0` Prometheus alert rules remain under the monitoring HA item. |

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
| Ref used in disposed widget (new-session reachability probe) | Error | 1 | Fix on main, shipped automatically on the next `main` commit | A 3.1 s daemon reachability probe could finish after `NewSessionDialog` was dismissed, then resume into `ref.read`/`setState`. Mounted guards now cover the probe and settings-update async boundaries; widget coverage dismisses the dialog while the probe is pending. |
| Session-create progress animation after dialog disposal | Error | Active burst on build 237001 | Fix on main, shipped automatically on the next `main` commit | Retained release symbols resolved the generic null-check stack to Flutter's `_CircularProgressIndicatorState`: its animation rebuilt after the Create dialog element was deactivated. The pending state is now a static hourglass icon, and the dismissal regression asserts no indeterminate ticker is mounted. |
| Back button error rate | Error | 3/8 (37.5%) | Fixed on main (ec102e5, 2bca2c8, bd011fd), shipped automatically on the next `main` commit | `StandardComponentType.backButton` `ui.action.click` transaction (GlitchTip transaction-group id 29). Two root causes addressed: (1) `PopScope` races where `canPop` was evaluated at build time but the callback ran later — fixed in `sessions_screen.dart`, `chat_screen.dart`, `edit_artifact_screen.dart`, and `voice_language_settings_screen.dart` by reading current state at callback time and adding `_pendingNav` / `_isPopping` guards; (2) bare `context.pop()` on deep-linked screens with an empty stack — fixed with `safePop()` helper in `lib/core/utils/safe_pop.dart` that checks `context.mounted` + `context.canPop()` and falls back to a named route, with widget tests in `test/core/utils/safe_pop_test.dart`. Transaction group last received an error 2026-04-03, before both fixes landed; no new occurrences as of audit 2026-05-22. |
| ANR (foreground `nativePollOnce` + background `__sfvwrite`) | Fatal | 2 | Open — awaiting next event with body | First ANRs ever captured 2026-06-09 (HAPPY_FLUTTER-3D6/3D7), but event bodies were lost server-side: GlitchTip's worker scheduler died silently ~2026-05-28, daily Postgres partitions ran out 2026-06-04, and every event until 2026-06-09 18:30 UTC was DLQ'd with `no partition of relation issue_events_issueevent found for row` (issues got metadata only). Server recovered when the payload-cap deploy restarted the worker; k2-gitops 5ca1e85 adds a daily `maintain_partitions` CronJob safety net; pipeline verified end-to-end with a test event. Next ANR will arrive with a full thread dump — diagnose the main-thread blocker then. |
| CryptoSecretBox.decrypt failed | Warning | 27 | Telemetry on main, shipped automatically on the next `main` commit | Audit 2026-06-09: leading hypothesis is DEK decryption failing in `fetchSessions` → client silently falls back to legacy NaCl master secret → AES-256-GCM messages then fail MAC check (`stage=sodium`, `envelope=aesV0`). Added once-per-session Sentry capture (`dek_fallback_session` tag) when DEK decryption falls back, so fallback sessions can be correlated with `decrypt_scope=session:<id>:messages` failures. Next: confirm correlation in GlitchTip, then fix key refresh (cached `_sessionDataKeys` is never refreshed after rotation). |
| Stale profile in ChatScreen | Warning | 9 | Shipped in v1.0.0-154901 (51f1189) | `_loadInitialSettings` now catches `StateError` from `firstWhere` and falls back to no profile, clearing the stale `savedProfileId` from `DraftStorage`. |
| Machine offline on session create | Warning | 33 | Fix on main, shipped automatically on the next `main` commit | NewSessionDialog disables offline machines and gates the create button (`newSessionCreateBlocker`). Remaining failure mode — machine heartbeat fresh but daemon wedged (60 s `SocketAckTimeoutException` on `spawn-happy-session`, seen 2026-06-09) — addressed with a 12 s pre-flight `ping` probe in `createSession` (`ensureMachineReachable`); daemon-side `ping` handler added in happy-cli-go (old daemons answer `Method not found`, which also proves liveness). |
| Spawn readiness timeout (single Loki WARN) | Warning | 1 / 24h | Fix on main, shipped automatically on the next `main` commit | `sendMessage` waited the full 15 s spawn-readiness budget without seeing presence come online, then sent anyway. Promoted the warn to a structured `Sentry.captureMessage` (`sessionId` / `spawnedAt` / `waitMs` / `recentlySpawned` hint fields, level `warning`) and bumped an OTel counter (`app.session.spawn_timeout` via `PowerDiagnosticsOtelReporter.recordAppError`) so the single occurrence becomes a rate-able signal. Magic numbers (15 000 / 30 000) replaced with `Sync.recentlySpawnedWaitMs` and `Sync.recentlySpawnedFlagMs`; all four `_sessionSpawned*` map writes funnelled through a single `_registerSpawn(sessionId, {profileId, modelMode, agent, at})` helper so `wasRecentlySpawned` anchors on the same time regardless of entry path (recovered `found.createdAt` vs. local `DateTime.now()`). Regression test: `test/services/sync_service_spawn_readiness_timeout_test.dart`. |
| RenderBox was not laid out (release StateError) | Error | 3 | Open — awaiting symbolicated event | New issues 2026-06-09 (HAPPY_FLUTTER-3D4/3D2/3CU): `StateError: Bad state: RenderBox was not laid out: <obfuscated>#…` thrown by Flutter 3.41 `RenderBox.size` in release builds (box.dart:2304). Likely unmasked by 12028a45 (Sentry filtering removed) rather than newly introduced. App-level `.size` readers (`session_cards.dart` Hero shuttle, `tool_view_widgets.dart` CollapsibleOutput) already guard `hasSize`; framework Hero `_boundingBoxFor` is the main unguarded candidate (session-avatar Hero is the only Hero pair). Debug symbols upload to Sentry since 12028a45, so the next occurrence will carry a symbolicated stack — pin the culprit then. |
| fetchMessages dropped (output filter) | Warning | ~180 | Fix on main, shipped automatically on the next `main` commit | Audit found every unresolved issue in this cohort comes from old builds (`1.0.0+97201` / `+1`) whose parser predated the top-level `dataType=tool-result` handler and the per-page summarizer dedupe. Current parser already routes the production-shape envelope (`callId`+`id`+`output`+`isError`+`parentUuid`+`permissions`+`type`) through `_isToolResultEnvelope`/`_addToolResultEnvelope`; added a contract test pinning the exact production shape and a telemetry split so known-skip categories (`assistant content list is empty`, `unrecognized output content block`, `user content block type=X not handled`, `pi result with no tool rows`) log at info-level while unknown `dataType`s stay at warning. |
| Orphan walk-back hollows out long sessions | Error (UI) | 1 session (13k seqs) | Fix on main, shipped automatically on the next `main` commit | User report 2026-08-03: chat showed "Beginning of conversation" over only the newest ~200 rows (mostly ungroupable workflow sidechain orphans); 5 days of messages/tool calls hidden. Loki showed a 2.5h orphan walk-back (500-row pages, 16:09–19:22 UTC) paging the session to seq 0 while the newest-N trim (1000 visible / 200 background) discarded pages as fast as they arrived (`upsert before=200` yo-yo). Reaching `startSeq == 0` then wrote `_sessionFirstLoadedSeq = 0` and pinned "history fully loaded" over a tail-only window — `hasOlderMessages` went false and the `firstLoaded <= 1` guard killed scroll-back. Fixed: a trim ledger (`_sessionsHistoryTrimmed`, recorded by `_upsertSessionMessages`) gates the pin; a trimmed walk reaching seq 0 re-arms the boundary to the oldest resident seq and exhausts the orphan-sweep budget (orphans render inline) instead of re-walking. Mid-walk pages keep coverage semantics (walk still advances over empty/parser-dropped ranges). Contract tests in `test/services/history_fully_loaded_pin_test.dart`. Restarting the app already heals a poisoned install (cache restore re-arms from the cache minimum). Follow-up: persist the walk give-up so cold starts don't re-walk ~25 pages before stopping. |
| Large session collections freeze retained UI | Error (UI) | 69 frozen home-route frames / 7d; reproduced on build 245500 | Follow-up fix on main, shipped automatically on the next `main` commit | The first pass removed collection-wide message scans, but build 245500 still showed five frozen `home` frames (175 ms max) with 200 sessions while Mission Control model work stayed below 1.3 ms. The remaining eager workspace `Column` and repeating status tickers scheduled 2,326 frames in 28.9 s. Workspaces are now lazy slivers with per-row repaint boundaries and static signals; activity pulses are bounded above 50 sessions. Re-baseline by `session_count_bucket` + `sessions_view`. |

### Performance (from GlitchTip)

| Metric | Value | Target | Notes |
|--------|-------|--------|-------|
| App cold start (`root /`) | avg 4.6s, p95 9.3s (Sentry); OTel quantiles uncomputable until 2026-07-31 | < 3s avg | `app.cold_start.first_frame` shipped a constant 0s because the top-level `_coldStartStopwatch` was lazily constructed *by* the post-frame callback that read it; `essential_ready` (2.4s) therefore measured from first frame, not process start. Anchored in `main()` (b5858b2f). The 2026-07-31 audit then found each launch overwriting the previous metric stream, so 24h quantiles still could not be computed; per-launch stream identity fixed that. Re-baseline from Prometheus once a few launches have reported on a build after 2026-07-31. |
| fetchMessages p95 | avg 33–50ms (Prometheus, 2026-07-28) | < 5s | Was "up to 54s"; `app_fetch_messages_seconds` now shows 0.033s visible / 0.050s background. Target met — the 54s figure predates the pagination work. |
| Deferred init | avg 2.5s | < 1s | `app.deferred_init` histogram (the Sentry `app.deferredInit` transaction agrees). Still the largest startup cost — audit what's loaded eagerly. |
| Sessions frozen-frame p95 | 388 ms on `home` / 7d (69 frozen frames); build 245500 Mission Control max 175 ms | < 100 ms, no growth by session bucket/view | `session_count_bucket` proved the build-245500 recurrence was at 200 sessions; `sessions.mission_control.model` disproved grouping as the remaining bottleneck. Frame metrics now also label `sessions_view`, and `app.ui.frozen_frame_build` / `app.ui.frozen_frame_raster` split future freezes into UI-build versus GPU-raster cost. Re-baseline after lazy workspaces and bounded activity animation reach production. |

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
| Persist messages to MMKV | Done | `MessageCacheService` caches the last 200 messages per session in MMKV. Warm in-memory rows paint first; native cache read/decrypt/JSON and routine save preparation run in workers. Writes debounce for 2s with a 15s ceiling, skip unchanged revisions, and flush synchronously on suspend. |
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
