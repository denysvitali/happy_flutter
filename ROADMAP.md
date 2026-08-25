# Roadmap

This roadmap tracks upcoming features and improvements for **happy_flutter**.

**Last Updated**: 2026-08-25

### Perf pass 10, 2026-08-25 ("move more and more operations to Rust")

Telemetry-first pass. The three-tool sweep on the live fleet (builds
268100–268700) re-baselined the eighth/ninth passes and named the next
driver. Prometheus: frozen frames are down to 12–137 per build per 24h,
essentially all `route=chat`, almost entirely in the ≤0.25 s buckets with
zero frames above 0.5 s — but concentrated ~10× at
`session_count_bucket="251+"` (268100: 130.4 vs 7.1 for 101–250) while
active render-window counts are *equal* across buckets (163.8 vs 159.5).
So the freeze probability per streaming window scales with catalog size,
not transcript size. Jaeger's `ui.jank` traces remain single-span — two
fetched in detail (28.0 s and 27.2 s windows, session.count 201/443) put
frozen-frame **build** at 1 ms and **raster** at 2 ms of a 125–137 ms max
frame: ~97 % blocked-isolate computation, still unattributable from tags
alone. Loki is quiet: exactly one WARN across the newest-build window (a
transient outbox dead-letter, `reason=agent_starting`).

The ingest orchestrator was cleared first — the pass-9 mutation yield and
in-place tail update hold; `_updateSessionUsage` is O(1). The catalog-scale
term lives in the notification fan-out instead: during a streaming turn the
server's `update-session` events carry fresh `activeAt`/`lastSeq` per token
batch, each bumping `SyncDomain.sessions` up to ~10 waves/s after Sync's
debounce, and two listeners walked the whole catalog on *every* wave:
`StuckAgentSentinel` (`reconcile(sync.sessionsView.values)` with fingerprint
strings per thinking session), and worse, `SessionActivityCoordinator`,
which copied the catalog via `sessionsView.values.toList()`, spawned an
unawaited `_apply` future for every session including noops, ran an
O(active × catalog) nested stale scan, and **re-posted one platform
notification + Live Activity update per thinking session per wave** —
notification flooding on top of the isolate work.

Shipped: both listeners now coalesce sessions-domain events into one
full-catalog walk per cooldown window (leading edge + trailing catch-up,
1 s default — alert/notification latency may lag ≤1 s against a 10-minute
stall threshold and a 15 s elapsed-refresh timer). The coordinator also
skips noop applies, iterates the live view without the defensive copy,
replaces the nested scan with a seen-set difference, and dedupes show
decisions by presentation identity (toolName/sessionName unchanged → no
platform re-post; keeping the first snapshot pins startedAt so the elapsed
clock no longer drifts forward when the server refreshes activeAt mid-turn;
tool changes still re-post immediately). New
`app.session.catalog_reconcile` histogram (`source` +
`session_count_bucket`) measures both walks so this fix verifies itself
from production and any regression is visible by bucket.

Deliberately **no Rust slice this pass**, stated so it is not re-litigated:
the pinned cost is fan-out work — map walks, platform-channel marshaling and
pointer chasing over the session collection — which crosses FRB worse than
it runs in Dart (every bridge call would copy the catalog over the boundary
to do less work than Dart already does). Rust pays off for CPU-dense
kernels; the queued kernel remains the transferable-buffer JSON
materialization design from the ninth pass (flat string copy into the
worker + processed-tree copy out). Contract tests pin the new behavior:
burst-of-10 domain events → exactly two catalog walks and one notification
post per coordinator/sentinel, tool-change re-posts, deleted-session
cleanup, and detach() cancelling the pending trailing walk
(`session_activity_coordinator_test.dart`,
`stuck_agent_sentinel_test.dart`); `testEmitDomainChanged` drives the
domain stream without the socket.

### Perf pass 9, 2026-08-25 ("improve the performance even further")

First slice of the eighth pass's "rest of the hot path is still Dart" list:
the **sidechain-grouper revision memo**. Six of the nine production
`_groupSidechainMessages` call sites pass no `changedIds` (catch-up skip,
visible-regroup on session open, cache restore, fetch-older, the deferred
walk-back sweep), so each one re-walked the whole resident transcript — up
to 1000 rows through five indexing/grouping passes — even when nothing had
changed since the previous pass. `Sync.messagesRevision` could not anchor
the memo: only the socket path bumps it. The memo instead keys on a new
per-session **mutation generation** bumped in `_invalidateMessageCaches`,
the hook every message-window mutation already flows through (18 call
sites, including the seventh pass's in-place tail update, which reuses the
list reference — so list identity alone would have been unsound). A full
pass that finished *clean* (nothing to group, or grouped with no orphans)
records the generation; a full pass requested at that same generation is a
guaranteed no-op and is skipped. Orphan outcomes are never memoized, so
`_scheduleSidechainRegroup` and the deferred sweep behave exactly as before,
and `changedIds` calls still take the existing fast path. Contract tests
(`test/services/sidechain_grouper_memo_test.dart`) pin: skip on unchanged
window with `children` intact, re-arm on any mutation including the
same-reference streaming update, late child and late parent still grouped
without `changedIds`, orphans never memoized, deferred sweep still runs
after a mutation, per-session clear.

