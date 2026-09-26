# Roadmap

This roadmap tracks upcoming features and improvements for **happy_flutter**.

**Last Updated**: 2026-09-24

**Rust hot-path follow-up, 2026-09-24.** A synchronous Rust pass over large
terminal output lost to Dart after bridge cost (2.33 ms versus 1.44 ms on
200 KB), so streaming updates now use an allocation-light Dart preview and
strip ANSI only after Copy. Large copy stripping runs on a Rust worker.
Outgoing AES-GCM encryption now uses the existing Rust batch cipher when the
native core is ready, preserving caller CSPRNG nonces and the Dart fallback.
Native encrypt/decrypt, sidechain, and terminal spans expose Rust stage and
bridge wall times; CI measures the revised terminal path and wire encryption.

**Battery + performance audit, 2026-09-24.** A 10-lane source audit was
grounded against 7 days of production telemetry. Two fixes shipped
(`7990886d`, `d17d6b8d`); the rest of the surface measured clean and is
recorded here so it is not re-litigated.

- **Unfocused rendering (shipped `7990886d`).** `app_ui_window_frames_total`
  recorded **1,233,610 frames with `app_active=false`** against 463,878 with
  `app_active=true` — roughly 7.5h/day painting a window nobody was looking
  at, 750,310 of it on the home route in `mission_control_folder`. The cause
  is not a ticker (`MissionClock`'s 15s timer cannot produce the observed
  ~28fps sustained rate) but the Sync data-change firehose: streaming agents
  emit `_notifyDataChanged({messages, sessions})` from a dozen sites in
  `_sync_messaging.dart` plus three in `_sync_socket.dart`, each rebuilding the
  whole home tree per token. An unfocused window now defers the rebuild and
  replays one catch-up read on refocus. **Note the interpretation:** this
  population is *desktop focus loss*, not phone idle — `app_active=false` is
  only set by `AppLifecycleState.inactive`. Mobile backgrounding already
  detaches frame metrics and suspends Sync, and mobile
  `app_active=true,current_route="home"` renders 0 frames on the current
  builds. Re-measure after rollout: `app_active=false` home frames should
  fall by ~99%.
- **Unbounded encryptor fan-out (shipped `d17d6b8d`).** `fetchSessions` and the
  cold-start cache restore each ran one `_ensureSessionEncryptionInitialized`
  per session through an unbounded `Future.wait`; each is an FFI round-trip
  that may spawn an isolate. Both are now bounded to 8 concurrent opens via
  `forEachBatched`, preserving order and the per-session error guard.
- **Measured clean — do not re-audit.** Cold start `essential_ready` ≈1.5s and
  `deferred_init` ≈1.5s (both within target). Frozen frames: 53/week on chat,
  ~1 elsewhere, against ~1.7M rendered frames. HTTP 54 attempts and 2.5 socket
  dials per 7d — no request storm. The resume path is deliberately bounded
  (global invalidation gated on `>5s && !rapidResume`, pending-message
  refreshes capped at 5, staggered 2s apart). `InvalidateSync` is
  suspension-gated with a shared completer. The three 1-second timers are
  already refcounted into one shared ticker. `ElapsedTime` cannot produce
  per-row timer fan-out. Raw `Circular/LinearProgressIndicator` exists only
  inside the two `App*` wrappers. Chat list virtualization is sound
  (per-row `RepaintBoundary`, tuned `cacheExtent`, `findChildIndexCallback`).
  On the server, `StoreOrderedMessages` already chunks at 25 rows per
  statement with a 2s lock timeout and holds **no network call inside the
  transaction** — the 55P03 burst is already addressed.
- **Open follow-ups.** (1) `app_memory_resident_rows` peaks at **2016**
  against a 1000-per-session cap and RSS reaches **1.8GB**; the
  previously "ruled out" memory suspects deserve a re-audit now that the
  instrumentation exists. (2) `refreshFromSync` runs in `initState` across
  ~15 screens with no cross-screen coalescing, so navigating between them
  refetches an already-loaded catalog. (3) `_sync_session_restore_split.dart`
  is a 49-line file holding no batching logic — the name misleads auditors.

**GlitchTip and observability follow-up, 2026-09-24.** The full unresolved metadata
inventory contains 5,300 groups (178 seen since September 1), mostly historical
warning fingerprints. Latest events, fatal reports and representative repeated
families were checked against release ancestry; this is not evidence that every
historical group has independently reproduced or been verified fixed.

- **Startup-resume teardown race (3604 / 8785, build 286800):** the latest
  null-check event is unsymbolicated. GlitchTip shows the
  `session-startup-resume-set` RPC failed with `handler_offline`; Jaeger records
  a `navigation.pop` at 19:55:53 in the same `app_launch_id`, before the
  failure at 19:56:06. Jaeger does not contain GlitchTip's Sentry trace ID.
  The catch path previously resolved localized text through the disposed
  screen context before its mounted guard. Localization now resolves before
  the RPC; the offline save still reports failure while the screen is present.
  Recheck after rollout.
- **Unmatched sidechain tool-result overflow (8880–8883):** Loki shows repeated
  pending-queue cap drops during reconnects. Results under a Task that has left
  the resident message window cannot be rendered; they no longer enter the
  bounded pending queue and displace results for resident calls. A sidechain
  result still waits when its parent Task is resident but its child call has
  not arrived. Added residency and overflow regression coverage; verify the
  drop counter and issue recurrence after rollout.
- **Terminal-session outbox readiness:** when a session reports a lifecycle
  error, sends deferred while waiting for readiness now move to the retryable
  failed bucket with their canonical `localId` and encrypted payload intact.
  Added coverage for terminal lifecycle delivery; verify the failed-send UX
  and identity after rollout.
- **Model selection/profile mismatch (8875):** five current-build warnings
  show the selected Cloudflare model is absent from the active custom profile,
  so the profile default is used. The guard prevents sending a model through a
  gateway that does not claim it; profile data or picker validation needs a
  follow-up before changing that fallback.
- **Spawn preparation deadline (8874):** one current-build `spawn-init` call
  timed out inside the server. The Flutter path reports the failure; this
  event does not identify a client-side fix. A separate send deadline (8876)
  followed a REST 500 and was handed to the outbox with its original `localId`.
- **Tool activity rendering:** collapsed tool groups count queued work without
  animating a spinner; only running tools animate. This avoids ongoing work
  indicators when no tool is executing. Shared shimmer fallback colors now
  come from the active Material surface palette when the app extension is
  unavailable.

- **Current Android null checks (3604/8780, build 286500):** exact matching
  symbols identify `CircularProgressIndicator` looking up a Theme ancestor
  during an animation after popping chat. App indicators now own explicit
  controllers and stop on deactivation; all circular call sites use the safe
  wrapper. The matching implicit-controller lookup in linear indicators is
  covered too. Regression coverage includes removal, reparenting, TickerMode,
  determinate transitions and route changes.
