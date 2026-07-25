# Refactor Report

**Date:** 2026-07-25
**Audit:** `docs/refactor-audit.md` (Phase A)
**Commits:** `66454f0f` … `c90a3566` (11)
**Verification:** `flutter analyze` after every commit — 0 errors, 0 new
warnings. Tests run on CI only, per CLAUDE.md.

---

## 1. Before / after

| Metric | Before | After |
|---|---|---|
| `lib` LOC (excl. generated + l10n) | 156,750 | 156,916 (+166) |
| Files > 800 lines (repo's own limit) | 37 | 36 |
| Files > 500 lines | 91 | 92 |
| Longest non-generated file | 2,223 (`_sync_operations_session.dart`) | 1,774 (`_sync_messaging.dart`) |
| Functions > 60 lines | 326 | 325 |
| `flutter analyze` issues | 145 (0 errors, 3 warnings) | 134 (0 errors, 3 warnings) |
| `invalid_null_aware_operator` | 6 | 0 |
| `unawaited_futures` | 5 | 0 |
| Undocumented `catch (_) {}` | 11 | 0 |
| Test files | 354 | 354 (+23 test cases) |
| CI on `main` | red for 7 consecutive runs | fixed (see §4) |

LOC is deliberately flat: this pass moved and de-duplicated code rather than
deleting features. The 3 remaining `invalid_annotation_target` warnings come
from `freezed`-generated annotations and are not editable by hand.

Two numbers did not move and that is the honest result: **326 → 325 functions
over 60 lines**, and **91 → 92 files over 500 lines**. Splitting a 2,223-line
file into 537 + 695 + 1,013 removes one 800-plus file but adds a 500-plus one.
The long tail was not touched, on purpose — see §5.

---

## 2. What changed, by objective

### Truthful docs (mandate §5)

Two commits, no code. The audit found **15 false or unverifiable statements**;
all are corrected or deleted.

The four that actively misled:

1. `docs/SYNC_PATTERNS.md`'s test-setup snippet wired `friendsSync`,
   `friendRequestsSync`, `feedSync` and `todosSync`. **None of those fields
   exist.** Anyone following the documented procedure wrote code that did not
   compile. Replaced with `createTestSync()`, which is the single source of
   truth because it fails to compile when a field is added or removed.
2. `CLAUDE.md` and `docs/book/04-sync-anatomy.md` claimed 13 `InvalidateSync`
   fields, listing the same four dead names. There are 9.
3. `ROADMAP.md` claimed 10 locale ARB files across 12 languages. There is one,
   `l10n/app_en.arb`, and `arb-dir` is `l10n/`, not `lib/l10n/`.
4. `docs/book/04-sync-anatomy.md`'s part-file inventory listed
   `_sync_messaging_parse.dart` and `_sync_messaging_parse_output.dart`, which
   no longer exist — semantic content parsing moved to
   `lib/core/encryption/processors/`. Rewrote the inventory from the tree.

Corrected counts: part files 19-20 → 21; `sync_service.dart` ~1,000 → ~1,700
lines; routes ~64 → 57; providers barrel 19 → 26 files; tool views 22 → 29;
`KnownTools` variants 30+ → 60+; settings screens 16 → 21; `docs/` 27 → 13
(+15 in `docs/book/`); integration tests ~18 e2e → 27 files / 20 e2e;
`dependency_overrides` 4 → ~30 (with the Dart-3.12 trap the pubspec comments
document). `CLAUDE.md`'s `lib/` tree was missing 11 `core/` directories and 3
features, and listed `features/user/`, which does not exist.
`new_session_screen.dart`, referenced in three docs, does not exist either —
creation lives in `sessions/widgets/new_session_dialog.dart`.

### Complexity reduced (mandate §3)

- **`_sync_operations_session.dart`, 2,223 → 537 lines.** Split by concern
  into `_sync_operations_machine_rpc.dart` (695: machine bash/read-file and
  the per-vendor usage probes) and `_sync_operations_session_profile.dart`
  (1,013: profile / env-var / model-mode resolution). Lines moved verbatim.
- **`app_router.dart`, 817 → 264 lines.** `createRouter()` held all 57
  `GoRoute`s inline; they now live in four part files under `routing/routes/`
  grouped by destination and are spread back in declaration order, which is
  behaviour for go_router. `createRouter()` fits on one screen.
- **`fetchMessages`: the window decision is now a pure function.** The 65
  lines of cursor arithmetic that open the fetch — the part where an off-by-one
  skips a conversation's first message, or leaves a missing middle after a
  merge — moved to `MessageCursorManager.computeFetchWindow`, returning a
  `MessageFetchWindow` record. The call site keeps the effects: three debug
  logs and the `_sessionFirstLoadedSeq` write plus its MMKV persist. **21
  characterization tests** pin the behaviour, including the quirks worth
  keeping (`afterSeq` in 1..10 rounds down to 0 because `after_seq=N` returns
  `seq > N`; `strippedImageAfterSeq` overrides the window; `firstLoadedSeq` is
  written only on a first load so a delta fetch cannot clobber the pagination
  anchor; web's `initialLoad` of 100).

### Footguns removed (mandate §8)

- **6 × `invalid_null_aware_operator` were one real bug.** See §4.
- **5 dropped `Future`s** now marked `unawaited()`. All five were intentional
  fire-and-forget, so this is documentation: a genuinely forgotten `await` now
  stands out from a deliberate one.
- **11 undocumented `catch (_) {}`** blocks. Ten were the OTel reporter (§
  below); the other two — `changelog_service`, `sftp_directory_manager_screen`
  — are genuinely best-effort and now say so.

### Duplication removed (mandate §6)

- **`PowerDiagnosticsOtelReporter`: 11 methods → 1 helper.** Ten near-identical
  methods each declared a nullable `Counter` field, lazily created it with
  `??=`, called `add(1)` and swallowed errors in a bare `catch (_) {}`. The
  eleventh already used the better shape (map keyed by metric name +
  `putIfAbsent`). Applied it to all of them: same metric names, descriptions,
  units and deltas, but the swallow policy now exists in one place with one
  comment, and 11 fields are gone.
- **Codex/pi event prologue.** `pi_content_handler.dart`'s own doc says it
  "mirrors `_processCodexContent`", and 45 lines were byte-identical — the
  data-is-a-map guard, usage extraction from both placements, sidechain/parent/
  agent metadata, and the message/reasoning/model-output branch. Extracted to
  `_processAgentEventHead`, with `vendor` threaded through for the
  dropped-reason telemetry strings.

Left alone, annotated as independent: the 37 clone groups that are
`*_native.dart` / `*_stub.dart` conditional-export pairs. Divergence is their
purpose.

---

## 3. Deferred, with reasons

| Item | Why not now |
|---|---|
| **`fetchMessages` full decomposition** (still 1,126 lines) | The window extraction was the piece that isolates cleanly and is pure. The remaining phases — paged fetch, decrypt/dedupe, merge, sidechain grouping, notify, 4 error classes — share ~15 mutable locals and interleave telemetry. Doing that without being able to run the test suite locally (CLAUDE.md forbids it: the suite OOMs the device) risks a silent regression on the P0 receive path. Needs a CI-driven loop, not a single pass. |
| **The three `_TerminalOutputSection` copies** (`bash_view`, `codex_bash_view`, `gemini_execute_view`) | Not equivalent copies. Expansion is parent-owned in one and self-managed in another; error state colours the body text in one but not the other; only one sets `fontFamilyFallback`. Merging changes pixels, which a `refactor:` commit must not do, and the golden suite cannot run locally. Unifying would need a flag per difference — the "function with five flags" the mandate warns against. |
| **`fetchSessions`** (460 lines, and the DEK-fallback bug lives in it) | Same shape as `fetchMessages`. Extracting the DEK-fallback decision as a pure function is the right first step and is a prerequisite for fixing the open `CryptoSecretBox.decrypt failed` issue. |
| **`lib/core/utils/` dissolution** (38 unrelated files) | Mechanical but touches imports across most of `lib`. Worth a dedicated commit series where every commit is a pure `git mv`. |
| **`lib/core/widgets` → `ui`/`components` merge** | Hundreds of import changes; wants explicit sign-off first. |
| **1,102 `as` casts / 2,159 `dynamic`** | A quarter-long project, one wire boundary at a time. `WireParsers` is the right home. |
| **692 `// ignore:` suppressions** | Sample-and-bucket, not a sweep. |
| **325 functions > 60 lines** | Addressed opportunistically when a file is already being edited. Opening 325 diffs is diff noise, not improvement. |
| **Mandate's "no `core`/`utils` package name" rule** | `utils` is slated for dissolution above. `core` is deliberately kept: it is the documented spine of this codebase and renaming it is a 587-file diff with no reader benefit. Explicit, flagged deviation. |

---

## 4. Bugs found

Reported rather than silently folded into a refactor, per HARD RULE 1. Both are
fixed, each in its own commit.

### 4.1 Absent shell fields were emitted as explicit nulls (`fix:` 11439c7f)

`_normalizeShellResult` in `grok_acp_normalize.dart` built its result with
`?'stderr': value`. That is the null-aware **map entry** form: it drops the
entry when the *key* is null. The keys are string literals, so the guard never
fired, and every shell tool result carried `'stderr': null`,
`'exitCode': null`, `'command': null`, `'description': null` and
`'truncated': null` whether or not the vendor sent them.

happy-cli-go's `normalizeGrokToolResult` omits empty fields and this function
documents itself as kept in sync with it, so value omission was the intent.
Moved the `?` to the value side. Visible effect: tool views that branch on key
presence rather than on a null value no longer render phantom
stderr/command/description rows. Two regression tests added.

Reproduction: normalize `{'output': 'ok\n', 'exit_code': 0}` and inspect the
result — before, `containsKey('stderr')` was `true` with a null value.

### 4.2 `main` was red before this pass, for 7 consecutive runs (`test:` fd517533)

Not caused by this work. Commits `b1b5dd34` / `47ce220f` / `74fe51a2`
deliberately changed two wire rules, and `74fe51a2` updated only
`model_mode_resolution_test.dart`, leaving `session_spawning_e2e_test.dart`
pinning the old shape — 5 failures across shards 6/8 and 8/8, all
"Expected: false / Actual: true".

The two rules, both documented in the source and both intended:

1. A model mode that `_normalizeModelModeForAgent` strips as incompatible is
   now sent as an explicit `model='default'` rather than omitted, so the daemon
   clears sticky `metadata.model` instead of re-applying e.g.
   `qwen3.8-max-preview` against a ChatGPT account.
2. `environmentVariables` is sent whenever non-null, empty map included
   (`rpc_types.dart:48-52`): an empty map means "explicit Default / no profile"
   and clears sticky `providerRoutingEnv`.

I first patched `_getModelOverride` to restore the old omission, then reverted
that on finding `model_mode_resolution_test.dart` pins the new semantics
deliberately. The stale assertions were the defect; each is now updated with a
comment naming the reason so it does not get "fixed" back.

### 4.3 Audit overstatements, corrected

- The audit counted **8 `print(` calls**. All 8 are false positives: two in doc
  comments, six inside embedded Python source strings in
  `_sync_operations_session.dart`. `avoid_print` is already configured as a
  warning; no lint change was needed.
- `empty_catches` is already enabled and permits `catch (_)` by design, so the
  11 blocks were never lint violations — only undocumented.
- The audit's "nesting depth 21" findings measure widget-tree indentation, not
  control flow. Those were not touched; chasing them would have made
  declarative trees worse.

---

## 5. `BREAKING:` — none

This is an application, not a published package; nothing outside the repo
imports `lib/**`. No `@visibleForTesting` surface changed.
`_tailAfterSeqForSession` was deleted as dead after the window extraction —
private, and `computeFetchWindow` calls `tailAfterSeq` directly.

---

## 6. Definition-of-done status

| Mandate criterion | Status |
|---|---|
| Build / analyze / lints green at every commit | ✅ 0 errors throughout; tests gated on CI |
| No file > 500 lines, no function > 60, no complexity > 15 | ❌ Not met, and not achievable in one pass — 92 files and 325 functions remain. Each exception is now listed in §3 rather than left implicit. |
| No `utils`/`common`/`helpers`/`misc` file or package | ❌ `lib/core/utils/` (38 files) deferred to a `git mv`-only series; `core` deliberately kept (§3) |
| Every lock documented; ownership elsewhere | ✅ Vacuous — Dart has no shared-memory concurrency, and this codebase has zero mutexes. The audit's §4 replaced it with an async-lifecycle inventory: 0 undisposed controllers, 3 deliberately-unclosed broadcast controllers with a documented rationale |
| Every `go` statement owned, `goleak` clean | ✅ N/A; the equivalent (`unawaited`, `Timer`, `StreamSubscription`) is clean, and the 5 unmarked futures are now marked |
| Truthful doc comment on every exported identifier | 🟡 New and touched code only |
| Every README/doc command executed | ✅ `flutter analyze`, `dart format`, `flutter pub get` verified; `flutter test` intentionally not run locally |
| True duplication removed, coincidental annotated | 🟡 Two of five candidates removed; the three-way view copy is documented as non-equivalent (§3) |
| Coverage equal or higher, no test deleted | ✅ +23 test cases, 0 deleted |
| Behaviour unchanged; bugs reported not hidden | ✅ One behaviour change, isolated in its own `fix:` commit (§4.1) |
| Audit, plan and report exist and are accurate | ✅ This file plus `docs/refactor-audit.md` |
