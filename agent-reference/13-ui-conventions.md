## UI Conventions

Warning panels pair `warningContainer` with `onWarningContainer` for readable
text and actions in both themes. Reserve `onWarning` for solid `warning`
surfaces. Session issue banners wrap long diagnostics at larger text sizes.

Generic chat Agent/Task rows show the reported child nickname and role using
the same metadata resolution as agent details. Missing names retain the tool
label; missing roles retain the supplied subagent type. Step counts and run
status remain visible as metadata arrives.
Prime Agent child details show the child text, thinking, Python cells, and
results forwarded by happy-cli-go from Prime's native daemon. Incoming steps
refresh an already open child view and stay attached to that child's anchor.

Official Codex (no profile) and Claude (default/Anthropic) chats show live
account usage windows in one compact row below the header, fetched from the
session's machine. Labels, percentages, and mini meters stay inline; longer
reports scroll horizontally rather than adding rows, including at large text
sizes. The strip refreshes once a minute while visible and opens usage details
for that machine. Third-party profiles omit it; failed refreshes label retained
limits as stale.

Desktop chats group completed tool calls by default. Mobile uses its
hide-tools preference. There is no grouped/full tool switch or extra chat
header; search temporarily shows all tools. Tool summaries name successful
file work and commands while retaining failures,
queued calls, cancellations, and approvals. The activity bar shows the recorded
running tool family and elapsed request time; its clock pauses with TickerMode.
An idle turn offers a result review sheet with the latest answer, recorded
changed files/diffs, and command output. File details include previous/next
navigation and a return to the review list. These are bounded, cached display
projections of resident messages; command completion never implies tests passed.
Codex Exec's `final_message` renders as attributed Markdown outside the
collapsed prompt/configuration panel and stays visible when tools are grouped.
Tool Details retains execution metadata and the unchanged raw payload.
Prime Agent session badges and the new-session picker share `PrimeAgentLogo`:
the official Prime Intellect bird mark, bundled from
`https://www.primeintellect.ai/icons/logo-icon.png`. Generated and custom
avatars use this logo, never the Claude logo or a generic sparkle icon.
Prime Agent’s `Python cell` calls start collapsed with a description or first
source line and a one-line output preview, including when completed tools are
grouped. Each cell expands independently to syntax-highlighted source and
readable output with four-line previews. Full source, Copy, output expansion,
and raw wire details remain available. A cell’s manual expansion or collapse
is preserved when its result arrives.
Tool completion flashes cancel their timer when the row is disposed.
Auth button labels fit the available width with a single-line ellipsis.

Active Codex turns have separate, visible Update current turn and Queue for
next turn actions. Mobile keeps model/permission controls in the composer and
moves profile/context settings into Composer options. Session triage labels
separate unread assistant results from unread activity while still working.
Unread Focus orders approvals, errors, unread answers, then unread activity;
routine thinking without unread work remains in All Sessions.
Cached chats stay mounted during refresh; a failed refresh offers Retry above
the retained history. Failed sends have a 44px retry target. Stopped Har chats
and Prime Agent chats without a saved transcript offer
an explicit new-session action. Transcript-backed Prime chats resume on Send
or Retry only after the daemon confirms restore; failed sends retain their
original identity. Failed saved Prime restores also offer a new-session
action while keeping Send and Retry available for the original transcript.
Long plain agent notices retain a two-line preview and expand to selectable,
complete text so recovery instructions remain readable.
New-session worktree/backend controls live under Advanced options. Recent
workspaces select only a path on the chosen machine, not an agent or model.
Mobile approvals and Composer options stay outside the scrolling model lane.
Pending configuration changes show no notice under the composer chips.
Har model choices made during a turn stay pending above the composer until
the idle process confirms the switch. The chip keeps the confirmed model;
new choices replace the pending target. Sends and retries wait for confirmation.
Failed switches retain the choice with explicit Retry and Cancel actions;
they never retry automatically or silently send with the previous model.
Cancelling a failed RPC confirms the previous model again before unblocking,
because a lost reply may hide a successful switch.
Model RPCs share Sync's delivery lane: foreground POSTs and automatic retries
already in progress finish first. Queued retries must drain before switching;
a failed attempt retains the choice for explicit Retry. A revived message
whose saved Har model differs from the running model cannot be delivered.
Safe model switching requires the daemon's version 1 barrier capability bound
to the current Har runtime. Older sessions show an explicit Happy CLI upgrade
and new-session message before any switch RPC is attempted.
Assistant replies have no avatar gutter; transcript text sits 12px from the
pane edge and full-width tool details keep a 4px gutter. The composer gives
the draft its full width with expand on the first line; attach, approvals,
model and options lead the toolbar, dictate and send close it.
The session pane can be hidden without losing its selection or scroll state;
dragging its divider resizes it. Chat inspectors allocate space only when
opened and use the available chat-pane width. The conversation and composer
share an 880px maximum reading width on desktop. Opening and closing an
inspector keeps the conversation mounted, preserving composer focus, draft
text, scroll position, and expanded tool rows.
Search temporarily shows individual tool calls so matching commands and
files can be revealed, then restores the previous tool visibility preference.
On desktop, Ctrl/Cmd+F opens and focuses conversation search. Enter and
Shift+Enter navigate search results; Escape closes the focused search field.

