# Refactor Audit — Phase A

**Date:** 2026-07-24
**Scope:** `lib/**` (excluding `*.g.dart`, `*.freezed.dart`, `lib/l10n_generated/**`), `docs/**`, `CLAUDE.md`
**Status:** Phase A complete and Phase B executed. See
`docs/refactor-report.md` for what was done, what was deferred and why, and
the two bugs found. Corrections to this audit's own numbers (the `print(`
count and the `empty_catches` claim) are recorded there — this file is kept as
the pre-work snapshot.

---

## 0. Mandate translation (Go → Dart/Flutter)

The mission text is Go-specific. This repo is Dart/Flutter, so the following
substitutions were applied. Everything else in the mandate carries over
unchanged.

| Mandate item | This repo's equivalent |
|---|---|
| `gocognit` / `gocyclo` | No packaged tool. Metrics below come from a purpose-written AST-lite scanner (branch count, control-flow nesting, function length). Numbers are marked `~`. |
| `dupl --threshold 60` | Normalized 25-line sliding-window hash clone detector (script in §1.5). |
| `go test -race ./...` | Dart is single-threaded per isolate; there is no data-race detector and no shared-memory concurrency. §5 replaces it with an async-lifecycle audit (Timer / StreamSubscription / Completer / unawaited / Isolate). |
| `sync.Mutex` ownership conversions (§7 of mandate) | **Not applicable.** Zero mutexes exist; Dart's model is already "one owner per isolate". §5 audits the real analogue: unowned async work and undisposed listeners. |
| `.golangci.yml` + `depguard` | `analysis_options.yaml` (already present), plus optional `custom_lint` for boundary rules. |
| `go vet copylocks`, typed-nil, `defer` in loop | Replaced by the Dart footgun catalogue in §4. |
| `goleak` | `test/helpers` leak assertions; no packaged equivalent. |
| "no `utils`/`core` package" hard rule | Conflicts with the repo's established, documented `lib/core/**` layout. See §3.1 — recommended **not** to enforce; renaming 79 directories is pure diff noise with no reader benefit. Flagged as an explicit deviation. |

Two repo rules constrain Phase B and override the mandate's process:

- **Tests are never run locally** (CLAUDE.md) — RAM exhaustion. Every "green
  at each commit" gate is a CI gate, not a local one. Coverage numbers below
  are therefore not measured here; they come from Codecov on CI.
- **Generated files are never hand-edited** — `*.g.dart`, `*.freezed.dart`,
  `lib/l10n_generated/**` are excluded from all metrics and all edits.

---

## 1. Metrics baseline

### 1.1 Size