- **Web RenderBox failures (34 groups):** the current source map identifies
  the equivalent stack as reading-order focus traversal reading an unlaid-out
  node's rectangle. A shared policy skips candidates without geometry and
  defers directional traversal until layout. Exact historical web maps expired,
  so this mapping is qualified; four old native groups remain unattributed.
  CI packages matching web JavaScript/source maps as a durable asset on the
  automatic release, independently of the one-day deployment artifact and
  optional Sentry upload. Debug artifacts request 90 days but are currently
  capped at three days by repository policy; release assets avoid that expiry.
- **Background readiness alarms (3572/3804):** suspension during the wait now
  defers delivery without reporting agent startup failure. Repeated identical
  sends retain distinct canonical IDs through the outbox and resume.
- **Linux missing shader (8708):** its event follows a desktop update. The
  updater deleted the running bundle while Flutter still held asset directory
  descriptors. Both automatic updaters now retain retired bundles; cleanup
  requires proof that no process uses them. Restricted process inspection can
  postpone cleanup. Failed rollback backups remain untouched.
- **Session creation (8682):** server logs show a canceled create followed by
  `sessions_account_id_tag_key` / SQLSTATE 23505 on retry. Backend commit
  `happy-cli-go feffbc11` recovers the existing account/tag session, with real
  PostgreSQL concurrency and account-isolation coverage. Deployment remains a
  separate verification from committing the source fix.
- **Earlier builds:** today's ANRs 8864/4716 are build 286200, before
  `f7fcdf5a`; tool-result cap reports 8846–8848 predate `c4d697c5`, despite
  containing the earlier history fix. Outbox suspension, HTTP cancellation,
  MMKV, TTS and missing-Codex reports also predate their matching fixes.
- **External failures remain visible:** latest Kimi/Zai usage failures are
  OS network-unreachable errors; slow spawn/loop RPCs correlate with server
  forwarding retries. Disconnected sends that already received REST ACKs
  retain socket notification retries. No GlitchTip statuses were changed.
- **Mobile network and battery follow-up:** a 2-minute device capture showed
  three HTTP cancellations caused by app suspension, no socket errors, and
  successful post-resume reads. Sparse chat opening and separate settings
  edits still produced avoidable requests. Automatic older-history backfill
  is now one visible page, and settings writes coalesce with a bounded delay.
  Verify request count and received bytes on a post-release device capture.
- **Still unattributed:** stack overflow 8750 has one build-275100 event;
  its exact CI symbol artifact expired (download returns HTTP 410). Foreground
  Android idle-render warning 8859 measured 492 frames/30s on build 285000,
  but supplies no widget/ticker attribution and its Loki query returned no
  records. These remain open observations, not verified fixes.

**Parallel correctness audit, 2026-09-22.** This batch addresses:

- Current-build Android ANR loop (GlitchTip 4716, build 286200 / `906adc08`):
  symbolicated stacks show the emergency fallback's `Text` performing a
  `MediaQuery` lookup through a defunct element, recursively failing during
  error display. The emergency fallback is now a leaf `ErrorWidget`; root
  takeover is deferred until build/layout finishes. The initial spinner's
  defunct-ancestor failure remains unattributed and needs post-release
  monitoring. Bounded Loki correlation returned no records for this event.
- Message merge fast paths now reject duplicate IDs across incoming batches
  and the resident window, and validate final ordering of adjacent updates.
- Outbox restore/add completions respect disposal generations; late delivery
  failures do not restart suspended retries, and resume also clears suspension
  after a failed initialization.
- Chat drafts survive first edits, exit, and session/controller replacement.
  DraftStorage persists after the composer's debounce without adding another
  500ms MMKV timer; lifecycle saves therefore reach durable storage.
  Autocomplete replaces whole tokens. File previews accept empty content,
  reject stale responses, and use one vertical viewport for code and gutter.
- Profile edits/duplication preserve structured provider configuration and
  defaults; session creation closes the navigator that owns its dialog.
- Batched/single settings writes share a persistence/sync queue. Storage
  serializes key hydration with edits, preserves lazy-key loading, and flushes
  pending settings on background suspension.
- Existing red CI was two outdated spawn-environment expectations after
  Codex Fast Mode, not the `ApiClient` messages in annotations. Assertions
  now cover the explicit flag; CI annotations use actual JSON error events.

Regression tests accompany these fixes; test execution remains CI-only.

**Battery idle-render follow-up, 2026-09-15 (issue 8809).** The Linux
280300 event reported 598 frames/30s at 19.9 fps while `in_foreground=false`
and `current_lifecycle_state=inactive`. Source tracing confirmed a real
focus-loss rendering path: `AppStatusDot` and `ConnectionStatusBadge` pulse
controllers, plus `MissionClock`, continued running while desktop focus was
lost. Existing route `TickerMode` wrappers did not cover app-level inactive
state. Fixed in `2b914aa3`: decorative tickers now respect inherited
`TickerMode`, Sync remains live for visible-but-unfocused desktop windows, and
frame metrics label inactive windows as `activity="inactive"` instead of
classifying them as battery-idle; the idle warning is suppressed for that
state. Regression coverage pins ticker silencing and inactive-window metrics.

**MMKV compaction / tool-result telemetry status.** Issues 8725/8808 and
8815/8830+ were emitted by build 280300/281000, before the current source
fixes. The MMKV worker now returns structured failures and logs the known
best-effort limitation once per process. The tool-result correctness fix is
`c939ce5c`: history backfill no longer queues results from pages that are
immediately trimmed from the resident window, so unmatchable results cannot
evict genuinely pending ones. The warning events are therefore stale-build
telemetry; re-check after 281000+ rollout rather than treating their presence
as a current regression.

**Server rollout.** The happy-server production Deployment now runs
`ghcr.io/denysvitali/happy-server-go:ff1cd91` (3/3 Ready, Argo Synced/Healthy,
2026-09-14). This tag contains the Sep-8 Go fixes that were missing from the
previous Aug-27 `4f97bfd` pods.


**Historical audit window: server was still on the Aug-27 image.** Every
`happy-server` line in the 2026-09-07→09-14 audit window carried
`service_version="master+4f97bfd8b97e"`, so the 2026-09-08 Go fixes
(`a9ef61a`, `505b79a`, `f513cc9`, `be33fb2`) were not deployed during that
window. Measured against it: **62** `failed to create message` + **89**
`atomic message store blocked` (`SQLSTATE 55P03`, `sessions` row lock), and
**78** `happy_ws_messages_dropped_total{reason="persist-failed"}` — ~72% of the
week's failures in one 09-12 14:00–16:20Z burst that coincided with daemon
lease churn. `happy-postgres-8` showed 5 restarts (last reason `Error`), and
`happy-postgres-9` was absent from the series. Push was still 100 %
`outcome="unconfigured"` (79/7d). Client-side gap recovery repaired every
observed seq gap, so the symptom was delay, not loss — but a persist failure
never gets a seq, so those 78 rows were not gap-recoverable and the loss
question remained unresolved. The rollout is now recorded above.

**Client fixes shipped in this batch:**

