---
name: ui-audit-batch
description: Run one batch of the incremental UI audit loop — find a themed-hardcoded-color / god-widget / deprecated-API target, fix it, sweep tests, commit. Use when the user says "ui batch", "dark mode audit", "continue the UI loop", or asks for incremental UI cleanup.
---

# UI Audit Batch

Incremental UI-quality loop (23+ batches shipped, 2026-06). Each batch: one scoped target, fixed, tested, committed. Never a big-bang refactor.

## Batch process

1. **Scout** a single target (pick ONE per batch):
   - Hardcoded colors that break dark mode: `rg -n "Colors\.black|Colors\.white|Color\(0x" lib/ --type dart` — migrate to M3 `ColorScheme` tokens or a `ThemeExtension`.
   - Deprecated APIs: `rg -n "withAlpha\(|withOpacity\(" lib/` → `withValues()`.
   - God-widget extraction: `chat_screen.dart` and friends — extract one cohesive widget (~100–200 lines) into its own file, using a typed record for many inputs (see `ChatStatusChipsInputs` pattern).
   - Near-identical builders: consolidate via data-driven specs (sealed spec classes, see settings batch 7).
2. **Fix** with the established patterns:
   - Palette consolidation → `ThemeExtension` (`SyntaxTheme`, `CodeViewerTheme`, `DiffTheme` precedents).
   - Keep public APIs stable via bridge factories (`asLegacy()` extension pattern) when 10+ callers exist; migrate callers in later batches.
   - Design tokens from `lib/core/theme/app_tokens.dart` (`AppSpacing`, `AppRadius`, `AppOpacity`, `AppShadow`, `AppIconSize`); scrims → `cs.scrim`, shadows → `cs.shadow`.
3. **Test sweep** — add/update widget tests for the extracted/changed surface. Standard sweep dirs: `test/features/chat/`, `test/features/sessions/`, `test/features/settings/`, `test/core/`. Regression tests should assert semantics (e.g. "R > G" for removed-diff red) not exact hexes. Run via CI only.
4. **Ship** — conventional commit (`refactor(ui): ...` / `fix(ui): ...`), push, and check CI.

## Retirement lesson (batch 12)

When retiring a bridge/class, grep for the **class name AND `.member` patterns** — a scout that only greps the class name undercounts stragglers.

## Part-file rules (batch 8)

Widgets living in `part` files can't be imported by tests directly — either promote to a standalone file or test via a wrapper that instantiates the parent library.

## Batch sizing

One logical target per batch, ~1 commit. If the scout finds a bug (not just style), fix the bug first in its own commit.
