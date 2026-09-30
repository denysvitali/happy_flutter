## UI Conventions

Desktop chats group completed tool calls by default, with a per-chat control
to show the full trace. Mobile keeps its existing hide-tools preference. Tool
summaries name successful file work and commands while retaining failures,
queued calls, cancellations, and approvals. The activity bar shows the recorded
running tool family and elapsed request time; its clock pauses with TickerMode.
An idle turn offers a result review sheet with the latest answer, recorded
changed files/diffs, and command output. These are bounded, cached display
projections of resident messages; command completion never implies tests passed.
Active Codex turns have separate, visible Update current turn and Queue for
next turn actions. Mobile keeps model/permission controls in the composer and
moves profile/context settings into Composer options. Session triage labels
separate unread assistant results from unread activity while still working.
The session pane can be hidden without losing its selection or scroll state;
dragging its divider resizes it. Chat inspectors allocate space only when
opened and use the available chat-pane width. The conversation and composer
share an 880px maximum reading width on desktop. Opening and closing an
inspector keeps the conversation mounted, preserving composer focus, draft
text, scroll position, and expanded tool rows.
Desktop dividers stay compact; tablet dividers retain a 44px touch target.
Arrow-key resizing persists the selected pane width immediately.

**Design tokens** in `lib/core/theme/app_tokens.dart`: `AppSpacing` (xxs=2 to xxxl=32), `AppRadius` (xs=4 to pill=100), `AppFontSize` (xxs=10 to lg=16), `AppDuration` (fast=150ms to slower=500ms), `AppTouchTarget` (min=44, comfortable=48), `AppBreakpoint` (tablet=600, desktop=960), `AppScreenPadding` (standard, compact, settings, listItem).

**Widget layers:**
- `lib/core/components/` — higher-level (AppCard, AppEmptyState, sidebar, settings sections)
- `lib/core/ui/` — lower-level (avatars, tab_bar, shimmer, diff, status_bar)
- `lib/core/widgets/` — additional shared widgets

**IMPORTANT — `hide TabBar`:** When importing custom `TabBar` from `lib/core/ui/tab_bar/tab_bar.dart`:

```dart
import 'package:flutter/material.dart' hide TabBar;
```

**Web search results:** Claude and MCP search detail views share full-width
source cards. Keep the entire card tappable for HTTP(S) URLs, with a separate
domain line and visible browser-launch failure feedback.

**Failure fallback:** `ErrorWidget.builder` must return a leaf render-object
widget. Even `Text` performs implicit inherited-widget lookups and can recurse
through defunct ancestors. Root error takeover waits until a failing build or
layout frame finishes.

**Progress and focus lifecycle:** Use `AppCircularProgressIndicator` and
`AppLinearProgressIndicator` so animation controllers belong to the widget and
avoid Flutter 3.41's per-tick Theme ancestor lookup after route removal. New
focus groups use `AppReadingOrderTraversalPolicy`, which waits for render
geometry before traversing candidates. Forward every lifecycle state to
`AppVisibilityCoordinator`: desktop `inactive`/`resumed` changes focus without
suspending or reconnecting Sync. The root `AppFocusTickerMode` mutes unfocused
animations while preserving route state; hidden/paused publishes the same
focus loss and emits only one suspend edge.

**Frozen-frame attribution:** frozen frames record `app.ui.frozen_frame_vsync`
(UI-isolate wait before build) with `stall_phase` and `blocker` labels. Wrap
long synchronous UI-isolate work in `MainIsolateStallTracker.track()` so a
`vsync` stall names its cause instead of reporting `untracked`.

**File previews:** supplied empty content is valid. Scope async file and
clipboard results to the current file, and keep code and gutter in one
vertical viewport.

**Terminal output:** `prepareTerminalOutputPreview` counts lines and selects
the visible prefix without allocating a line list. ANSI stripping happens
only on Copy; outputs of at least 4096 characters use an async Rust worker,
with a Dart fallback. Keep its SGR-only strip rule and `split('\n')` line
semantics identical. Native AES encrypt/decrypt, JSON, sidechain, and terminal
spans report bridge wall and Rust stage time without message data.
Rust stage timers use `web_time::Instant`: `std::time::Instant` panics on the
WASM target. The web CI job smoke-tests the built release WASM sync bridge.

**Display text:** Session previews and profile avatar initials must use
`characters` (grapheme clusters), never UTF-16 indexing or fixed-offset
`substring` cuts. Sanitize malformed remote text before rendering; ingestion
sanitization cannot prevent a later display slice from splitting an emoji.

**Screen types:**
- `ConsumerStatefulWidget` + `ConsumerState` — screens with local state or sync subscriptions (majority)
- `ConsumerWidget` — stateless read-only screens