- **ErrorBoundary latch oscillation (GlitchTip 4902, fatal, 280100).**
  `error_boundary.dart` cleared `_error` whenever `oldWidget.child !=
  widget.child`; a parent rebuilding with a fresh child instance cleared it on
  essentially every rebuild, so the fallback and the failing subtree alternated
  at ~1 Hz (repeating `Null check operator` + `ErrorWidget built` breadcrumbs)
  until the isolate ANR'd. A different subtree (type or key change) still
  clears; a like-for-like rebuild now gets 3 bounded retries, then the
  fallback holds. Regression test fails pre-fix at 13 child renders vs ≤4.
- **Our own cancellation reported fatal (8776).** The request budget's
  deadline cancel escaped an async gap to `PlatformDispatcher.onError` and was
  filed as a fatal. `sentry_config.dart` gained
  `isExpectedHttpCancellation`, wired as `beforeSend` on both platforms.
- **`ref` after unmount (8778 / 8806 / 8804).** `showSessionMenu` popped the
  sheet and then read `ref` from the unmounted `Consumer`; the notifier is now
  resolved before the pop.
- **Silent tool-result loss.** `_queuePendingToolResults` shed unmatched
  results at INFO with no counter (six drops in 3.4 s on one live session); it
  is now a WARN plus `happy_flutter.tool_results.dropped`.
- **StuckAgentSentinel walked an empty catalog** every 60 s unconditionally;
  now returns on empty, mirroring `SessionActivityCoordinator`.
- **MMKV compaction null-check (8725).** The worker body force-unwrapped its
  request map and escaped as a bare null-check. It now validates inputs,
  returns a structured reason, and the known worker-isolate limitation is
  logged once per process at info.
- **Parameterized-route page reuse (whole bug class, swept 2026-08-24).**
  The per-session widget key fixed one route; the trap belonged to all 13
  parameterized routes (session info/files/file/loops/workflows, message
  detail, agent conversation, workflow run, machine detail, artifact
  detail/edit, machine command) — every one seeds parameter-derived state
  once, and `EditArtifactScreen` latched artifact A's title/body into its
  text controllers, so a reused page would save A's text onto B. Only
  `chat` had a live same-route `go()` caller; the rest were latent. Fixed
  structurally: `routePageKey` in `app_router.dart` folds resolved path
  parameters into the page key inside `_fadePage` / `_slideUpPage` /
  `_slidePage`, so later routes inherit the guarantee (query parameters
  stay out — `SessionsScreen` rewrites `?tab=` via `router.replace()`).
  `test/core/routing/route_page_identity_test.dart` walks the real route
  table asserting per route/parameter that the `Page` key differs and
  `Page.canUpdate` is false, plus a `go()` walk over a probe screen that
  seeds state in `initState`.

**(2) Tablet/desktop auto-selection stole the tap.** `_ensureTabletSelection`
treated "not an auto-selection candidate" as "gone":
`TabletSessionSelectionProjection.fromSessions` filters archived sessions out
of its candidate list, so after tapping an archived session in master-detail
the post-frame callback replaced `_selectedSessionId` with the most recent
*live* session. Archived sessions were therefore impossible to open on
Linux desktop and tablets — the reported symptom. The projection now also
carries every session id and exposes `contains()`; an explicit selection is
only replaced when the session leaves the collection entirely.

**Confirmed healthy:** idle rendering is clean (`activity="idle"` windows
empty across three independent checks — the historical pulse/spinner family is
gone); `unmatched_optimistic` / `unknown_acked_local_id` / `CryptoSecretBox
decrypt failed` all empty for 7d; zero outbox dead-letters; cold start 0.79 s
mean / 2.32 s p95; send `target_resolution` p99 4.23 s → 0.22 s (fixed at
280100); session-collection compute ≤10 ms in every bucket.

**Watch:** chat sustains ~87–95 fps (mostly legitimate token streaming); a
>1 s frozen-frame tail reproduces on 280100/279900/279800 but not 280300; a
341 ms `ListSessionsV2` outlier; session-lifecycle skew still firing on 280300
(10 auto-restores on 09-14).

**Observability gaps worth fixing:** `happy-daemon` emits **no ERROR and no
WARN** at all (2,090 info + 96 `unknown`) — absence of daemon errors is not
daemon health; `service_build` is structured metadata on `happy-flutter`
streams, not a selectable label, so per-build stream filters silently return
empty; production server/daemon records are labelled
`deployment_environment="dev"`; GlitchTip trace ids do not resolve in Loki.

**Follow-up: did the 78 `persist-failed` drops lose user messages?** The
contradiction between "the client lost nothing" (gap recovery repaired every
seq gap) and "78 messages dropped server-side" resolves mostly in the client's
favour, with one gap that is now closed:

- **App sends are REST-first.** `_notifyDaemonOfStoredMessage`
  (`_sync_messaging_send.dart:1373`) documents the socket emit as a redundant
  notification of a row `POST /v3/sessions/:id/messages` already committed,
  and the server stores via an idempotent `ON CONFLICT (session_id, local_id)`
  upsert. A persist failure on that redundant emit cannot destroy a committed
  row. Measured: user sends succeeded inside the 09-12 burst
  (`localId=29aad41d-…` → `status=200` → `ACK … seq=18782` on session
  `c6fd0d01…`, one of the affected sessions).
- **Counter semantics:** `happy_ws_messages_dropped_total{reason="persist-failed"}`
  increments once per **terminal** failure, 1:1 with `ws: message: failed to
  create message` ERROR lines (+45 ↔ 45 in 09-12 14:00–15:07Z). Retries are not
  counted, so 78 is a floor, not a total; `isSessionGoneError` returns without
  incrementing, so that drop class is uncounted entirely. ~4-day Jaeger
  retention has expired the 09-09/09-10 windows, so the original burst
  attribution cannot be re-verified.
- **Still indeterminate:** a `persist-failed` on a *daemon-originated* frame
  has no REST fallback and would be real loss. `happy-daemon` emits nothing to
  Loki, so user-vs-agent classification of the drops could not be established.
- **Closed — the client ignored the server's loss signal.** The server emits
  `{code: "message-failed", sid, localId}` from its store-failure path, and
  the client had **zero** references to `message-failed` anywhere in `lib/`:
  `_handleErrorEvent` handled only `session-invalid`, so the one signal the
  server sends about a lost message was dropped without a log or a counter.
  It now counts (`happy_flutter.app.messaging.server_dropped`), warns, and
  marks a still-pending optimistic row `'failed'` so the canonical
  "Failed — tap to retry" affordance appears with its `localId` intact
  (`test/services/socket_message_failed_test.dart`).
- **Not a defect:** two user messages (`f5d31772-…`, `14014d3a-…`, session
  `ce3ac255…`) are still `dead=true retryCount=3` on build 280400. That is the
  documented **permanent**-class path (4xx / session-gone) — permanent dead
  letters stay user-retry-only by design, and `_retryFromDeadLetter` can
  rebuild the send after a cold start or cache eviction. Worth confirming the
  user actually sees the retry row for a session whose transcript row was
  evicted: `reconcileOutboxStatuses` skips a row that is no longer resident.