**Second slice, same day ("add JSON parsing in Rust too"): decrypt-and-parse
in one crossing.** After the crypto moved to Rust, the next thing the UI
isolate did with every row was `jsonDecode` it, then copy the parsed tree
*into* the message-processing isolate and copy the processed tree back out —
on the 500-row benchmark page that is parse 3.9 ms + copy-in 2.2 ms +
copy-out 2.2 ms of UI-isolate time per page (`aes_stage_utf8_json_decode_500`
/ `aes_stage_decoded_copyout_500`). Design constraint, stated so nobody
re-litigates it: Rust cannot build the Dart object tree cheaper than
`jsonDecode` does — every bridge codec allocates the same objects plus its
own envelope, and `Dart_CObject` has no map type — so the split is Rust
**parses** and Dart **materializes** off the UI isolate. `rust/happy_core/
src/json.rs` runs the full serde_json grammar walk (`IgnoredAny`: zero
allocation) on each decrypted plaintext in the same call as the AES batch
and returns validated text plus an exact per-row status (`bad_base64` /
`bad_envelope` / `auth_failed` / `not_utf8` / `invalid_json` / `bad_key`)
instead of the old "base64 or auth, can't tell". On the Dart side the page
path (`decryptEncodedJsonInIsolate`) wraps each body as `JsonText`; the
processor materializes it inside its worker (`materializeJsonText`), the
single-row convenience path materializes on read, and `EncryptionCache`
budgets it by characters. Web, native-unavailable and native-fault paths
return the decoded objects exactly as before. Pinned by 5 Rust tests
(grammar corners, every failure class aligned, byte-identical text, bad
key, empty) and Dart contracts (`test/encryption/native_json_batch_test.dart`:
byte-identical `JsonText` through the real FFI, failure classes aligned,
**processed page identical through the native and Dart paths**, cached lazy
row materialized on the single path, fallback; `json_text_processor_test.dart`:
lazy vs decoded rows equal, JSON-string bodies unchanged, corrupt text
degrades to the decryption-failed bubble, cache budget). Regenerated frb
bindings (`rustContentHash` 1046558248). The remaining per-page UI-isolate
cost around JSON is the flat string copy into the worker
(`aes_stage_isolate_strings_in_500`, 2.2 ms) and the processed-tree copy
out; both need a transferable-buffer design rather than more Rust.

**Third slice, same day (sidechain assignment planning in Rust).** The
grouper still has to flatten and mutate Dart's dynamic message tree, but the
repeated identity indexing and transitive parent-chain walk now run through a
compact FRB `SidechainRow` batch. Rust returns an index-aligned task
assignment plan; Dart applies root persistence, child-list deduplication,
nested regrouping, and orphan retry policy. A missing or faulty native core
falls back to the existing four-pass Dart grouper. Native Rust contracts cover
direct, transitive, nested, orphan, and cycle cases, and the live FFI test
covers the production grouper shape.

The post-decrypt socket tail also yields at the 120-row mutation-phase
budget, preserving FIFO and one notification while giving the UI isolate
event-loop boundaries during large batches. A targeted contract test covers
the yield count, bounded resident result, and ordering/localId behavior.
Frame metrics split every render window's activity into pointer events,
non-message Sync changes, and message-list mutations, so a future low-fps
report can distinguish an active streaming window from a blocked isolate or
a genuinely idle renderer.

The remaining per-token merge work is now consumer-side rather than store-side:
`ChatScreen` still hashed the first/tail message maps on every refresh even
though `Sync.messagesRevision` was already authoritative. It now uses that
revision (plus list identity and explicit session/empty-state guards) as the
only change gate, so a no-op Sync wake costs no content hashing. Widget tests
pin both directions: a replaced resident list with an unchanged revision does
not repaint, while an in-place streaming replacement with an advanced revision
does. A rejected follow-up also proved why row-signature memoization is not
viable today: chat rows are mutable nested maps, so identity-keyed caching
hides in-place tool-result and sidechain-child changes.

**Same-day P0 invariant fix (`unmatched_optimistic`).** Production bursted
~198 warnings on build 267200 because the `fetchMessages` pre-page loop
acked every known-but-not-resident history `localId` before that page was
merged. With a truncated cache window, replaying 200 rows looked like 198
optimistic sends with no resident placeholder. History fetch now seeds the
restart-safe localId set and clears outbox entries without touching ack
state; only a real REST/socket acknowledgement can record an ack outcome.
A 200-row truncated-window contract pins zero false violations
(`test/services/message_ack_cache_truncation_test.dart`), while the existing
fetch-invariant suite still proves foreign rows stay silent and real-ack
duplicate detection remains observable.

### Native (Rust) core, eighth pass, 2026-08-24 ("create a library in Rust")

Seven passes of Dart-side fixes each corrected a real defect and each left
frozen frames at ~487 ms p95. The phase split says why they could not help:
frame **build** p95 9.6 ms, **raster** p95 9.6 ms, **total** p95 487 ms — ~96 %
of every frozen frame is neither widget work nor GPU work. The UI isolate is
blocked on plain computation, and Dart gives no way to do that work
concurrently without an isolate hop that costs a spawn plus a full copy of the
payload being handed over.

So the heavy lifting moves out of Dart. `rust/happy_core` is a new crate
bridged with flutter_rust_bridge v2; Flutter keeps the view layer.

**First slice: batch AES-256-GCM**, chosen because it is the largest measured
cost that scales with the 251+ session count. The app depends on
`cryptography` with **no** `cryptography_flutter`, so every AES-GCM operation
resolved to pure-Dart `DartAesGcm` (~8-15 MB/s) *on the UI isolate*; a cold
catalog decrypts up to two payloads per session, i.e. ~502 inline decrypts
draining in one pass. Rust compiles to AES-NI / ARMv8 crypto extensions and
the batch entry points pay one crossing per catalog instead of one per row.
`decryptEncodedInIsolate` is the seam — it already takes base64 and returns
index-aligned results, matching the Rust API exactly.

**The native core is an optimisation, never a dependency.** `NativeCore`
returns `null` for the whole call when it is unavailable or throws, which is
the caller's signal to run the existing Dart path; a native fault latches the
core off for the process. A missing library makes the app slower, never wrong.
This also fixed a real init bug: `RustLib.init()` throws when the bridge is
already initialized (hot restart, second entry point) and that was being
misread as "unavailable" — the symbol probe is now the only authoritative
signal.