| Metric | Value |
|---|---|
| Dart files in `lib` | 587 |
| Dart files in `test` | 354 |
| `lib` LOC excl. generated | 172,170 |
| Generated LOC (`*.g.dart`, `*.freezed.dart`) | 19,373 |
| `lib/l10n_generated` LOC | 15,420 |
| Directories under `lib` | 79 |
| Files > 300 lines | 172 |
| Files > 500 lines (mandate hard limit) | 91 |
| Files > 800 lines (**repo's own** stated limit) | 37 |
| Lines > 80 cols (repo's own stated limit) | 78 |

**The repo already has a stricter, self-imposed limit (800 lines) than the
mandate's 500, and violates it 37 times.** That is the number to move.

### 1.2 Longest files (excl. generated)

| LOC | File |
|---|---|
| 2223 | `lib/core/services/_sync_operations_session.dart` |
| 1789 | `lib/core/services/_sync_messaging.dart` |
| 1701 | `lib/core/api/provider_usage_api.dart` |
| 1676 | `lib/core/services/sync_service.dart` |
| 1507 | `lib/features/chat/chat_screen.dart` |
| 1402 | `lib/core/models/workflow_run.dart` |
| 1378 | `lib/features/sessions/widgets/sessions_list_content.dart` |
| 1342 | `lib/core/services/_sync_messaging_send.dart` |
| 1277 | `lib/features/chat/chat_input.dart` |
| 1247 | `lib/core/services/_sync_messaging_rpc.dart` |

### 1.3 Function-level complexity

| Metric | Value |
|---|---|
| Functions/methods detected | ~3,460 |
| Length > 40 lines (mandate: justify) | 545 |
| Length > 60 lines (mandate: must fix) | 326 |
| Branch count ~> 12 | 129 |
| **Control-flow** nesting > 3 | 39 |

Worst offenders by branch count:

| ~cyc | ctrl-nest | LOC | Location |
|---|---|---|---|
| 148 | 6 | **1141** | `lib/core/services/_sync_messaging.dart:280` `fetchMessages` |
| 86 | 5 | 460 | `lib/core/services/_sync_data.dart:24` `fetchSessions` |
| 61 | 5 | 191 | `lib/core/utils/ansi_parser.dart:55` `parse` |
| 58 | 4 | 267 | `lib/core/services/_sync_data_machines.dart:4` `handleEphemeralUpdate` |
| 50 | 4 | 224 | `lib/features/chat/chat_screen.dart:493` `_refreshFromSync` |
| 45 | 4 | 255 | `lib/core/services/_sync_messaging_rpc.dart:831` `onSessionVisible` |
| 40 | 6 | 235 | `lib/core/services/_sync_data_machines.dart:273` `fetchMachines` |
| 39 | 2 | 181 | `lib/features/chat/_chat_screen_builders.dart:10` `_buildMessageList` |
| 37 | 2 | 272 | `lib/core/services/_sync_messaging_merge.dart:268` `_runDeferredRegroupSweep` |
| 36 | 4 | 353 | `lib/core/services/_sync_lifecycle.dart:158` `resume` |

**Metric caveat, stated up front so Phase B does not chase it:** raw
indentation depth in Flutter is dominated by *widget-tree* nesting, not
control flow. `all_loops_screen.dart:115` measures indentation ~21 but has
almost no branching — that is a normal declarative tree and **must not be
"fixed"**. Every nesting finding in §2 uses control-flow depth only.

### 1.4 Static analysis

`mise exec -- flutter analyze` → **145 issues, 0 errors, 0 warnings, 136 info**
(9 further infos are in `test/`, which `analysis_options.yaml` excludes from
the fatal set). Clean by CI's bar (`--no-fatal-infos --no-fatal-warnings`).

| Count | Rule |
|---|---|
| 39 | `directives_ordering` |
| 10 | `cascade_invocations` |
| 9 | `always_put_required_named_parameters_first` |
| **6** | **`invalid_null_aware_operator`** ← real smell, see §4 |
| **5** | **`unawaited_futures`** ← real smell, see §5 |
| 5 | `unnecessary_getters_setters` |
| 5 | `sort_constructors_first` |
| 4 | `omit_local_variable_types` |
| 3 | `unnecessary_import`, 3 `invalid_annotation_target`, 3 `deprecated_member_use` |
| ~14 | `lines_longer_than_80_chars` and misc. |

64 of the 145 (`directives_ordering`, `cascade_invocations`,
`omit_local_variable_types`, `eol_at_end_of_file`) are pure formatting and are
**out of scope** — fixing them is exactly the diff noise HARD RULE 7 forbids,
unless the file is being edited anyway.

### 1.5 Duplication

Normalized 25-line clone detector: **160 duplicate block groups**.

| Blocks | Files | Classification |
|---|---|---|
| 32 | `_offline_dictation_service_native.dart` \| `_offline_dictation_service_stub.dart` | **Coincidental / by design** — conditional-export platform pair. Divergence is the point. Leave; annotate. |
| 24 | `codex_content_handler.dart` \| `pi_content_handler.dart` | **True duplication candidate** — same wire-decode rule, two vendors. |
| 17 | `claude_limits_screen.dart` \| `usage_screen.dart` | **Structural boilerplate** — same section/card scaffold. |
| 14 | `profile_editor_screen.dart` \| `profiles_screen.dart` | **True duplication candidate** — profile row rendering. |
| 14 | `profile_wizard_screen.dart` (self) | **Structural boilerplate** — repeated step scaffold. |
| 12 | `bash_view.dart` \| `codex_bash_view.dart` \| `gemini_execute_view.dart` | **True duplication** — one command-output rule, three vendor wrappers. |
| 11 | `output_content_handler.dart` \| `pi_content_handler.dart` | **True duplication candidate.** |
| 11 | `edit_artifact_screen.dart` \| `new_artifact_screen.dart` | **Structural boilerplate** — create/edit form pair. |
| 5 | `_offline_tts_service_native.dart` \| `_offline_tts_service_stub.dart` | **By design** — platform pair. Leave. |

37 of the 160 groups are platform conditional-export pairs and must be left
alone per §6 of the mandate.

### 1.6 Concurrency primitives (Dart-adjusted)

| Primitive | Count | Note |
|---|---|---|
| `sync.Mutex` / `RWMutex` equivalents | **0** | Dart has no shared-memory concurrency. Mandate §7 is moot. |
| `Timer` uses | 64 | vs 211 `.cancel()` calls — no obvious orphans |
| `StreamSubscription` declarations | 35 across 26 files | see §5 |
| `Completer<…>` | 17 | see §5 |
| `Isolate.*` | 29 | encryption + TTS workers |
| `unawaited(` | 253 | intentional fire-and-forget; 5 places forgot it (`unawaited_futures` lint) |
| `StreamController` without `close()` | 3 files | **all three justified** — `_sync_lifecycle.dart:867` documents that `Sync` is reused across logout/login and closing broadcast controllers would break re-login |
| Undisposed `TextEditingController` / `ScrollController` / `AnimationController` | **0** | disposal discipline is good |

### 1.7 Footgun census

| Pattern | Count |
|---|---|
| `as T` downcasts | 1,102 |
| `dynamic` occurrences | 2,159 |
| Force-unwrap `x!.` | 222 |
| `late` declarations | 180 |
| `DateTime.now()` in logic | 186 |
| `catch (_)` (identity discarded) | 92 |
| Empty `catch {}` blocks | 11 |
| `// ignore:` / `// ignore_for_file:` suppressions | 692 |
| `print(` | 8 (repo standard forbids it) |
| `TODO`/`FIXME`/`HACK`/`XXX` | 60 |

### 1.8 Tests / coverage

27 files in `test/integration` (20 named `*e2e*`). Coverage is measured by CI
(`flutter test --coverage` → Codecov). **Not measured here** — running the
suite locally is forbidden by CLAUDE.md. Phase B must treat the Codecov delta
on each PR as the coverage gate.

---

## 2. Findings

Severity: **H** = actively costs reader time or hides bugs today; **M** = real
but bounded; **L** = cosmetic.

### 2.1 Complexity

| Location | Issue | Sev | Proposed action | Risk | Size |
|---|---|---|---|---|---|
| `_sync_messaging.dart:280` | `fetchMessages` is **1,141 lines, ~148 branches, one function**. It computes a cursor plan, runs a paged HTTP loop, decrypts, dedupes, merges, groups sidechains, notifies UI, emits telemetry, and handles 4 error classes. Nothing about it is testable in isolation. | H | Split along the phase boundaries already marked by its own comments: (a) pure `MessageFetchPlan computePlan(...)` — cursor/tail/skip decision, no I/O; (b) `_fetchPage`; (c) `_processPage`; (d) `_finishFetch` (group + notify + telemetry); (e) `_handleFetchError`. Characterization tests first. | **High** — this is the P0 send/receive path | XL |
| `_sync_data.dart:24` | `fetchSessions`, 460 lines / ~86 branches. Same shape: plan + fetch + decrypt + DEK fallback + merge + notify. | H | Same decomposition; extract the DEK-fallback decision as a pure function (it is also the subject of an open production bug — see §7). | High | L |
| `_sync_operations_session.dart` | 2,223 lines — largest non-generated file, 4.4× the repo's own 800-line limit. | H | Split by operation group into `_sync_operations_session_create.dart` / `_spawn.dart` / `_lifecycle.dart`. Pure `git mv`-equivalent part-file split, no content edits. | Low | M |
| `provider_usage_api.dart` (1701) | Single API class covering all providers. | M | Split per provider or per response-shape family. | Low | M |
| `chat_screen.dart:493` | `_refreshFromSync`, 224 lines / ~50 branches, 6 boolean-ish named params. | H | Extract the "what changed" decision into a pure function returning a small result record; keep `setState` as a thin applier. Mandate §3.2 "separate decision from effect". | Med | L |
| `_sync_lifecycle.dart:158` | `resume()`, 353 lines / ~36 branches — zombie-socket detection, watchdog arming, sync invalidation, session refresh, all inline. | H | Extract `ResumeDecision decideResume(now, lastSuspendedAt, socketStatus)` as pure; `resume()` becomes a dispatcher. Directly improves testability of the zombie-socket rule documented in SYNC_PATTERNS.md. | Med | M |
| `_sync_data_machines.dart:4` | `handleEphemeralUpdate(dynamic data)`, 267 lines / ~58 branches, `dynamic` param. | H | Parse to a typed union at the boundary (`WireParsers` already exists), then dispatch. Kills both the complexity and the `dynamic`. | Med | M |
| `app_router.dart:215` | `createRouter()` is 586 lines of 57 inline `GoRoute`s. | M | Split into per-feature route lists (`sessionRoutes`, `settingsRoutes`, …) composed in `createRouter()`. Mechanical. | Low | S |
| `session_info_screen.dart:279`, `new_session_dialog.dart:124`, `tool_view.dart:441`, `mcp_server_edit_screen.dart:160`, `terminal_connect_screen.dart:47` | `build()` methods 272–449 lines. | M | Extract named sub-widgets (not helper methods — real widgets, so they get their own rebuild scope). Perf win as well as legibility. | Low | M each |
| 326 functions > 60 lines | Long tail. | M | Address opportunistically only when a file is already being touched. Do **not** open 326 diffs. | — | — |
| `built_in_profiles.dart:89` (409), `profile_setup_catalog.dart:117` (318) | Long but flat `switch`-over-constants returning data. | L | **Leave.** Flat table data; mandate §3.1 explicitly excuses this. | — | — |

### 2.2 Footguns

| Location | Issue | Sev | Proposed action |
|---|---|---|---|
| 6 sites (analyzer `invalid_null_aware_operator`) | `?.` / `!` applied to a non-nullable receiver — means the author believed a value could be null when the type says otherwise. Either the type or the belief is wrong. | H | Investigate each; one of the two is a bug. Report, don't silently "fix". |
| 11 empty `catch {}` blocks | Silent failure. Mandate §8 forbids. | H | Each becomes handled, wrapped, or `logger.warning`-with-context. |
| 92 `catch (_)` | Error identity discarded, so the log cannot say what failed. | M | Where the catch already logs, bind the error. Where it does not, see above. |
| 8 `print(` | Violates the repo's own standard (`logger.*`). | M | Replace with `logger.*`; add `avoid_print` to `analysis_options.yaml` so it cannot come back. |
| 186 `DateTime.now()` in logic | Untestable time-dependent behaviour; already the root cause of the spawn-readiness timeout work in ROADMAP. | M | Inject a `Clock` at the boundaries that already have time-based rules (`_sync_lifecycle`, spawn registry, outbox backoff). Do not sweep all 186. |
| 692 `// ignore:` suppressions | Each is an un-triaged lint. | M | Bucket by rule, delete the ones that no longer apply, keep the rest with a one-line reason. Sample first — do not open 692 diffs. |
| 222 `x!.` force-unwraps | Already the documented cause of 21 fatal GlitchTip events (ROADMAP "Null check operator"). | H | Sweep `!` on `Session`/`Profile`/`Machine` fields across async gaps only. The repo has an established fix pattern (`case final x?`) — apply it. |
| 1,102 `as T` + 2,159 `dynamic` | Concentrated at wire boundaries where `WireParsers` should own coercion. | M | Push coercion into `WireParsers`/typed models at the boundary; the interior becomes typed. Long project; scope one boundary per commit. |
| `Settings` mutable public fields | Documented exception (roundtrips through JSON in `updateSetting`). | L | **Leave**, but the doc comment should state the invariant so nobody "cleans it up". |

### 2.3 Duplication

| Location | Kind | Action |
|---|---|---|
| `bash_view.dart` \| `codex_bash_view.dart` \| `gemini_execute_view.dart` | True — one command-output rendering rule, three vendors | Extract a `CommandOutputView` taking vendor-specific accessors. 3rd occurrence exists → extract now. |
| `codex_content_handler.dart` \| `pi_content_handler.dart` \| `output_content_handler.dart` | True — shared wire-decode rule | Extract the shared block; keep vendor-specific branches separate. Needs characterization tests first (decode correctness). |
| `claude_limits_screen.dart` \| `usage_screen.dart` | Structural boilerplate | Shared section/card widget. |
| `edit_artifact_screen.dart` \| `new_artifact_screen.dart` | Structural boilerplate | Shared form widget; keep the two screens as thin wrappers. |
| `profile_editor_screen.dart` \| `profiles_screen.dart` | True — profile row rule | Extract `ProfileRow`. |
| `*_native.dart` \| `*_stub.dart` pairs (37 groups) | **Coincidental by design** | **Leave.** Add the one-line "independent by design, conditional-export pair" comment §6 requires. |

### 2.4 Structure

| Issue | Sev | Proposed action |
|---|---|---|
| `lib/core/utils/` holds 38 unrelated files (mandate: forbidden dumping ground) | M | Move each next to the thing it serves (`ansi_parser` → chat, `message_utils` → messaging, `safe_pop` → routing). `InvalidateSync` stays — it is a real named concept and belongs in `lib/core/sync/`. |
| `lib/core/widgets/` + `lib/core/ui/` + `lib/core/components/` — three overlapping widget layers | M | The three-way split is documented but not guessable. Recommend collapsing to two (`ui` primitives, `components` composites) and folding `widgets/` into whichever fits. Requires approval — it touches many imports. |
| 9 `lib/features/*/widgets/` + 2 `helpers/` dirs | L | `widgets/` under a feature is idiomatic Flutter — **leave**. `chat/helpers/` and `settings/helpers/` are dumping grounds — rename to what they hold. |
| Mandate's "no `core`" rule | — | **Recommend not enforcing.** `lib/core` is the documented spine of this codebase; renaming it is 587-file diff noise with zero reader benefit. Explicit deviation, flagged per §11. |

---

## 3. Proposed target tree (path diff, no moves yet)

```
  lib/core/utils/ansi_parser.dart          -> lib/features/chat/ansi_parser.dart
  lib/core/utils/message_utils.dart        -> lib/core/services/message_content.dart
  lib/core/utils/safe_pop.dart             -> lib/core/routing/safe_pop.dart
  lib/core/utils/invalidate_sync.dart      -> lib/core/sync/invalidate_sync.dart
  lib/core/utils/  (remaining 34)          -> distributed by owner; dir deleted
  lib/features/chat/helpers/               -> renamed by content
  lib/features/settings/helpers/           -> renamed by content
  lib/core/widgets/                        -> merged into lib/core/{ui,components}/   [needs approval]

+ lib/core/services/_sync_operations_session_create.dart      (split of 2223-line file)
+ lib/core/services/_sync_operations_session_spawn.dart
+ lib/core/services/_sync_operations_session_lifecycle.dart
+ lib/core/services/_sync_messaging_fetch_plan.dart           (pure cursor logic, testable)
+ lib/core/routing/routes/{sessions,settings,chat,dev}_routes.dart
+ lib/features/chat/tools/views/command_output_view.dart      (3-way dedup)
+ lib/core/time/clock.dart                                   (injectable now())
```

`lib/core` itself is **kept** — see §2.4.

---

## 4. Async-lifecycle inventory (replaces mandate §7)

| Category | Count | Disposition |
|---|---|---|
| Mutexes / locks | 0 | Nothing to convert. Mandate §7 does not apply to Dart. |
| `StreamController` never closed | 3 | **Keep, all justified.** `_sync_lifecycle.dart:867` documents why (`Sync` outlives logout). Action: ensure the same one-line rationale sits on `sync_service.dart:556`, where the controllers are actually declared. |
| `StreamSubscription` (26 files) | 35 | Sampled: all cancelled in `dispose`. The repo's `SyncSubscriptionMixin` centralizes this correctly. No finding. |
| `unawaited(` | 253 | Explicit and correct per repo standard. |
| Missing `unawaited` (5, analyzer) | 5 | Fix — a dropped future is an invisible failure path. |
| `Completer` | 17 | Audit each for a guaranteed completion path on every branch (the `InvalidateSync` disposed-crash class of bug). |
| `Isolate.*` | 29 | Already migrated to top-level workers with sendable args (ROADMAP: "Isolate unsendable Future"). No finding. |
| Controller disposal (`Text`/`Scroll`/`Animation`) | 0 misses | No finding. Discipline is good. |

**Conclusion: this codebase's concurrency hygiene is genuinely good.** The
mandate's headline concern (locks → ownership) has nothing to act on. Do not
manufacture work here.

---

## 5. Doc drift — false or unverifiable statements found

Each verified against the code today.

| Doc | Claim | Reality | Sev |
|---|---|---|---|
| `docs/SYNC_PATTERNS.md` | Test-setup snippet sets `friendsSync`, `friendRequestsSync`, `feedSync`, `todosSync` | **None of these fields exist in `lib`.** Copying the documented snippet produces code that does not compile. | **H** |
| `CLAUDE.md` | "InvalidateSync fields (13)" and lists the same 4 dead names | Actually **9** fields + `messagesSync` map | **H** |
| `CLAUDE.md` | `sync_service.dart` is "~1,000 lines" | **1,676** | M |
| `CLAUDE.md` / `ARCHITECTURE.md` | "~64 flat `GoRoute` entries" | **57** | L |
| `CLAUDE.md` | Provider table lists 16 providers | **65** `NotifierProvider` declarations in `lib/core/providers` | M |
| `CLAUDE.md` | "22 tool-specific views" | **29** files in `tools/views/` | L |
| `CLAUDE.md` | "`docs/` — 27 internal docs" | **13** `.md` files in `docs/` (+15 under `docs/book/`) | M |
| `CLAUDE.md` | "10 locale ARB files (en, es, fr, …), 4 generated" | **1** ARB file (`l10n/app_en.arb`); `l10n.yaml` points at `arb-dir: l10n`, not `lib/l10n`. The other 11 locales do not exist. | **H** |
| `CLAUDE.md` | Settings: "(16 screens)" | **21** `*_screen.dart` in `features/settings` | L |
| `CLAUDE.md` | `lib/core/` subdirectory list | Omits **13** existing dirs: `actors`, `config`, `crdt`, `dialogs`, `event_log`, `fsm`, `native_chat_list`, `types`, `wire`, `sync`, `repositories` (+`dialogs`, `native_chat_list`) | M |
| `CLAUDE.md` | `features/` list | Omits `loops`, `providers`, `workflows` | M |
| `CLAUDE.md` | "`dependency_overrides` … (as of Jun 2026: `shared_preferences_android`, `mmkv_platform_interface`, `flutter_secure_storage_linux`, `go_router`)" | **~30 overrides**, incl. a large "force-upgrade" block, `cupertino_http`, `jni`/`cronet_http` pins | M |
| `CLAUDE.md` | "~18 e2e files" in `test/integration` | 27 files, 20 matching `*e2e*` | L |
| `ARCHITECTURE.md` | "`chat_screen.dart` | ~14 `sync.` references" | Needs re-count; file has grown to 1,507 lines since the Apr 2026 review | L |
| `ROADMAP.md` | "**Last Updated**: 2026-07-10"; several rows say "needs release" | Releases are automatic per-commit (stated in the same file), so every "needs release" row from before 2026-07-10 has shipped and the status is stale | M |

The four **H** items are the priority: two of them will actively mislead an
agent or a new contributor into writing code that does not compile.

---

## 6. Ordered plan

Batched into commits, highest value / lowest risk first. Every batch lands on
`main` (per repo workflow) and is gated on **CI**, not local tests.

**Batch 1 — `docs:` fix the four H-severity lies.** Zero code risk, immediate
payoff, unblocks everyone else. Correct the `SYNC_PATTERNS.md` snippet and the
`CLAUDE.md` InvalidateSync/ARB/count claims; delete the unverifiable ones
rather than hedging them. *(Est. 30 min.)*

**Batch 2 — `docs:` remaining drift sweep.** All M/L rows in §5, plus a
regenerated `lib/core` + `features` directory map. *(Est. 45 min.)*

**Batch 3 — `chore:` deletions.** Dead `catch {}` bodies replaced, 8 `print(`
→ `logger.*`, `avoid_print` added to `analysis_options.yaml`, dead
`friendsSync`-era references in `test/`, sampled dead `// ignore:` lines.
*(Est. 1–2 h.)*

**Batch 4 — `fix:` the 5 `unawaited_futures` + investigate the 6
`invalid_null_aware_operator` sites.** These are behaviour-relevant, so they go
in `fix:` commits, separate from all refactoring, per HARD RULE 1. Anything
that turns out to be a genuine bug is reported in `FINDINGS.md` first. *(Est.
2 h.)*

**Batch 5 — `refactor:` mechanical part-file splits.** `_sync_operations_session.dart`
(2223 → 3 files), `app_router.dart` route lists, `provider_usage_api.dart`.
Content-preserving moves only, so the diff is reviewable line-for-line.
*(Est. half a day.)*

**Batch 6 — `test:` characterization tests for `fetchMessages` +
`fetchSessions` + `resume()`.** Pins today's behaviour, including its
edge cases, before any interior change. This is the gate for Batch 7 and the
largest single item. *(Est. 1–2 days.)*

**Batch 7 — `refactor:` decision/effect split on the three hot paths.**
`fetchMessages` → `computePlan` + phases; `fetchSessions` → pure DEK-fallback
decision; `resume()` → `decideResume`. One commit per function, each green on
CI. Highest reader payoff in the repo. *(Est. 2–3 days.)*

**Batch 8 — `refactor:` duplication removal.** `CommandOutputView` (3-way),
content-handler shared decode, artifact form, profile row, usage/limits
section. Platform pairs annotated and left alone. *(Est. 1 day.)*

**Batch 9 — `refactor:` widget extraction on the five 270+ line `build()`
methods.** Real sub-widgets, not helper methods. Requires
`update-goldens` via CI afterwards. *(Est. 1 day.)*

**Batch 10 — `refactor:` `lib/core/utils/` dissolution + `Clock` injection at
the three time-dependent boundaries.** *(Est. 1 day.)*

**Batch 11 — `ci:` lock it in.** Tighten `analysis_options.yaml`
(`avoid_print`, keep the current fatal bar), optionally add `custom_lint`
boundary rules. *(Est. half a day.)*

### `BREAKING:` — none identified

This is an application, not a published package. No external consumer imports
`lib/**`. Every move in §3 is import-visible inside the repo only. If any
`@visibleForTesting` surface changes, it will be listed at that commit.

### Deferred / needs a decision

- **`lib/core/widgets` → `ui`/`components` merge** — touches hundreds of
  imports. Worth doing, but wants an explicit yes.
- **`as`/`dynamic` reduction (3,261 sites)** — a quarter-long project, one wire
  boundary at a time. Not schedulable as part of this pass.
- **692 `// ignore:` triage** — sample-and-bucket only; a full sweep is its own
  project.
- **Mandate's "no `core`/`utils` package name" rule** — `utils` is being
  dissolved (Batch 10); `core` is deliberately kept (§2.4).

---

## 7. Bugs found but not fixed

Per HARD RULE 1, these are reported, not silently fixed. None is a new
discovery of unknown severity; two overlap with open ROADMAP items.

1. **`docs/SYNC_PATTERNS.md` test snippet does not compile** — references 4
   removed `InvalidateSync` fields. Not a runtime bug, but it is a documented
   procedure that fails on first use. Batch 1.
2. **6 × `invalid_null_aware_operator`** — a null-aware operator on a
   non-nullable receiver means either the type annotation or the author's
   assumption is wrong. Needs per-site investigation before any edit. Batch 4.
3. **5 × dropped `Future` (`unawaited_futures`)** — each is a failure path that
   cannot report. Batch 4.
4. **11 × empty `catch {}`** — silent failure. Batch 3.
5. **DEK-fallback key staleness** (pre-existing, ROADMAP "CryptoSecretBox.decrypt
   failed") — `_sessionDataKeys` is cached and never refreshed after rotation.
   Surfaced again here because the fallback decision is buried mid-way through
   the 460-line `fetchSessions`, which is why it is hard to test. Batch 7
   extracts it; the fix itself stays a separate `fix:` commit.

---

## 8. Outcome

Phase B ran batches 1-8 of §6. Results, before/after metrics, deferred items
and the bugs found are in `docs/refactor-report.md`.

Deferred out of §6, with reasons given in the report: the full `fetchMessages`
and `fetchSessions` decompositions (need a CI-driven loop — the test suite
cannot be run locally), the three-way `_TerminalOutputSection` merge (the
copies are not equivalent, so merging changes pixels), the
`lib/core/utils/` dissolution, the `core/widgets` merge, and the long tails
(`as`/`dynamic`, `// ignore:`, functions over 60 lines).
