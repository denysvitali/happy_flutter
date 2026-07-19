---
name: ci-flake-triage
description: Diagnose a red happy_flutter CI run by first checking against the known-flake corpus before treating it as a regression. Use when the user says "CI is red", "main is red", "shard failing", or a push comes back with failing checks.
---

# CI Flake Triage

Before diagnosing a red run as a regression, check it against the known flake corpus. Most "main red" episodes here were pre-existing shard failures unrelated to the triggering commit.

## Step 1: Get the failure

```text
mcp__gh-actions__list_runs / mcp__gh-actions__diagnose_failure
```

Note which job/shard failed and the first real error line.

## Step 2: Match against known flakes

| Signature | Cause | Action |
|-----------|-------|--------|
| Test job killed after ~2.5 min, no test failure output | CI runner reclaim — `flutter_test` shutdown hang; pods die past ~2.5 min | Known infra issue; `ci.yml` has a timeout-wrapper workaround. Retry the job, don't debug tests. |
| Timer/clock assertion flake, passes on rerun | fakeAsync-vs-real-clock gate pattern | Rerun. If recurrent in one file, wrap the gate in fakeAsync properly. |
| `ApiClient` not initialized in a shard | Pre-existing shard failure (seen in the 2026-06-13 and 2026-06-30 main-red episodes) | Not caused by your commit — check if the same shard failed on the parent commit. |
| Secure-storage / encryption fake setup errors across shards 1/5/6/7/8 | Same 2026-06-30 episode family | Same check: compare with parent commit's run. |
| `empty_session` parser null-check, `tool_view` RenderFlex | Pre-existing failures from 2026-06-13 episode | Verify still-known before re-diagnosing. |
| Golden mismatch after UI change | Stale goldens | Use the `update-goldens` skill. |
| Check annotations echo passing test lines (e.g. `write_view_test.dart`) with identical window across runs | Can be EITHER the infra kill OR a real failure — the annotation window (`grep -B 20`) lands on the same recent-output lines regardless | Pull the full job log and search `[E]` / `TestFailure` / `RangeError` before calling it a flake. 2026-07-19 episode: shard 5 looked like the infra kill on 3 consecutive runs but was a real `profile_editor_screen_test.dart` bug (off-screen tap + lazy-ListView `.at(2)` index). |

**Lazy-ListView test trap:** in widget tests over a scrollable form, `find.byType(TextFormField).at(N)` counts only *built* children. Scrolling (e.g. `ensureVisible`) unmounts off-cache fields and shifts every index — find fields by content (`find.widgetWithText(TextFormField, 'VALUE')`) instead, and `ensureVisible` before any `tap()` below the 800x600 fold.

**Decision rule:** run the same shard against the parent commit (or check its run history). Failure predates your commit → flake/pre-existing, note it and move on. Failure is new → real regression, fix it.

## Step 3: Real regression path

- Reproduce understanding from the diff, not by running tests locally (**never run the full suite locally** — RAM).
- Fix, commit (`fix(test): ...` or `fix: ...`), push, then `mcp__gh-actions__wait_for_commit_checks`.

## Step 4: Record

If you discover a NEW flake signature, add it to the table above (edit this skill) so the next triage is faster.

## Constraints

- CI must stay fully automatic: builds gate on `analyze` only, never `needs: test`; rely on cancel-in-progress. Don't manually cancel runs or tag.
- Aim for green CI on `main` — releases are cut automatically from every commit.