Verification: 11 Rust tests including **cross-language vectors** (an envelope
produced by Dart's `AES256Encryption` must decrypt in Rust unchanged — that
test failing means do not ship, never update the vector); 450 Dart encryption
tests green with the native path live; new end-to-end tests that seal payloads
in Dart and decrypt them through the real FFI (nested, unicode, and
corrupt-row index alignment). CI gained a `rust` job (cargo test + clippy
`-D warnings`) wired into the quality gate, and the release job cross-compiles
and installs `libhappy_core.so` for arm64-v8a and x86_64 — confirmed in the
build log, so the library ships inside the APK.

Not yet done, in priority order:
- **The remaining hot path is still Dart**: the per-token merge path and the
  ~140-line no-`await` span in the socket ingest orchestrator. Crypto was the
  dominant *measured* cost; JSON parsing and sidechain assignment planning now
  have native fast paths, while their Dart materialization and fallback paths
  remain intact.
- **WASM delivery is now wired into the web build.** CI runs
  `flutter_rust_bridge_codegen build-web --release` against `rust/happy_core`
  and copies `pkg/happy_core.js` plus `pkg/happy_core_bg.wasm` into the
  Flutter web artifact. This closes the previous deployment gap: web now
  ships the module files required by `RustLib.init()`. The native core
  remains optional at runtime; a failed WASM load still takes the existing
  Dart fallback.
