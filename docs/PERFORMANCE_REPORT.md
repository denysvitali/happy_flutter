# Performance Report

**Date:** 2026-03-13
**Agent:** A4 — Performance Optimizer

## July 2026 implementation update

- Chat and session collections use lazy builders and bounded visible windows.
- Message updates now invalidate the header/activity chrome, message pane, and
  composer independently instead of rebuilding the full chat scaffold.
- Background workflow refresh is limited to the visible session plus the three
  most-recent online sessions, with in-flight deduplication, capability caching,
  and transient-error backoff.
- OpenTelemetry histograms now cover first frame, essential startup readiness,
  deferred initialization, message fetch, optimistic-row latency, slow chat-list
  builds, aggregate build/raster/total frame duration, and end-to-end
  machine-usage operations with named enrichment stages.
- Frame reporting distinguishes slow frames (over the 60 Hz budget) from frozen
  frames (100ms+); only frozen frames create Sentry transactions.
- Active trace context is Zone-local, so concurrent sends, socket events, and
  HTTP requests cannot parent each other's spans. Agent-readiness waits have a
  dedicated child span instead of appearing as unexplained send latency.
- Aggregate frame metrics run whenever app telemetry is enabled; Sentry jank
  transactions remain independently gated by Sentry sampling settings.

The findings below are the March 2026 baseline. Several have since been
completed and should not be treated as the current backlog.

---

## Summary

The codebase has strong fundamentals (const tokens, RepaintBoundary, Riverpod selectors, proper disposal). Key optimization areas: monolithic screen widgets, ListView without .builder, and repeated Theme.of() calls.

---

## High Impact Issues

### 1. Monolithic StatefulWidget Screens (HIGH)

| File | Lines | setState() Calls | Local State Fields |
|------|-------|-----------------|-------------------|
| `chat_screen.dart` | 1,082 | ~20+ | 11+ |
| `sessions_screen.dart` | 1,434 | ~15+ | 8+ |
| `message_widget.dart` | 1,194 | ~10+ | 5+ |

**Problem:** Each `setState()` triggers a full rebuild of the widget subtree. In `chat_screen.dart`, this means re-evaluating message lists, profile deduplication, and neighbor caches.

**Fix:** Extract into smaller widgets and move computed state to Riverpod providers:
```dart
// Move from chat_screen build method to computed provider
final availableProfilesProvider = Provider((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final seen = <String>{};
  return [...settings.profiles, ...builtInProfiles]
      .where((p) => seen.add(p.id)).toList();
});
```

**Impact:** Eliminates unnecessary rebuilds of 50+ message widgets per screen.

### 2. ListView Without .builder (41 instances) (MEDIUM-HIGH)

41 screens use `ListView(children: [...])` instead of `ListView.builder()`. All children are mounted immediately regardless of visibility.

**Worst cases:**
- `changelog_screen.dart` — renders entire changelog at once
- Settings screens with 20–30 options
- Session info screens with variable-length content

**Fix:** Convert to `ListView.builder()` or `ListView.separated()`:
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => SettingsTile(item: items[index]),
)
```

### 3. Repeated Theme.of(context) (MEDIUM)

`message_widget.dart` calls `Theme.of(context)` ~9 times per message across sub-widgets. With 50+ messages visible, this causes 450+ tree walks per frame.

**Fix:** Cache once per build method:
```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  // Reuse theme, cs throughout
}
```

### 4. Expensive Build-Method Computations (MEDIUM)

`chat_screen.dart` lines 169–172: Profile deduplication runs in every build:
```dart
final seen = <String>{};
final deduped = <AIBackendProfile>[];
for (final p in [...settings.profiles, ...builtInProfiles]) {
  if (seen.add(p.id)) deduped.add(p);
}
```

**Fix:** Move to a computed Riverpod provider or cache in notifier.

### 5. Search setState() Triggers Full Rebuild (MEDIUM)

`sessions_screen.dart`: Search query changes call `setState()` which rebuilds the entire tab shell (inbox + settings + sessions).

**Fix:** Extract search to a `StateProvider<String>` and use a computed filtered provider.

---

## Low Impact Issues

### 6. CachedNetworkImage Missing Disk Cache Config
**File:** `avatar.dart` — no `maxWidthDiskCache`, `maxHeightDiskCache`, or timeout settings.

### 7. Avatar Image List Initialization
**File:** `avatar.dart` — 420 string concatenations at runtime for `_allImages`. Consider `const` propagation.

### 8. AnimatedBuilder Child Recreation
**File:** `app_empty_state.dart` — Container in `child:` parameter recreated on parent rebuild (minor; empty state is infrequent).

---

## Well-Optimized Patterns (Preserve)

| Pattern | Location | Quality |
|---------|----------|---------|
| Provider triple-check (ref + content equality) | `sessions_notifier.dart` | Excellent |
| MarkdownView stylesheet caching | `markdown_view.dart` | Excellent |
| RepaintBoundary on message animations | `message_widget.dart` | Good |
| Skip animation on bulk-loaded messages | `message_widget.dart` | Smart |
| Riverpod `.select()` for badge counts | `sessions_screen.dart` | Good |
| Custom paint `shouldRepaint` | `avatar.dart` | Correct |
| Pre-computed neighbor cache | `chat_screen.dart` | Thoughtful |

---

## Effort Estimates

| Issue | Fix Time | Impact |
|-------|----------|--------|
| Decompose monolithic screens | 4–6 hours | High |
| Convert 41 ListViews to .builder | 3–4 hours | Medium-High |
| Cache Theme.of() in message pipeline | 1–2 hours | Medium |
| Extract build computations to providers | 1–2 hours | Medium |
| Search state extraction | 1–2 hours | Medium |
| CachedNetworkImage config | 30 min | Low |