Historical audit narratives (2026-04 → 2026-09-13): moved to docs/roadmap-archive/2026-H1.md.
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

### Production audit, 2026-09-04 (GlitchTip, Jaeger, Loki)

Read-only audit of recent unresolved app errors and sampled September 4 slow
traces. Counts below are issue totals, not daily rates or affected-user counts.
Latest fetched tag: `v1.0.0-276800`; sampled events are builds 274000–276300.
Event timestamps can precede GlitchTip last-seen/ingestion timestamps. These
samples do not establish recurrence or resolution on 276800. No issues were
resolved or ignored.

1. **P1: make retry deadlines and suspension behavior real.** Issues 8770,
   8769, 8768, 8767 and 8667 share a background timeout burst on build 276200.
   Event time is 14:17:12 UTC: the app suspended at 14:16:44, several GETs
   retried together, and a nominal 20,000 ms budget lasted 33,227–33,555 ms.
   `_nextRetryDelay` checks elapsed time plus backoff but does not bound the
   following attempt's 23-second receive timeout. Add a cancellable overall
   deadline, clamp attempt timeouts to the remaining budget, and defer optional
   refreshes while suspended. Tests should combine hanging requests, suspension
   during backoff, cached UI availability, and a single refresh on resume.
   Issue 8761 (build 275300) additionally shows Cronet `ERR_NAME_NOT_RESOLVED`
   during outbox delivery; it retained the message for retry, so this is not
   evidence of message loss. Preserve localId and test eventual recovery.

2. **P1: investigate default-profile respawns on the send path.** Issue 5198,
   build 276300, logs `default -> default` while a session is online/running.
   Jaeger trace `6a434176e8e775ee938e858ef5eacb2b` measures 3,232.559 ms total,
   3,161.417 ms target resolution, and only 64.141 ms for message POST.
   Loki matches request `mrpc_8644a440c5487cfea6f39201`: the app reports
   rpc-capabilities at 3,085 ms and the server publishes an RPC forward retry.
   Check omitted/null/default profile identity and restored spawn tracking;
   retain intentional profile/model changes. Add a no-op-default-send contract
   and cross-replica capability-routing test. The default-to-default log alone
   does not prove equivalent internal profile identifiers. The profile fix
   `e9914bda` is already an ancestor of 276300, so do not dismiss this sample as
   predating that fix. Server attribution is partial: no matched daemon log.

3. **P1 investigation: symbolicate the remaining stack overflow.** Issue 8750
   has one event on September 2, build 275100; its stack contains native
   addresses without usable Dart function names. The earlier ErrorWidget
   recursion fix `d3185a0e` is an ancestor of this build. Obtain the exact build
   symbols and reproduce the identified path before claiming a root cause or
   duplicate. Issue 8731 is a separate unsymbolicated web layout failure on
   build 274000 and also needs matching source maps. No newer recurrence was
   established by this sample.

4. **P2: represent an absent Codex installation as unavailable capability.**
   Issue 8763 on build 275900 and Loki at 09:11:02 UTC agree that
   `get-codex-models` failed because the daemon could not find the executable.
   `machineGetCodexModels` still falls through to error logging for this
   response. Return typed provider-unavailable metadata, display setup status,
   and avoid repeated model discovery until capabilities change. Test a machine
   without Codex alongside an installed machine; do not hide other handler
   failures or treat the missing binary as a client crash.

5. **P2: measure transport/callback delay separately from backend work.**
   Trace `3e93600c6fbe1d3263dc1a00d84f4db6` has a 5,886.8 ms client session-list
   span but only 4.449 ms server work (ListSessionsV2: 1.019 ms). Instrument
   DNS/connect/TLS/first-byte/body/callback phases and lifecycle state before
   deciding whether Cronet, connectivity, or isolate scheduling is responsible.
   The timeout event's Sentry trace `818255445c2d4461a129b93c46444847` is absent
   from Jaeger, so do not claim that the slow successful trace explains that
   exact timeout. Also inspect repeated HTTP completion breadcrumbs during
   nested retries: they may be duplicate instrumentation, not duplicate sends.
   A sampled 112.7-second `subagent.spawn` span represents task lifetime and is
   not, by itself, evidence of a UI stall.

### Production Bugs (from GlitchTip, May 2026)

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
| Settings POST timeout swallowed (4717) | Warning | 17 issue total | Shipped (`04d30f60`) | Build 277500: the 10s POST wrapper timed out and the queue then reported success with zero retries. The wrapper is removed (HTTP owns the deadline), failures rethrow into `InvalidateSync`'s bounded retry, only acknowledged pending keys are cleared so edits made during the write survive, version conflicts rebase and retry, and a `_generation` guard blocks late POST/GET completion after `clear()`. Six contract tests in `test/core/sync/settings_manager_test.dart`, covering delayed POST past the old deadline, deadline failure, edits during write, conflict rebase, late POST after runtime reset, and edits during GET. |
| Machine RPC timeout / slow ping (3702/3627) | Warning | Current-build recurrence | Open — verify Bash cleanup and deployed routing | Build 277900 Bash ACK timeout at 30s correlates with server Redis retries. Go `f513cc9` fixes independently reproduced descendant pipe hangs; causality for the live RPC remains unproven. See September 8 audit. |
| Retry deadline overshoot / background refresh burst (8770/8769/8768/8767/8667) | Warning / Error | 1 / 1 / 1 / 1 / 2 | Fixed in `e4dad040` / `28b9b6e4` | Build 276200 predates absolute request deadlines, suspension gates and completed-budget retry handling; ancestry rechecked September 22. |
| Send target resolution / default-profile respawn (5198) | Warning | 161 issue total | Open — P1 investigation | Build 276300: 3.16s target resolution versus 64ms POST; Loki correlates capability RPC forward retry. Verify profile identity and routing separately. |
| Stack overflow (8750) | Error | 1 | Open — exact-build symbols expired | Build 275100 already contains d3185a0e. CI run 33612731392 artifact 9839878457 returns HTTP 410; release assets contain no matching Dart symbols. Native addresses cannot safely be mapped using another build. |
| Codex executable absent during model discovery (8763) | Error | 1 | Fixed in `e4dad040` / `6a879ee5` | Reporting build 275900 predates typed unavailable responses, per-machine negative caching and install guidance; contract tests cover both daemon error codes and cache isolation. |