- **Re-baselined 2026-08-25** (`app.native_core.status_total` confirms builds
  266600+ load the core). Frozen frames per 24h by build: 263600 = 329,
  265200 = 179, 266200 = 119 (pre-Rust plateau) vs 266600 = 7, 266800 = 27.
  Normalized per active render window (`app.ui.render_windows_total`; the
  `app_cold_start_first_frame_seconds_count` denominator reads all-zero and is
  unusable): plateau ~3.1–3.8 → **0.60 on 266600, 2.26 on 266800**. Every
  surviving freeze on Rust builds sits in the 100–250 ms bucket; zero frames
  above 250 ms anywhere — the old 487 ms tail is gone. Methodology note:
  judge raw counts and bucket occupancy, never `histogram_quantile` on these
  near-empty histograms (single occupied bucket → the quantile returns a
  number just under that edge on every build; an earlier interim "p95 halved
  to 242.5 ms" claim was exactly that artifact and is retracted). Verdict: it
  moved, so the port continues — survivors are the remaining Dart hot path.
- **Follow-up measured 2026-08-25:** the newest fleet build 268000 regressed
  to 106 frozen frames per 24h, all on `chat` with
  `session_count_bucket=251+`; build and raster work account for only 3.4% of
  the frozen wall time, so the UI isolate is blocked by synchronous
  application work. Loki identified the dominant loop: sessions at the
  1000-row resident cap repeatedly regrouped 800+ unresolvable sidechain
  orphans and re-walked older pages after every suppression window. The
  orphan walk-back now persists a stable parent-group give-up signature,
  skips the full grouper on subsequent stream events and cold starts, and
  re-arms only when the real parent Task or a new parent group arrives. The
  remaining Dart hot path is still the next Rust slice.

### Progressive-lag remediation, seventh pass, 2026-08-24 ("still lags")

The sixth pass **worked on the metric it targeted** — on build 265500
`app.cache.messages.write` `write` p95 fell **172 ms -> 9.7 ms**, and the
worker-storage latch is confirmed in Loki (one fallback log per launch instead
of five per twelve seconds). Frozen frames did **not** move: p95 stayed at
**487 ms**. So the synchronous cache write was real, but it was not what
freezes the frames.

Two signals then named the actual driver. Every jank window on chat lands in
the **5-30 s bucket** — zero short ones — i.e. sustained jank for the length of
an agent turn, not isolated frames; and `app.chat.sync.await` p95 is **652 ms**.

Root cause: a streaming turn re-delivers the *same* agent row 20-50x/second as
tokens arrive. `_canAppendMessagesFastPath` deliberately rejects those (the id
already exists in the tail), so **every token fell through to the full merge
path**: a whole-list `LinkedHashMap` rebuild, a localId reverse index over
every row, an O(resident) `_isPromptEcho` scan per incoming row, a full
`toList()` copy and an order re-check — five passes over up to 1000 decrypted
rows, per token. That is both the sustained jank and the allocation churn
behind the GC stalls.

Shipped: an **in-place tail update**. When every incoming row is a pure content
update of a row already in the tail, it is replaced where it sits —
O(incoming + tail) instead of O(resident) — preserving the merge path's grouped
`children` and `_sidechainRootUuids`. It stays strictly subordinate to the
messaging invariants: a `localId` on either side, a prompt-echo candidate, a
user row, an out-of-tail id, or any replacement that would reorder the list all
fall through to the proven full merge. Contract tests
(`test/services/streaming_in_place_update_test.dart`) pin in-place replacement
without duplication or reorder, repeated updates keeping one logical row,
sidechain child preservation, optimistic replacement still happening by
`localId`, out-of-order rejection, out-of-tail fallback, and plain appends; the
dedup/out-of-order E2E suites were re-run green alongside them.

Still open, ranked, from the same audit: `_preDecryptSessions` runs up to 502
**inline** pure-Dart AES-GCM decrypts in one microtask drain (no
`cryptography_flutter`, so `DartAesGcm`), the only remaining cost that scales
linearly with the 251+ session count; the socket ingest orchestrator has a
~140-line span with no `await` between `_upsertSessionMessages` and
`_groupSidechainMessages`; and the sidechain grouper re-walks the whole
transcript with no revision memo.

### Progressive-lag remediation, sixth pass, 2026-08-24 ("it still happens")

The fifth pass shipped and **worked on its own terms** — RSS p95 fell from the
2048 MB bucket (265100) to ~634 MB (265200) — and the app was still laggy. The
frozen-frame phase split on the user's own build finally named the real
mechanism, and it was never widget cost or GC:

- frozen frame **total** p95 = **486 ms**
- frozen frame **build** p95 = **9.6 ms**
- frozen frame **raster** p95 = **9.6 ms**

~96 % of every frozen frame is spent outside both phases: the UI isolate is
*blocked*. `app.cache.messages.write` matched it almost exactly (`total` p95
408 ms, `write` p95 153-172 ms), and Loki produced the proof — the user's
Android device (CPH2653) logs `[MessageCache] Native worker storage
unavailable` on **every single cache write** (5 in 12 s while chatting).

Root cause: `writeSessionMessagesEncodedInWorker` calls `MMKV.defaultMMKV()`
inside a short-lived `compute()` isolate. MMKV is only initialised on the main
isolate and a worker cannot create a handle without a platform channel, so the
call throws on this device **every time**. The fallback then wrote the whole
multi-MB encrypted marker **synchronously on the UI isolate** — a ~150 ms frame
block roughly every 2.4 s of active chat. Worse, each write first paid an
isolate spawn *plus a full copy of that same multi-MB marker string* into the
worker that was guaranteed to fail.

Shipped: **(1)** the worker-storage failure is now latched for the process
(`_workerStorageUnavailable`) — a device that cannot write from a worker stops
paying the doomed spawn+copy on every subsequent write and goes straight to the
main-isolate handle. **(2)** inline base64 image data is stripped in
`_rawCacheWindow`, i.e. *before* the `compute()` deep-copy, instead of inside
the worker. The copy is synchronous on the UI isolate, so the old order paid a
multi-MB copy for bytes the worker immediately discarded; `stripInlineImageData`
is non-mutating and idempotent, so the worker's own sanitize pass is now a no-op
and the persisted bytes are unchanged. Contract tests pin pre-copy stripping,
caller non-mutation, idempotence, and pass-through
(`test/services/message_cache_worker_payload_test.dart`).

**(3)** A parallel static audit then caught a regression the fifth pass had
just introduced. `_shrinkSessionWindow` re-arms the scroll-back boundary, which
calls `_scheduleSaveFirstLoadedSeq()` — and that was **undebounced**, copying
the whole cursor map twice and spawning an isolate (`saveAllAsync` ->
`compute`) *per call*. The fifth pass made that fire for many more sessions
(budget-based, no idle wait) and on **every chat switch**, so switching into a
chat after fanning across 30 sessions queued ~22 back-to-back isolate spawns on
the UI isolate — the best single fit for a 486 ms frozen frame keyed to
route=chat. It is now debounced to one write per 500 ms window, matching its
sibling `_scheduleSaveSeq`; `suspend()` and `shutdown()` both still flush the
cursor map synchronously, so no cursor is lost. Pinned by a contract test that
a 20-session bulk shrink leaves one coalescing write rather than 20 spawns.

**(4)** The cache payload is now bounded by **bytes** (512 KB) rather than only
by row count, walking newest-first. The native write is a synchronous memcpy
into an mmap (plus MMKV's full-writeback when the region grows), so its cost
tracks payload size. Bounding by bytes keeps the full 200-row window for
ordinary sessions and trims only the giant-tool-output sessions that actually
produce the long writes; caching fewer rows than are resident is already a
supported state, so restore semantics are unchanged. The newest row is always
cached (cold start must repaint something); no row floor beyond that, since a
handful of multi-MB tool outputs would otherwise blow past the ceiling.

Still open (needs its own pass): the proper fix is making MMKV usable from the
worker isolate via `BackgroundIsolateBinaryMessenger.ensureInitialized(
rootIsolateToken)` + an explicit `rootDir`, which would move the native write
fully off the UI isolate on every device. Also still unbounded: giant *text*
tool outputs in the cache payload (the deferred truncation item — it needs the
refetch cursor), and the per-change rewrite of the whole 200-row window.

### Progressive-lag remediation, fifth pass, 2026-08-24 ("still lags like crazy")

Telemetry re-check on the live build (265100, which carries all four earlier
passes) reframed the problem. The "zero idle renderer" is now largely healed:
`app.ui.render_windows` shows chat rendering frames in only ~171 of 2,880
30 s windows/day (~6 %), and **zero** windows are labelled `activity="idle"
with frames` — the bad case (a rogue animation rendering with no pointer/Sync
change) no longer occurs. The dominant remaining signal is **memory**:
`app.memory.rss_mb` p50 ≈ 450 MB with a heavy tail, and RSS p95 lands in the
**2048 MB** bucket at the 101-250 session bucket — RSS scales with session
count, which is exactly the "laggier the longer it runs" heap-growth
signature (GC/platform stalls, not build/raster cost: frozen-frame *build*
p95 is still ~9.8 ms on chat).

Root cause: `_sessionMessages` (the decrypted/parsed resident transcripts) had
**no global cap**. The third-pass idle-window shrink only fires after 30 min
of inactivity, so a user fanning across a large catalog retains one full
~200-row transcript *per session touched in the last half hour* — at 250
sessions that is up to ~50k decrypted rows (tool outputs and sidechain
children included) pinned at once.

Shipped: a **residency budget** (`Sync.maxFullResidentSessions = 8`) layered
onto the same shrink sweep. Beyond the 8 most-recently-touched non-visible
sessions, the least-recent full transcripts are shrunk to the 25-row preview
window *immediately*, without waiting out the 30-min grace — bounding full
residency to the handful of sessions the user is actually cycling between
(memory becomes O(8×200 + rest×25) instead of O(total×200)). The visible
session and any session with an unsettled send stay full (retry identity
outranks the budget), and a budget-shrunk session pages history back in on
reopen via the existing re-armed scroll-back boundary. The shrink body was
extracted to a shared `_shrinkSessionWindow` helper; contract tests pin the
LRU ranking, the within-budget no-op, the visible-session exemption, and the
unsettled-send exemption (`test/services/idle_session_window_shrink_test.dart`).

Also fixed one genuine un-mitigated idle driver a static audit surfaced:
`HiddenToolSummary`'s collapsed indeterminate `CircularProgressIndicator` spun
forever on a resting visible chat. `parseToolState('canceled')` returns
`ToolState.pending` (the enum has no `canceled` member), and `_isPending`
counted `pending||running` — so the round-4 running→canceled reconcile, meant
to *stop* stuck animations, actually re-armed this collapsed spinner. `_isPending`
now treats a literal `'canceled'` row as terminal
(`test/features/chat/widgets/hidden_tool_summary_spinner_test.dart`).

Deferred with reasons: the `SyncProgressBar` circular indicator's null-fraction
indeterminate spin (an honest indeterminate spinner during a genuine sync is
correct UX; coercing `value` to 0 would freeze a 0 % ring and mask the
separate "isSyncing latches" bug), and shortening the 15-min visible-session
`thinking`/`running` reconcile window (risks demoting a legitimately slow but
alive turn — a long Bash with no message mutation would drop the caret). The
Loki client-OTel outage remains an infra track.

### Progressive-lag audit, 2026-08-24

User report: the app gets laggier the longer it runs. Four-agent sweep
(Prometheus, Loki, Jaeger, static audit) found: on build 263600 the chat
route froze 302 times in 48h (p95 245 ms at the 251+ session bucket) while
frame build p95 is 9.6 ms and raster p95 9.5 ms — the missing time is the
GC/platform-stall signature, i.e. heap pressure, not widget-build cost.
The renderer still reports **zero** `activity="idle"` windows (~31 fps
continuous on chat), so something beyond the fixed online-chip pulse keeps
the pipeline warm; and Jaeger holds no client traces (dev-cluster backend
only), while **Loki lost all happy-flutter logs after 2026-08-20 16:07 UTC**
(happy-server still streams — client OTel export or retention needs fixing
before log-level attribution is possible again).

Shipped here (all target memory ratchets / per-tick churn):
`MessageInvariantMonitor` id sets are bounded FIFOs (10k, mirroring
`_maxRecentInlineKeys`) instead of growing with every message seen for the
process lifetime; `EncryptionCache.setCachedMessage` skips decrypted
messages over a 50k-char content budget so huge tool outputs stop pinning
tens of MB in the count-capped LRU; both workflow screens reuse their
transcript index within a 250 ms floor instead of re-walking the whole
resident transcript on every revision tick of a live run; removed a dead
both-branches-identical ternary in `_refreshFromSync`. Contract tests pin
the FIFO bounds, the live-send-after-flood semantics, the evicted-id
trade-off, and the cache budget. Deferred with reasons: incremental
neighbor-cache patching (correctness risk in padding logic; build-phase
p95 says CPU is not the freeze driver), sidechain-grouper single-pass
(loses its early exit), byte-budgeting the other four EncryptionCache maps,
and dirty-gating the session-activity reconciler.

**Second pass, same day (user: "still lags").** Telemetry re-check: builds
≥263600 are live and the zero-idle-renderer and GC-stall signatures persist
post-ratchet (frozen-frame p95 247 ms on chat at 251+ sessions with frozen
*build* mean 1.0 ms and *raster* mean 1.85 ms — the time is outside both
phases), and the chat route has never once recorded an `activity="idle"`
render window. The 14k/day `unknown_acked_local_id` WARN bursts are zero on build
264200 (7bc1d1c8 works) — they heal as the fleet updates. A verified static hunt then landed four fixes: **(1)**
`_pendingToolResults` was unbounded (results whose tool-call left the
200-row resident window are permanently unmatchable) and the whole stale
queue was re-scanned — with a full resident-list rebuild — on every socket
batch and fetch page, O(pending × resident) allocation on the ingest path
forever; now FIFO-capped at 200/session with a 10-min TTL, and
`ToolResultProcessor` gets an allocation-free no-match prescan. **(2)**
Stuck-`running` tool rows (the structural product of (1)) kept a full-fps
pulse, a 1 s elapsed tick, and an indeterminate spinner alive indefinitely;
a session's `thinking` true→false socket transition (and presence-offline)
now walks resident `running` rows without results back to `canceled`
(permission-parked rows skipped; a late result still overwrites). **(3)**
`TodoView`'s in-progress pulse ran an unbounded `repeat()` — the resting
state of any interrupted plan kept the frame pipeline warm; now a bounded
3-cycle intro that restarts on real progress (row keyed by `id_status`).
This was the primary zero-idle suspect. **(4)** `Sync.sessions` /
`sessionUsage` getters copy the whole catalog per access (`Map.unmodifiable`
is a copying constructor) and were on per-message-tick and per-timer-tick
paths at 251+ sessions; hot readers (chat screen, `SessionUiStateNotifier`,
sentinel, activity coordinator) now use new zero-copy
`sessionById`/`sessionsView`/`sessionUsageView`. Also: dead
always-repeating `_AppBarTypingIndicator` deleted, spawn-readiness capture
list capped. Contract tests:
`test/services/pending_tool_results_bounds_test.dart`,
`test/features/chat/tools/views/todo_view_pulse_test.dart`.

**Third pass, same day — the two big deferrals landed.** **(5)** Idle
background windows now shrink: a session untouched for 30 min (no message
mutation, no visibility) drops to its newest 25 rows — enough for the
session-card preview — releasing decrypted tool outputs and sidechain
children that previously stayed resident for the process lifetime (200
rows × every session ever touched = the "laggier the longer it runs"
footprint). The sweep piggybacks on `_notifyDataChanged` (5-min throttle,
two-int-compare guard, no lifecycle timer to leak), skips the visible
session and any session with an unsettled send, records the
`_sessionsHistoryTrimmed` ledger, un-pins `_sessionsHistoryFullyLoaded`,
and re-arms `_sessionFirstLoadedSeq` to the oldest retained seq so
reopening pages history back in (never the 2026-08-03 false
"beginning of conversation"); MessageCacheService still holds 200
rows/session for cold-start repaint. Contract tests:
`test/services/idle_session_window_shrink_test.dart`. **(6)** Client
memory telemetry exists now: `app.memory.rss_mb` histogram (native only;
web RSS unavailable), sampled once per 30 s frame-metrics window — before
the zero-frame early return, so healthy idle windows still sample — with
`current_route` + `session_count_bucket` labels. Quantile it per
`service_build` to finally see progressive heap growth; the GC-stall
hypothesis is measurable from the next build on. Still deferred: a
visible "interrupted" ToolState (touches ~10 exhaustive switches + l10n;
`canceled` renders as the static queued glyph for now).

**Fourth pass, same day ("still laggy").** Telemetry first: the live fleet
build is 264400 — it has round 1 but predates round 2, so the RSS histogram
is absent yet. Frozen frames on chat per build/day are falling exactly along
the round-1 ratchets: 263600→325, 264200→82, 264400→21. Four remaining root
mechanisms landed: **(7)** state-latch animations had no client-side expiry —
`thinking`, tool-row `running`, and sub-agent `running>0` are server-truth
booleans, so a daemon that dies mid-turn left the caret pulse, stop-bar dot,
N tool-row spinners, and banner dots animating at full fps on an idle chat
forever (the zero-idle-renderer signature, ~90fps sustained windows with no
user input). `_reconcileStalledThinkingSessions` piggybacks on the throttled
idle-window shrink sweep (no new timers): a session with no message mutation
for 15 minutes gets `thinking` demoted to false and its stuck `running` rows
walked back to `canceled` (permission-parked rows skipped; a late result or
server update still overwrites). **(8)** inline base64 images decoded inside
`build`: every stream tick re-ran `base64Decode` on multi-MB payloads and
minted a fresh `MemoryImage`, whose new bytes identity missed the ImageCache —
a full-resolution re-decode per tick of pure garbage (the GC-stall freeze
signature). `_CachedBase64Image` decodes once per distinct payload and every
rebuild shares the identical bytes instance; malformed base64 now renders a
placeholder instead of throwing out of build. **(9)** EncryptionCache's five
count-capped LRU maps gained byte budgets (agent-state 4MB / metadata 2MB /
messages 8MB aggregate on top of the 50k-char admission gate / machine
metadata 1MB / daemon state 4MB) through new `LRUCache` `sizeOf`/`maxBytes`
accounting with an O(budget) `estimateJsonBytes` bail-out; `getStats()` now
reports `retainedBytes`. **(10)** the four per-id derived families
(`sessionById`, `machineById`, `recentPathsForMachine`, `sessionUiEntry`)
became autoDispose — riverpod keeps every non-autoDispose element alive for
the process lifetime, one element per id ever rendered. Also: chat chrome
revision now bumps when the recent-stream-activity window expires, so chrome
settles without waiting for a message event. Contract tests:
`test/utils/lru_cache_byte_budget_test.dart`,
`test/services/stalled_thinking_reconcile_test.dart`,
`test/core/providers/derived_view_providers_test.dart`,
`test/features/chat/widgets/user_bubble_image_decode_test.dart`, plus the
byte-budget group in `encryption_cache_test.dart`. Deferred with reasons:
SendStatusIndicator legacy-'sending' spinners (P0 send-path surface, needs
its own contract analysis), TtsPlaybackBar token-stall and hidden_tool_summary
spinner, SyncProgressBar/shimmer stall cases (load-path bugs in their own
right), visible-session tool-output hollowing (breaks resident-read
guarantees; needs the refetch-cursor design), dialog TextEditingController
disposal lint, ChatSwitchMetrics stranded span (cosmetic), and the Loki
client OTel export outage since Aug 20 (infra track, blocks log-level
attribution only).

### Session-identity and test-suite hardening, 2026-08-24

User report: tapping an archived session opened a different session. A
worktree-isolated agent sweep with adversarial verification found **two
independent root causes**, both now fixed and pinned.

**(1) Route page reuse.** go_router derives `state.pageKey` from the route
*pattern* (`/chat/:sessionId`), so `go('/chat/B')` while `/chat/A` is the
current location keeps the same page and swaps the child in place.
`ChatScreen` seeds its transcript, visibility and sync subscriptions in
`initState` from `widget.sessionId`, so the keyless widget kept A's state
while `widget.sessionId` read B: the header named B, the transcript and
composer context were A's. Every imperative entry point navigates that way —
command palette, notification tap, the send redirect
(`_followRedirectedSession`), the new-session dialog. Fixed with a
per-session `ValueKey('chat:<id>')` in `lib/core/routing/routes/`
`_shell_routes.dart`; pinned by `test/core/routing/chat_route_identity_test`
`.dart` (go-over-go and push/pop both assert the visible transcript matches
the URL).

**(2) Tablet/desktop auto-selection stole the tap.** `_ensureTabletSelection`
treated "not an auto-selection candidate" as "gone":
`TabletSessionSelectionProjection.fromSessions` filters archived sessions out
of its candidate list, so after tapping an archived session in master-detail
the post-frame callback replaced `_selectedSessionId` with the most recent
*live* session. Archived sessions were therefore impossible to open on
Linux desktop and tablets — the reported symptom. The projection now also
carries every session id and exposes `contains()`; an explicit selection is
only replaced when the session leaves the collection entirely.

**Ruled out with evidence, not assumption.** The sessions-list layer was
cleared by 22 widget tests covering folder recent/older archived groups,
Mission Control workspace drill-down, date- and folder-grouped archived
cards, search, archive-while-visible, timestamp reorder, row deletion,
collapse/expand, grouping toggle, in-flight press while rows shift, and the
400 ms tap debounce: label and route id come from the same `Session` object
in every path (a mutation test remapping one id fails 21 of 22).

**Coverage.** ~6,600 test lines added: a 51-test session-open contract suite
across every chat entry point (list, folder view, Mission Control, tablet
master-detail, command palette, notification tap, artifact detail) asserting
tap-label → routed id with archived rows and near-identical metadata, plus
91 pure-logic cases pinning ordering, date/folder grouping, disambiguation,
notifier identity/rollback, targeted `SessionUiState` updates and Mission
Control lane partition. That work exposed one real defect: every session
sort compared timestamps only, so equal-timestamp sessions landed in Sync
merge order and flipped above Dart's 32-entry insertion-sort threshold — all
five sorts now tie-break by id (folder order by key).

**Test speed.** Multi-second real timers were the dominant cost. Sync gained
`@visibleForTesting` timing overrides (spawn readiness, reachability probe,
retry jitter, suspend grace) and `MessageOutbox` a retry-delay scale, all
defaulting to production values and reset in `tearDown`: session spawning
81s→5s, session lifecycle 60s→2s, spawn-readiness 45s→5s, profile
switching 23s→1s, outbox e2e 11s→2s, update-routing 5s→0s, and
`message_outbox_test`
52s→~3s, `sync_service_test`/`sync_notify_scoping_test` ~20s→~3s under
FakeAsync. CI shards now run `--concurrency=4` (the serial pin dated from
the k8s-runner OOM era, traced to coverage accumulation rather than isolate
count), `.github/test-durations.json` was refreshed from real shard logs,
`.github/scripts/update_test_durations.py` regenerates it from the JSON
file-reporter artifact, and the analyze job now fails if any test file is
missing from the shard assignment.

### Web build performance sweep, 2026-08-23

User report: the deployed web build spins the fans while a tab sits open. A
16-agent audit + fix pass found three independent burn sources. **Idle:**
OpenTelemetry initialized unconditionally on web, arming 1s/5s/30s SDK export
timers — and every export dies at CORS preflight (the collector sends no
`access-control-allow-origin`), so web telemetry was pure waste; OTel init is
now skipped on web (Sentry/GlitchTip unaffected), the session-activity 15s
timer is native-only and the stuck-agent sentinel drops to 5-minute cadence.
Steady-state UI kept animating forever: permission-required dots pulsed on
retained session trees behind routes (`TickerMode` now mutes covered
subtrees; `isPulsing` is thinking-only), machine/friend "online" dots pulsed,
the ask-a-question card ran an infinite blurred-boxShadow glow (now a finite
3-cycle intro), and empty states/auth gradients looped unbounded (now finite
or reduced-motion-gated). **Streaming:** on web `compute()` runs inline, so
every delta re-parsed whole markdown documents and re-tokenized whole code
blocks while poisoning the shared syntax LRU — streaming rows now render a
bounded plain-text tail and settle to full markdown/highlighting after growth
stops; the sub-agent banner/builder double transcript walk per socket event
shares one revision-keyed projection; web batch decrypt/process yield between
8-row chunks instead of one long synchronous block. **Churn:** the reconnect
watchdog redialed forever with an 8-fetch cascade per reconnect — backoff now
caps at 600s and recovery is outage-proportional (short outages refresh
critical domains only; web skips the push-token sync it can't use); the
message cache no longer decrypt+re-encrypts identical windows every page load
(`pw` pipeline marker) and the ~2MB sessions blob is sharded per-session in
IndexedDB with batched decode. Deliberately not done: repeat-visit payload
caching (Flutter 3.41's service worker is a deprecated self-unregistering
shim — needs a hand-written SW or non-Pages hosting), CanvasKit→skwasm
renderer A/B, and WebCrypto-backed AES-GCM (needs async seam through sync
call sites).

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

### UI-isolate hot-path sweep, 2026-08-23

A static audit of `lib/` found the remaining main-thread hot spots now that
sessions collection, message cache, and socket ingest are already workerized.
Three fixes shipped: **(1)** send-path encryption — `SessionEncryption`
encrypt helpers for AES sessions now run through a new
`AES256Encryption.encryptInIsolate` / `AesGcmEncryption.encryptBatch`
(mirroring the existing decrypt isolates; NaCl FFI stays inline), so a large
pasted payload no longer jsonEncodes+encrypts on the frame that must paint
the optimistic bubble; **(2)** cold-start sessions-cache decode — the native
`getSessionsCacheAsync` no longer synchronously parses up to ~200 cached
session records on the UI isolate; the MMKV string read stays inline and the
parse moves to a `compute()` worker with inline fallback; **(3)** MCP tool
header summaries in `ToolView` are memoized per render signature instead of
re-running full `jsonDecode` of the tool result on every streaming tick.
Wire format is unchanged (version byte + nonce+ct+tag), pinned by new
round-trip tests in `test/encryption/aes_gcm_test.dart`. Accepted as-is:
suspend-flush durability fence (bounded by design) and the folder-detail
eager list (only reachable after opening a folder). Re-baseline send
preparation phase and tap-to-first-frame histograms once this reaches
production.

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
| Invariant telemetry | In Progress | Audit 2026-08-25 fixed the production build-267200 burst (~198 `unmatched_optimistic`): the `fetchMessages` pre-page loop acked known-but-not-resident history ids before merging their page; it now seeds identity/outbox state only, so history is never treated as a send ack (`test/services/message_ack_cache_truncation_test.dart`). Earlier audits removed foreign-history unknown-ack noise and shipped restart-safe seeding, per-localId ack dedupe, all four counters, denominators, and the send tap→ack histogram; the `> 0` Prometheus alert rules remain under the monitoring HA item. |

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
| Orphan walk-back hollows out long sessions | Error (UI) | 1 session (13k seqs) | Fix on main, shipped automatically on the next `main` commit | User report 2026-08-03: chat showed "Beginning of conversation" over only the newest ~200 rows (mostly ungroupable workflow sidechain orphans); 5 days of messages/tool calls hidden. Loki showed a 2.5h orphan walk-back (500-row pages, 16:09–19:22 UTC) paging the session to seq 0 while the newest-N trim (1000 visible / 200 background) discarded pages as fast as they arrived (`upsert before=200` yo-yo). Reaching `startSeq == 0` then wrote `_sessionFirstLoadedSeq = 0` and pinned "history fully loaded" over a tail-only window — `hasOlderMessages` went false and the `firstLoaded <= 1` guard killed scroll-back. Fixed: a trim ledger (`_sessionsHistoryTrimmed`, recorded by `_upsertSessionMessages`) gates the pin; a trimmed walk reaching seq 0 re-arms the boundary to the oldest resident seq and exhausts the orphan-sweep budget (orphans render inline) instead of re-walking. Mid-walk pages keep coverage semantics (walk still advances over empty/parser-dropped ranges). Contract tests in `test/services/history_fully_loaded_pin_test.dart`. Restarting the app already heals a poisoned install (cache restore re-arms from the cache minimum). Follow-up shipped in this pass: persist the parent-group give-up signature so capped sessions do not re-run the full grouper or re-walk ~25 pages after a cold start; a real parent Task or disjoint parent group re-arms recovery. |
| Model/provider switch silently ignored on running session | Error | 1 session (2026-08-13) | Fix on main, shipped automatically on the next `main` commit | User switched a running DeepSeek session to Fable + Anthropic; the change-detecting respawn RPC failed because daemons older than the `isRestore` field (61c553b7, 2026-08-11) strict-unmarshal the request and reject the unknown field — breaking **every** auto-restore/respawn against pre-field daemons. Worse, `_resolveSendTargetSession` cleared `_sessionSpawned*` before the respawn, so the failure erased the pending change and every later send kept the old process (and model) alive with no retry. Fixed: spawn RPC retries once without `isRestore` on the unknown-field rejection, and failed respawns restore the cleared spawn tracking so the next send re-detects the change. happy-cli-go now unmarshals RPC requests with `DiscardUnknown` so additive fields never break old daemons again. Contract tests in `profile_switching_e2e_test.dart`. |
| Chat shows "working" and "Stopping…" at the same time | Error (UI) | user report 2026-08-17 | Fix on main, shipped automatically on the next `main` commit | The thinking bar and the stop state were two independent conditions in `_buildActivityChrome`, and the typing orb only checked `agentWorking`. Tapping Stop therefore replaced a styled 44 px bar with a bare unlocalized `Text('Stopping…')` (default `DefaultTextStyle`, no theme colour) while the animated orb kept claiming the agent was working above it — and because `_isAborting` only spans the abort RPC, the bar flipped back to "Thinking… [Stop]" as soon as the daemon acked. One `ThinkingStopBar` now renders all three states (`thinking` / `stopping` / `stopUnconfirmed`) at a fixed height with localized copy, the stop request is latched for a 20 s confirmation window (cleared on stop confirmation, on a new send, and on request failure), the typing orb is suppressed while a stop is pending, and an unconfirmed stop surfaces a warning row that re-offers the action instead of lying about progress. |
| Large session collections freeze retained UI | Error (UI) | 69 frozen home-route frames / 7d; reproduced on build 245500 | Follow-up fix on main, shipped automatically on the next `main` commit | The first pass removed collection-wide message scans, but build 245500 still showed five frozen `home` frames (175 ms max) with 200 sessions while Mission Control model work stayed below 1.3 ms. The remaining eager workspace `Column` and repeating status tickers scheduled 2,326 frames in 28.9 s. Workspaces are now lazy slivers with per-row repaint boundaries and static signals; activity pulses are bounded above 50 sessions. Re-baseline by `session_count_bucket` + `sessions_view`. |
| Permission request keeps reappearing after it was answered | Error (UI) | user report 2026-08-23 (session c92bc7c2) | Fixed in happy-cli-go (75f134c, 2026-08-23) | The `PendingPermissionBar` renders `session.agentState.requests` — server truth. A permission that outlived its session process (user answered an AskUserQuestion via a chat message; the process exited with the request still pending) stayed in the server-side agent state forever: the new process has no matching control request, so nothing ever moved the entry to `completedRequests`, and every Allow tap failed with "no pending permission request" — the app cleared only its local copy and the next sessions fetch resurrected the bar. Daemon fix: the first agent-state queue job on process start prunes pending requests left by a previous process, and the permission RPC prunes + acks a stale id still present in the published state (ordered via a new `submitWait` so a double-tap race still errors). App code unchanged — it already renders server truth. Existing phantoms heal on the next session-process restart or one Allow tap against the updated daemon. |

### Performance (from GlitchTip)

| Metric | Value | Target | Notes |
|--------|-------|--------|-------|
| App cold start (`root /`) | avg 4.6s, p95 9.3s (Sentry); OTel quantiles uncomputable until 2026-07-31 | < 3s avg | `app.cold_start.first_frame` shipped a constant 0s because the top-level `_coldStartStopwatch` was lazily constructed *by* the post-frame callback that read it; `essential_ready` (2.4s) therefore measured from first frame, not process start. Anchored in `main()` (b5858b2f). The 2026-07-31 audit then found each launch overwriting the previous metric stream, so 24h quantiles still could not be computed; per-launch stream identity fixed that. Re-baseline from Prometheus once a few launches have reported on a build after 2026-07-31. |
| fetchMessages p95 | avg 33–50ms (Prometheus, 2026-07-28) | < 5s | Was "up to 54s"; `app_fetch_messages_seconds` now shows 0.033s visible / 0.050s background. Target met — the 54s figure predates the pagination work. |
| Deferred init | avg 2.5s | < 1s | `app.deferred_init` histogram (the Sentry `app.deferredInit` transaction agrees). Still the largest startup cost — audit what's loaded eagerly. |
| Sessions frozen-frame p95 | 388 ms on `home` / 7d (69 frozen frames); build 245500 Mission Control max 175 ms | < 100 ms, no growth by session bucket/view | `session_count_bucket` proved the build-245500 recurrence was at 200 sessions; `sessions.mission_control.model` disproved grouping as the remaining bottleneck. Frame metrics now also label `sessions_view`, and `app.ui.frozen_frame_build` / `app.ui.frozen_frame_raster` split future freezes into UI-build versus GPU-raster cost. Re-baseline after lazy workspaces and bounded activity animation reach production. |
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
| Settings | Done | Language, voice, agents & tools, features, profiles, usage, developer, machines, changelog, Claude Connect; declarative hub with search; theme picker inline; server settings reachable from the hub (20 screens) |
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
