---
name: update-goldens
description: Regenerate golden screenshots via CI after a UI change and commit the updated PNGs. Use when the user says "update goldens", "goldens are stale", "golden test failing", or after any change that affects visual output.
---

# Update Golden Screenshots

Goldens in `test/golden/goldens/` are showcase images (README + visual regression). They MUST be regenerated after any UI change. **Never run the golden update locally** — the test suite can crash the device; CI only.

## Preferred path: workflow dispatch

1. Dispatch the `Happy Flutter CI/CD` workflow on `main` with the `update_goldens` input:
   ```bash
   gh workflow run ci.yml --ref main -f update_goldens=true
   ```
2. Wait for the run (`mcp__gh-actions__wait_for_run`), then download the golden PNG artifact:
   ```bash
   gh run download <run-id> -n <goldens-artifact-name> -D test/golden/goldens/
   ```
3. Commit the PNGs. They are **Git LFS** tracked (`.gitattributes`) — verify `git lfs status` shows them as LFS pointers before pushing.

## Fallback: commit-message trigger

If dispatch is unavailable, include `[update-goldens]` in the triggering commit message (see `b5d5f145` for precedent). The CI run produces the artifact; download and commit as above.

## Scope gap (important)

The `[update-goldens]` CI path only covers `test/golden/`. **Widget-local goldens** elsewhere in the tree do NOT regenerate via CI — single-file local runs are safe for those:

```bash
mise exec -- flutter test test/path/to/one_widget_golden_test.dart --update-goldens
```

(Single-file runs don't hit the RAM problem; only the full suite does.)

## Checklist

- [ ] UI change committed and pushed first (goldens regenerate from main)
- [ ] CI artifact downloaded, PNGs replaced
- [ ] `git lfs status` confirms LFS tracking
- [ ] Committed with `test: refresh golden screenshots` and pushed
- [ ] Golden CI job green on the follow-up commit — no stale goldens left behind