| InvalidateSync disposed crash | Fatal | 55 | Shipped in v1.0.0-154901 (1ba4ebc) | App suspend races with in-flight `invalidateAndAwait()`; `dispose()` now completes normally instead of throwing `StateError`. |
| Null check operator (chat load) | Fatal | 9 | Shipped in v1.0.0-154901 (51f1189) | `session!.permissionMode!` and `selectedProfile!.defaultModelMode` force-unwraps in `_loadInitialSettings` when async gap allowed session/profile to become null. Fixed with safe pattern-matching (`case final x?`). Residual GlitchTip events (HAPPY_FLUTTER-17O/3C0/382) are historical aggregate; no new shape identified in audit 2026-05-22. |
| Null check operator (general) | Error | 12 | Shipped in v1.0.0-154901 (51f1189) | Same root cause as above. |
| Isolate unsendable Future | Error | 3 | Shipped in v1.0.0-152XXX+ (7b69d1b, 84ff0c2) | `Isolate.run` closure was capturing `this` in offline TTS / AES decrypt isolates; switched to top-level worker with sendable POD args. |
| ttsUseOffline unknown settings key | Fatal | 1 | Shipped in v1.0.0-XXXX (e051f35); telemetry b7cee41 on main | Settings dispatcher dropped unknown legacy keys instead of throwing; Sentry breadcrumb now captures dropped keys for context. |
| sherpa-onnx not initialized (TTS fallback noise) | Warning | 4 | Fix on main (9135fbd), shipped automatically on the next `main` commit | `OfflineTtsService` now records FFI probe failures and short-circuits to system TTS via typed `OfflineTtsException`; one info breadcrumb per process replaces ~one Sentry capture per `speak()`. |
| Sidechain orphans absorbed | Warning | 100+ | Fix on main (35db8c4), shipped automatically on the next `main` commit | Sentry capture gated to `triedFetchOlder && hasMoreOlder && count≥5`; normal happy-path absorption now local-info-only. |
| Resume sessions sync timeout | Error | 6 | Fix on main (0621440), shipped automatically on the next `main` commit | `TimeoutException` on resume is now caught and logged at info; underlying sync still completes via `onDataChanged`. |
| Resume conversation progress timeout | Warning | 6 | Fix on main (0621440), shipped automatically on the next `main` commit | Safety-timer fallback demoted from Sentry warning to local info log. |
| Screen awake plugin crash on Linux | Fatal | ~4,400 | Fix on main, shipped automatically on the next `main` commit | Issues 4678/4680/4682/5290 are the same `MissingPluginException` on Linux desktop: only Android/iOS runners register the channel. The Dart service now guards non-mobile platforms, and the Linux runner implements `setEnabled` with GTK idle/suspend inhibitors. Regression covers the unsupported-platform no-op. |
| Ref used in disposed widget (sessions dismissible) | Error | 1 | Fix on main (6a4776b), shipped automatically on the next `main` commit | `ref.read` and `context.l10n` hoisted before `showDialog` await in `session_dismissible.dart` so swipe-and-unmount can't trigger StateError. |
| Ref used in disposed widget (new-session reachability probe) | Error | 1 | Fix on main, shipped automatically on the next `main` commit | A 3.1 s daemon reachability probe could finish after `NewSessionDialog` was dismissed, then resume into `ref.read`/`setState`. Mounted guards now cover the probe and settings-update async boundaries; widget coverage dismisses the dialog while the probe is pending. |
| Session-create progress animation after dialog disposal | Error | Active burst on build 237001 | Fix on main, shipped automatically on the next `main` commit | Retained release symbols resolved the generic null-check stack to Flutter's `_CircularProgressIndicatorState`: its animation rebuilt after the Create dialog element was deactivated. The pending state is now a static hourglass icon, and the dismissal regression asserts no indeterminate ticker is mounted. |
| Back button error rate | Error | 3/8 (37.5%) | Fixed on main (ec102e5, 2bca2c8, bd011fd), shipped automatically on the next `main` commit | `StandardComponentType.backButton` `ui.action.click` transaction (GlitchTip transaction-group id 29). Two root causes addressed: (1) `PopScope` races where `canPop` was evaluated at build time but the callback ran later — fixed in `sessions_screen.dart`, `chat_screen.dart`, `edit_artifact_screen.dart`, and `voice_language_settings_screen.dart` by reading current state at callback time and adding `_pendingNav` / `_isPopping` guards; (2) bare `context.pop()` on deep-linked screens with an empty stack — fixed with `safePop()` helper in `lib/core/utils/safe_pop.dart` that checks `context.mounted` + `context.canPop()` and falls back to a named route, with widget tests in `test/core/utils/safe_pop_test.dart`. Transaction group last received an error 2026-04-03, before both fixes landed; no new occurrences as of audit 2026-05-22. |
| ANR (ErrorWidget recursion on UI isolate) | Fatal | 10+ | Fix on main, ships with next `main` commit | Issue 3659 (Background ANR, 19:41 UTC, **build 271500** = HEAD) plus 3529/3545 on 271100. Same 498–521 `libapp.so` cycle (`nativePollOnce`). 271100 events followed the todo_get TypeError (3eef2c38). 271500 is **after** that fix: chat → message-detail → home, then `Null check operator used on a null value [widgets library]`; ErrorBoundary replaced the tree *above* MaterialApp and `_ErrorWidgetFallback` called `Theme.of` — unbounded ErrorWidget recursion. Fallback is now theme-free, builder latches re-entry, takeover injects a minimal Material host (`test/core/widgets/error_boundary_test.dart`). The original home-pop null-check is still unsymbolicated; the ANR is the loop, not that throw. Close 3659/3529 only after a post-fix build (≥ this commit) with zero recurrences. |
| Home UTF-16 rendering crash recurrence | Error | 4 events on 279300 | Fixed in source; awaiting CI and device rollout | Issues 8777/8779 on Sep 9 share a trace after returning from Codex usage to Home and retrying. Symbolized stack confirms paragraph layout failure. Fixed unsafe UTF-16 cuts in session previews, tool hints, and profile initials; added emoji/grapheme regression coverage. Exact source widget is absent from the production stack; Loki trace query returned no logs. |
| Malformed UTF-16 tool output crash cascade | Fatal / Error | 3 events, one launch | Fixed in 272500 (42fbf23d); no recurrence on 272500/272600 | Issues 8647/8648/8615 on 272400 share one trace: an unpaired surrogate in CodexBash output failed during paint, followed by a layout null-check and `No ProviderScope found` in the recovery tree. Decrypted JSON is now recursively sanitized and ErrorBoundary is mounted under ProviderScope. |
| Outbox `agent_starting` readiness poll storm | Error (reliability / battery) | 16,953 attempts and 18,648 schedules / 1h; same `localId` at retry 49 | Wakeup implemented (`b5f9684e`); dead-letter fixed in 272500 | Issue 5387/8631 dead-lettered the same item after attempts 466–480 collapsed into about two seconds on 272400. Readiness deferral no longer consumes retry budget. The implemented wakeup replaces indefinite 5 s readiness polling with coalesced per-session waiters woken from the sessions readiness funnel; `test/services/message_outbox_test.dart` pins stable `localId`/retry identity, no timer storm, and explicit wakeup behavior. Keep `deferred` out of attempt/failure denominators. |
| Kubernetes auto-restore rejects a valid local path | Error (user-visible send failure) | 4 issues in one 272600 launch | Fix on main, ships automatically on the next `main` commit | Issues 8658–8661: auto-restore selected Kubernetes for `/home/workspace/git/happy-cli-go`, outside `/workspace`, because legacy backend recovery treated any `repoUrl` as Kubernetes proof. Explicit `runtimeType` is still authoritative; legacy recovery now selects Kubernetes only when the normalized path is inside the machine's advertised checkout root, otherwise it preserves the local backend. Contract coverage pins both the local-path regression and the legacy `/workspace` compatibility case in `test/integration/session_spawning_e2e_test.dart`. |
| Session says running but daemon has no process | Warning when blocked; recovered history is info | 6 warnings / 5 sessions on 273300, issue 8679 count 4 through build 273700, plus the earlier 27-event burst | Daemon/server fix 4f66380; Flutter telemetry fix on main; post-deploy verification pending | Issues 8623/8626/8654/8674/8675 span multiple sessions. Same-window daemon logs show metadata-version CAS races, failed lifecycle marks, stale-session reconciliation, and zero live processes. The latest 8679 event at 17:41 UTC was recoverable: Loki shows restore, send acceptance, and a response. Local graceful restarts wrote an exact handoff marker that the replacement daemon ignored while startup respawn was disabled. happy-cli-go 4f66380 resumes only recent exact handoffs, fences late host-PID and canceled-generation writes, and removes message-ingest lifecycle claims. Flutter keeps `hasLifecycleError` terminal across readiness/send gates and now logs restorable history at info while retaining warnings for sessions with no restore target. A runtime epoch/lease remains useful defense-in-depth; close the issues only after clean post-deploy evidence. |
| Kubernetes backend advertised without `GHProxyURL` | Warning (session creation blocked) | 2 fingerprints / 1 spawn on 273300 | Client reporting fixed in 273500; GitOps d4502fa Synced and Healthy | Issues 8672/8673 are the same explicit Kubernetes repository spawn. The `/workspace` path is valid, but the standalone daemon did not receive `HAPPY_KUBERNETES_GH_PROXY_URL`. k2-gitops now passes the in-cluster proxy URL; Argo reconciled the exact commit and is Healthy. Verify a repository-backed spawn before closing the issues. Flutter reports one stable dialog-boundary warning and keeps RPC context in a breadcrumb. |
| Cached profile/settings startup timeout | Warning noise | 2 fingerprints / 1 cold-start stall on 273300 | Fixed on main | Issues 8670/8671 retained usable cached data during the same disconnected 10-second startup window. Expected cached fallback is now info-level; invalid payloads, failed statuses, write timeouts, and unexpected failures remain warning/error signals. |
| Cronet `ERR_HTTP2_PING_FAILED` network transition | Warning noise | 1 event on 272900 | Fixed on main | Issue 8667 was one broader mobile transport outage. Both retry and reporting classifiers now recognize the exact HTTP/2 ping failure as connection-level while preserving receive-timeout and 5xx server-stall reporting. |
| Lifecycle partial window reported as idle rendering | Warning noise | 1 event on 272900 | Fixed on main | Issue 8668 force-flushed 358 frames about 4.8 seconds after resume but divided them by a hard-coded 30-second window and ignored lifecycle activity. Frame telemetry now rate-normalizes partial windows, marks lifecycle-bounded windows active, and discards detached timing callbacks before reattach. |
| TypeError `'List<dynamic>' is not a subtype of 'String?'` at chat open | Error | 3 | Fix on main (3eef2c38); no recurrence on 271500 | Recurred 2026-08-27 15:46 on build 271100 (issues 8570/8571 + ANR 3529). Codex MCP `todo_get` results arrive as `{content:[{type:text,text}], status}` maps; `TaskGet` did `map['content'] as String?`. Flatten MCP content blocks in `_resultText`. Last seen 271100; 271300 was first ship of the fix; 271500 (HEAD at triage) has zero events. Close after one more clean build window. |
| `RpcException(handler_error, codex debug models: signal: killed)` | Error | 2 (271100 + 271500) | Fix on main — demote to info | Issues 8603/8606: daemon `codex debug models` SIGKILLed (OOM). Catalog is optional chrome; client now logs info and keeps the failure TTL (`test/services/codex_model_catalog_cache_test.dart`). Daemon OOM still wants a host-side look. |
| `ServerConfigStorage: Sync init failed` (MMKV not initialized) | Warning | 258 | Fixed on main, shipped automatically on the next `main` commit | Expected startup state, misreported as a defect: `main.dart` deliberately resolves a provisional server URL while storage is still warming, so `MMKV('server-config')` throws "forget initialize MMKV first?" and the old code logged a warning (forwarded to Sentry) on every pre-warmup read. `_syncInit` now logs one info line per process and retries silently until the engine is up; callers already fell back to the default URL and re-resolved after warmup. |
| `Failed to fetch usage for kimi/…` HTTP 429 (insufficient balance) | Warning | 173 | Fixed on main, shipped automatically on the next `main` commit | A Kimi account out of balance answers 429 forever; the per-account strike/backoff map was process-local, so every launch re-emitted up to two full warning stacks (forwarded to Sentry) and re-hit the provider immediately. Strikes now hydrate from / persist to secure storage (`provider_usage_failures` key), preserving the 30 s→15 min backoff and warn→info demotion across restarts. The usage card still surfaces the error to the user. |
| Cronet `ERR_CONNECTION_ABORTED` on message fetch (issues 4900/8573) | Error | 7 + 1 | Fixed on main, shipped automatically on the next `main` commit | Device network transitions (VPN handoff, wifi↔cellular) mid-fetch exhausted the InvalidateSync retries and the raw Cronet error was forwarded as an error-level issue, even though the client preserved cached messages and re-armed recovery (`fetchMessages: network changed with pending gap`). A new `isConnectionLevelNetworkError` classifier (Cronet `ERR_*`, DNS, socket resets — NOT receive timeouts/5xx) demotes only the connection-level family to info at both the `InvalidateSync: max retries exceeded` and ChatScreen `background messagesSync awaitQueue failed` sites; server-side failures keep error level because they are the brownout signal (`test/core/utils/network_errors_test.dart`, `test/utils/invalidate_sync_test.dart`). |
| Deferred cached sessions missing encryption (issues 8755/8756) | Warning (message recovery) | 2 | Fixed on main, ships with next `main` commit | Cold start opened cached DEKs only for the five synchronously restored sessions. The deferred tail became known to the UI without a `SessionEncryption`, so its next socket payload was skipped and recovered through an avoidable network fetch. Restore now retains every cached encrypted key and initializes deferred encryption in bounded parallel batches before publishing the session batch; `sessions_cache_restore_test.dart` pins the sixth-session boundary. |
| Expected compatibility/Stop races promoted as issues (issues 5987/8757) | Warning | 48 + 1 | Fixed on main, ships with next `main` commit | Retrying a pre-`isRestore` daemon without the additive field is successful compatibility behavior, and `handler_offline` after a Stop tap means the target process already disappeared. Both paths retain their fallback/retry UX but log at info instead of opening GlitchTip issues. |
| Outbox-acked send trips `unmatched_optimistic` | Error | 3 | Fixed on main, shipped automatically on the next `main` commit | Issue 8566 (2026-08-26): a 24-attempt transient outbox retry (~4 h, server brownout) acked 50 ms after the session was archived — the resident window was empty, the optimistic placeholder long gone, identity held, message delivered. `recordAck` now takes `sessionResidentRowCount` and suppresses `unmatched_optimistic` when the client holds zero rows for the session (restart / idle-shrink / archived clear); duplicate and unknown-acked checks still fire. Contract tests in `test/utils/message_invariant_monitor_test.dart`. |
| Socket echo of a seeded, non-resident `localId` trips `unmatched_optimistic` | Error | 2 | Fix on main, shipped automatically on the next `main` commit | Issues 8592/8594 (2026-08-27, build 270800 — first occurrences past both prior fixes): `_handleNewMessage` taps `'sent'` for every socket row carrying a `localId`, so a re-broadcast of an old message (row evicted by idle/budget shrink) or another device's send reads as rowCount=0 over a held transcript (13–32 rows). Those ids are only *seeded* (cache restore / every upserted batch — `_sync_messaging_merge.dart`), never minted in the running process. `recordAck` now requires an in-process mint (`_sentAtMs`) to fire `unmatched_optimistic`; duplicate/unknown checks and minted-id strictness are unchanged. Contract tests in `test/utils/message_invariant_monitor_test.dart`. |
| `[Perf] sessions UI state compute` at extreme catalogs | Warning | 2 (one device, 463–465 sessions) | Open — needs its own measured pass | Issues 8589/8590 (2026-08-27): `trigger=single changed=1` 209 ms and `trigger=sessions_and_messages changed=3` 211 ms at 465 sessions. The single path pays a 465-entry map copy + ordering/MissionControl reconcile; the all-sessions path walks every entry (~0.45 ms each) even when only 3 changed — incremental reconciliation is the fix shape, not a same-day patch. Re-check the fleet tail via `app.sessions.ui_state_compute` by `session_count_bucket` before designing. |
| `[machineRPC] SLOW method=ping/get-codex-models/rpc-capabilities` | Warning | 254 / 271 / 80 since 2026-06-13 | Open — daemon-side, observability signal | Wedged/slow daemons answering machine RPCs above the slow threshold. `ping` slowness is the designed wedged-daemon detector (12 s pre-flight probe, 2026-06-09 fix); `get-codex-models` slowness feeds the coalescing model-catalog cache. No client defect; candidate for demoting per-session repeats to a rate-limited summary once the daemon fleet updates. |
| `[loops] listLoops` refresh noise (`method_unsupported` / `handler_offline`) | Warning | 15 across 10 rows | Fixed on main | Structured `RpcException` failures were falling through the `StateError`-only policy in `refreshAllLoops`, so unsupported and offline handlers were reported as warnings. The refresh path now negative-caches unsupported methods by machine and treats offline/retryable failures as transient; regression coverage pins one capability probe and no warning-level loop log across repeated refreshes. |
| `MessageCache` web quota-guard eviction | Warning | 13 across 4 rows | Fixed on main | Evicting the least-recently-used session after the deliberate three-session web cap is normal quota protection; the message cache rehydrates from the server on reopen. The event is now info-level so expected evictions do not open GlitchTip issues. |
| CryptoSecretBox.decrypt failed | Warning | 27 | DEK refresh implemented (`913d667f`); telemetry retained | Audit 2026-06-09: leading hypothesis is DEK decryption failing in `fetchSessions` → client silently falls back to legacy NaCl master secret → AES-256-GCM messages then fail MAC check (`stage=sodium`, `envelope=aesV0`). Added once-per-session Sentry capture (`dek_fallback_session` tag) when DEK decryption falls back, so fallback sessions can be correlated with `decrypt_scope=session:<id>:messages` failures. DEK refresh after rotation is now implemented (`913d667f`); use the retained telemetry to check for any remaining fallback/decryption failures. |
| Stale profile in ChatScreen | Warning | 9 | Shipped in v1.0.0-154901 (51f1189) | `_loadInitialSettings` now catches `StateError` from `firstWhere` and falls back to no profile, clearing the stale `savedProfileId` from `DraftStorage`. |
| Machine offline on session create | Warning | 33 | Fix on main, shipped automatically on the next `main` commit | NewSessionDialog disables offline machines and gates the create button (`newSessionCreateBlocker`). Remaining failure mode — machine heartbeat fresh but daemon wedged (60 s `SocketAckTimeoutException` on `spawn-happy-session`, seen 2026-06-09) — addressed with a 12 s pre-flight `ping` probe in `createSession` (`ensureMachineReachable`); daemon-side `ping` handler added in happy-cli-go (old daemons answer `Method not found`, which also proves liveness). |
| Spawn readiness timeout (single Loki WARN) | Warning | 1 / 24h | Fix on main, shipped automatically on the next `main` commit | `sendMessage` waited the full 15 s spawn-readiness budget without seeing presence come online, then sent anyway. Promoted the warn to a structured `Sentry.captureMessage` (`sessionId` / `spawnedAt` / `waitMs` / `recentlySpawned` hint fields, level `warning`) and bumped an OTel counter (`app.session.spawn_timeout` via `PowerDiagnosticsOtelReporter.recordAppError`) so the single occurrence becomes a rate-able signal. Magic numbers (15 000 / 30 000) replaced with `Sync.recentlySpawnedWaitMs` and `Sync.recentlySpawnedFlagMs`; all four `_sessionSpawned*` map writes funnelled through a single `_registerSpawn(sessionId, {profileId, modelMode, agent, at})` helper so `wasRecentlySpawned` anchors on the same time regardless of entry path (recovered `found.createdAt` vs. local `DateTime.now()`). Regression test: `test/services/sync_service_spawn_readiness_timeout_test.dart`. |
| RenderBox was not laid out (release StateError) | Error | 38 unresolved groups | Web focus guard added; old native reports unattributed | 34 web groups share the focus-geometry stack shape; the 286500 map identifies reading-order traversal. Historical maps expired, so exact old-build mapping is unavailable. Four native groups (3547/3526/3524/3520) remain unverified; three lack event bodies. |
| fetchMessages dropped (output filter) | Warning | ~180 | Fix on main, shipped automatically on the next `main` commit | Audit found every unresolved issue in this cohort comes from old builds (`1.0.0+97201` / `+1`) whose parser predated the top-level `dataType=tool-result` handler and the per-page summarizer dedupe. Current parser already routes the production-shape envelope (`callId`+`id`+`output`+`isError`+`parentUuid`+`permissions`+`type`) through `_isToolResultEnvelope`/`_addToolResultEnvelope`; added a contract test pinning the exact production shape and a telemetry split so known-skip categories (`assistant content list is empty`, `unrecognized output content block`, `user content block type=X not handled`, `pi result with no tool rows`) log at info-level while unknown `dataType`s stay at warning. |
| Orphan walk-back hollows out long sessions | Error (UI) | 1 session (13k seqs) | Fix on main, shipped automatically on the next `main` commit | User report 2026-08-03: chat showed "Beginning of conversation" over only the newest ~200 rows (mostly ungroupable workflow sidechain orphans); 5 days of messages/tool calls hidden. Loki showed a 2.5h orphan walk-back (500-row pages, 16:09–19:22 UTC) paging the session to seq 0 while the newest-N trim (1000 visible / 200 background) discarded pages as fast as they arrived (`upsert before=200` yo-yo). Reaching `startSeq == 0` then wrote `_sessionFirstLoadedSeq = 0` and pinned "history fully loaded" over a tail-only window — `hasOlderMessages` went false and the `firstLoaded <= 1` guard killed scroll-back. Fixed: a trim ledger (`_sessionsHistoryTrimmed`, recorded by `_upsertSessionMessages`) gates the pin; a trimmed walk reaching seq 0 re-arms the boundary to the oldest resident seq and exhausts the orphan-sweep budget (orphans render inline) instead of re-walking. Mid-walk pages keep coverage semantics (walk still advances over empty/parser-dropped ranges). Contract tests in `test/services/history_fully_loaded_pin_test.dart`. Restarting the app already heals a poisoned install (cache restore re-arms from the cache minimum). Follow-up shipped in this pass: persist the parent-group give-up signature so capped sessions do not re-run the full grouper or re-walk ~25 pages after a cold start; a real parent Task or disjoint parent group re-arms recovery. |
| Model/provider switch silently ignored on running session | Error | 1 session (2026-08-13) | Fix on main, shipped automatically on the next `main` commit | User switched a running DeepSeek session to Fable + Anthropic; the change-detecting respawn RPC failed because daemons older than the `isRestore` field (61c553b7, 2026-08-11) strict-unmarshal the request and reject the unknown field — breaking **every** auto-restore/respawn against pre-field daemons. Worse, `_resolveSendTargetSession` cleared `_sessionSpawned*` before the respawn, so the failure erased the pending change and every later send kept the old process (and model) alive with no retry. Fixed: spawn RPC retries once without `isRestore` on the unknown-field rejection, and failed respawns restore the cleared spawn tracking so the next send re-detects the change. happy-cli-go now unmarshals RPC requests with `DiscardUnknown` so additive fields never break old daemons again. Contract tests in `profile_switching_e2e_test.dart`. |
| Chat shows "working" and "Stopping…" at the same time | Error (UI) | user report 2026-08-17 | Fix on main, shipped automatically on the next `main` commit | The thinking bar and the stop state were two independent conditions in `_buildActivityChrome`, and the typing orb only checked `agentWorking`. Tapping Stop therefore replaced a styled 44 px bar with a bare unlocalized `Text('Stopping…')` (default `DefaultTextStyle`, no theme colour) while the animated orb kept claiming the agent was working above it — and because `_isAborting` only spans the abort RPC, the bar flipped back to "Thinking… [Stop]" as soon as the daemon acked. One `ThinkingStopBar` now renders all three states (`thinking` / `stopping` / `stopUnconfirmed`) at a fixed height with localized copy, the stop request is latched for a 20 s confirmation window (cleared on stop confirmation, on a new send, and on request failure), the typing orb is suppressed while a stop is pending, and an unconfirmed stop surfaces a warning row that re-offers the action instead of lying about progress. |
| Large session collections freeze retained UI | Error (UI) | 69 frozen home-route frames / 7d; reproduced on build 245500 | Follow-up fix on main, shipped automatically on the next `main` commit | The first pass removed collection-wide message scans, but build 245500 still showed five frozen `home` frames (175 ms max) with 200 sessions while Mission Control model work stayed below 1.3 ms. The remaining eager workspace `Column` and repeating status tickers scheduled 2,326 frames in 28.9 s. Workspaces are now lazy slivers with per-row repaint boundaries and static signals; activity pulses are bounded above 50 sessions. Re-baseline by `session_count_bucket` + `sessions_view`. |
| Permission request keeps reappearing after it was answered | Error (UI) | user report 2026-08-23 (session c92bc7c2) | Fixed in happy-cli-go (75f134c, 2026-08-23) | The `PendingPermissionBar` renders `session.agentState.requests` — server truth. A permission that outlived its session process (user answered an AskUserQuestion via a chat message; the process exited with the request still pending) stayed in the server-side agent state forever: the new process has no matching control request, so nothing ever moved the entry to `completedRequests`, and every Allow tap failed with "no pending permission request" — the app cleared only its local copy and the next sessions fetch resurrected the bar. Daemon fix: the first agent-state queue job on process start prunes pending requests left by a previous process, and the permission RPC prunes + acks a stale id still present in the published state (ordered via a new `submitWait` so a double-tap race still errors). App code unchanged — it already renders server truth. Existing phantoms heal on the next session-process restart or one Allow tap against the updated daemon. |