Desktop dividers stay compact; tablet dividers retain a 44px touch target.
Arrow-key resizing persists the selected pane width immediately.

Inbox (persisted as `status`) filters appear for multiple occupied lanes or an
existing selected lane, with an explicit return from an empty filter. Inbox
rows use a flat surface with inset dividers; By machine retains grouped cards.
Quiet-only lists omit the redundant section heading and ignore an earlier
collapsed state. Quiet lists up to twelve show all rows; longer lists preview
ten and expand below them. Open and Archived tabs keep history reachable from
Inbox and By machine. Unarchived conversations stay open when their process
stops or becomes idle; presence still describes the process on each row.
An empty Open inbox links directly to Archived when history is available.
Bulk selection includes collapsed rows in the
selected lane and reconciles when filters change. Row menus expose preview,
selection and confirmed archive; selection mode suppresses secondary actions.
Confirmed bulk archive/delete keeps its captured selection and one shared
progress bar until completion. Selection controls and Back cannot dismiss or
change a pending batch; failures restore the controls and show feedback.
Search-scoped selection in every layout excludes hidden sessions and reconciles
after sync changes. Session search and folder headers grow with text scale;
Clear keeps search focused and Escape closes it. The shared bottom navigation
measures complete labels and uses two rows when enlarged labels need more space.
Its selection indicator follows reading direction, and keyboard focus is exposed
on the same semantic button used for touch and screen readers.
Inbox previews have up to two lines; named conversations retain nonredundant
workspace context. Missing previews fall back to the provider plus workspace
or real host. Other layouts retain compact rows. Raw IDs and placeholder hosts
stay out of the list. Time and a 44px menu sit at the right; larger text moves
the time to protect title width.
The Sessions title opens the layout picker in the single-row app bar.
Connection problems have an indicator; a healthy connection adds no extra row.

Unread Focus uses neutral session surfaces with a slim accent: primary for
unread work, error for approvals and failures. Dense cards use 4px vertical
padding, 6px avatar gaps and 2px gaps between text lines. Selection replaces
the avatar instead of adding a second gutter. The whole card supports touch
and keyboard review, without a separate review-button row. Both sections
share `SessionListDetails`: single-line titles and previews use the available
content width, with status, timestamps, unread counts and task progress in a
wrapping footer. Full text remains available in the chat; text size is not
reduced for density. Approval controls sit below the content and wrap independently;
selection and larger text must not squeeze them into a trailing column.

**Design tokens** in `lib/core/theme/app_tokens.dart`: `AppSpacing` (xxs=2 to xxxl=32), `AppRadius` (xs=4 to pill=100), `AppFontSize` (the whole type scale: sm=12, md=13, base=14, lg=16, xl=18 — nothing below 12; `xxs`/`xs` were removed), `AppDuration` (fast=150ms to slower=500ms), `AppTouchTarget` (min=44, comfortable=48), `AppBreakpoint` (tablet=600, desktop=960), `AppScreenPadding` (standard, compact, settings, listItem).

**Inline rows:** Reuse `AppInlineRow`, `AppInlineAction`, and `AppInlineText`
from `lib/core/components/app_inline_row.dart` for compact headers and status
rows. Thinking, tools, tasks, activity, and turn review share flat surfaces,
icon slots, spacing, 13px chrome text (`AppInlineText.body`), and 44px action
targets. Separate secondary actions from the row tap target. Composer selector
chips and the task / activity / review rows above the composer are the
*composer chrome*: 11px regular muted text (`AppInlineText.chrome`,
`AppFontSize.xs`), 24px pills and 28px rows (`dense: true`), so they are
clearly secondary to the 14px draft. State emphasis is color and icon only. Elapsed
labels switch to `Xh Ym` past one hour.

**One component per element** (`test/core/theme/design_system_guard_test.dart`
fails if a parallel copy comes back):

| Element | Use | Not |
|---------|-----|-----|
| Primary / secondary / tertiary button | themed `FilledButton` / `OutlinedButton` / `TextButton` | `ElevatedButton`, per-site `styleFrom` sizes |
| Destructive button | `AppButtonStyle.destructive` / `.destructiveFilled` | `styleFrom(foregroundColor: cs.error)` (the themed FilledButton paints a gradient over `backgroundColor`) |
| Dense button | `AppButtonStyle.compact` | ad-hoc `minimumSize: Size(44, 32)` |
| Status / count pill | `AppBadge` (full-radius, `AppBadge.defaultPadding`) | `Container` + `Text` with `AppRadius.pill` |
| Filter / choice chip | themed `ChoiceChip`/`FilterChip` with `VisualDensity.compact` (28px) | custom `InkWell` pills |
| Composer setting | `ComposerSelectorChip` (28px) | — |
| Icon in a tinted box | `AppIconTile` (`AppControlSize.md`/`lg`) | hand-built circles/squares |
| Card | `AppCard` (`color`/`borderColor` for tonal cards) | raw `Card` with per-site shape/elevation |
| Inline row / row action | `AppInlineRow` / `AppInlineAction` (`AppRowHeight.compact` = 36) | 44px rows in the transcript |

Control sizes are `AppControlSize` 28/32/40; row height is `AppRowHeight.compact`
36. Transcript rows and their actions are 36px — dozens stack, so they trade
the 44px minimum for density; standalone buttons keep `AppTouchTarget.min`.

**Text roles (`AppText`, `lib/core/theme/app_text.dart`):** Row and header text
is one of five roles — `screenTitle` (18/600, the app bar style), `title`
(14/600, `onSurface`), `secondary` (12/400), `label` (12/600) and `badge`
(12/700, tabular) — with one line height (1.3) and default color per role.
Never build row text from `textTheme.x?.copyWith(fontSize/fontWeight)`: the
same job then renders with a different weight, height or color on every page
(titles were 500, 600 and 700; `titleSmall` defaulted to the muted color).
Section headers are never force-uppercased and have no `uppercase` option.
`MissionType` is a thin alias for these roles.

**Type and icon scale:** The theme (`theme_helper.dart`) and every component
theme use only `AppFontSize` sizes; `test/core/theme/type_scale_test.dart` pins
that. Do not write literal `fontSize:` values — use `textTheme` slots or the
tokens. Small text is always 12 (`bodySmall`, `labelSmall`, `labelMedium`);
differentiate by weight and color, never by going to 11. Icons snap to
`AppIconSize` (12/14/16/18/20/22/24); 4–8px status dots are the only exception.

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

**Activity motion:** Thinking dots, status dots, streaming cursors, and
connection badges use `AppMotion.activityPulseCount` bounded passes, then
remain visible without scheduling frames. Respect both reduced-motion flags
and `TickerMode`; routine rebuilds must not restart settled indicators.
Loading shimmers use the same bounded budget, then retain a static skeleton.
Elapsed tool clocks unsubscribe while muted and catch up from wall time on
reactivation. Gate chat visual projections on focus and the actual enclosing
route, including stacked chats with the same route name; delivery stays active.

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

**Setup and recovery:** First-use setup keeps each step visible and reveals its
command on demand. New sessions group workspace and agent selection ahead of
advanced runtime options; those controls must reflow at large text sizes.
Connection guidance distinguishes eligible queued retries from failed messages.
Workflow run details label session-linked artifacts as session-wide, since the
artifact model does not establish which run produced them.