### Performance (from GlitchTip)

| Metric | Value | Target | Notes |
|--------|-------|--------|-------|
| App cold start (`essential_ready`) | Build 272600 mean 0.17s, p95 0.25s (68 samples); 30d fleet mean 0.90s, p95 2.34s | < 3s avg | Target met. The previous 4.6s Sentry baseline is obsolete. OTel uses delta temporality on per-launch streams, so aggregate one-shot histogram samples with `sum_over_time`, not `rate`/`increase`. |
| Successful send end-to-end | Build 272600 mean 4.32s, p95 reaches 30s bucket (841 observations) | < 1s p95 when runtime is ready | Server POST `/v3/sessions/{id}/messages` p95 is about 35ms with no 500s. The delay is before/around the POST: readiness waits, restore/respawn, FIFO serialization, and outbox handoff. Split the histogram by `ready`, `restored`, `queued`, and `backgrounded` phases. |
| App RSS | Build 272600 p95 2.02GB in the 101–250 session bucket; one launch averages 2.01GB in chat with 34 resident rows | < 768MB p95 | Image cache (~0.005MB), encryption cache (~0.05MB), and resident-row count rule out the three instrumented suspects on the outlier. Add Dart heap, external/native allocation, retained tool-output bytes, workflow projection bytes, and route-transition snapshots. |
| fetchMessages p95 | avg 33–50ms (Prometheus, 2026-07-28) | < 5s | Was "up to 54s"; `app_fetch_messages_seconds` now shows 0.033s visible / 0.050s background. Target met — the 54s figure predates the pagination work. |
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

1. **Note**: Releases are automatic — every commit to `main` publishes a GitHub Release with the production APK. A fix that is on `main` has shipped; there is no manual tagging step and no release backlog.
2. **This sprint**: Verify GlitchTip `StandardComponentType.backButton` error rate stays at 0% now that the PopScope/safePop fixes (ec102e5, 2bca2c8, bd011fd) have shipped
3. **Done**: Session creation guards offline machines and performs a preflight
   reachability check; regression coverage exists.
4. **This sprint**: Investigate `CryptoSecretBox.decrypt failed` warnings (27 events)
5. **Next sprint**: Optimistic mutation layer for instant UI feedback
6. **Next sprint**: Profile and reduce cold start time (avg 4.6s → target < 3s)
7. **This quarter**: Sidebar navigation for tablet/desktop

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Guard offline machine in NewSessionDialog | Done | Implemented with offline feedback, preflight reachability, and regression tests. |
| Streaming cursor in assistant bubble | Low | Makes AI response feel continuous vs discrete jumps |
