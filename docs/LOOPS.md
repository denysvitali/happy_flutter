# Loops — First-Class Scheduled Prompts

**Status:** Draft (2026-06-17)
**Scope:** happy_cli_go daemon + happy_flutter mobile client

## Overview

Loops are scheduled recurring prompts that fire inside an active Claude session.
They mirror Claude Code's `/loop` slash command and the `CronCreate` / `CronList`
/ `CronDelete` tool family. In Happy Flutter we elevate them to **first-class
citizens** — visible in the chat header, browsable in a dedicated screen, and
queryable per-session in the sessions list.

Reference: https://code.claude.com/docs/en/scheduled-tasks

## User-Facing Surface

| Surface | Behavior |
|---|---|
| Chat input | `/loop 5m check the deploy` → opens Create Loop sheet with the prompt pre-filled |
| Chat input | `/loop 1d summarize today's commits` → one-shot reminder at 9am tomorrow |
| Chat input | `/loop cancel <id>` → cancel a specific loop |
| Chat header | Loop count badge (e.g. "⏱ 3 loops") tapping opens Loops screen |
| Loops screen | Per-session list: schedule, prompt, last fired, fire count, pause/delete |
| Sessions list | Compact badge on session cards showing loop count |
| `/loop` autocomplete | First-class entry in chat autocomplete overlay |

## Constraints (from Claude Code)

- **Max 50 active loops per session.**
- **Recurring loops auto-expire 7 days after creation** (Claude Code's current
  spec; subject to change as Anthropic evolves the feature).
- **One-shot reminders fire once and self-delete.**
- **Jitter**: Recurring tasks fire up to 10% of their period late (max 15 min),
  one-shots fire up to 90s early when pinned to :00 or :30.
- **Fire only when session is idle** (Claude is not mid-turn). If a task's
  scheduled time passes while busy, it fires once when idle (no catch-up).
- **Session-scoped**: Loops live only while the daemon session process is alive.
- **`CLAUDE_CODE_DISABLE_CRON=1` disables scheduling entirely.**

## Data Model

```dart
// happy_flutter/lib/core/models/loop.dart
class Loop {
  final String id;             // 8-char ID, matches Claude Code convention
  final String sessionId;
  final String expression;     // 5-field cron expression (local tz)
  final String prompt;         // prompt text to fire
  final bool recurring;        // false = one-shot
  final int createdAt;         // ms epoch
  final int expiresAt;         // ms epoch (createdAt + 7d for recurring)
  final int? lastFiredAt;      // ms epoch
  final int fireCount;         // incremented each fire
  final bool paused;           // optional manual pause
}
```

```go
// happy-cli-go/internal/cli/loop_types.go
type Loop struct {
    ID          string `json:"id"`
    SessionID   string `json:"sessionId"`
    Expression  string `json:"expression"`
    Prompt      string `json:"prompt"`
    Recurring   bool   `json:"recurring"`
    CreatedAt   int64  `json:"createdAt"`
    ExpiresAt   int64  `json:"expiresAt"`
    LastFiredAt int64  `json:"lastFiredAt,omitempty"`
    FireCount   int    `json:"fireCount"`
    Paused      bool   `json:"paused"`
}
```

Both must serialize byte-identically. ID format: `[0-9a-f]{8}` (8 lowercase hex
chars), generated from crypto/rand.

## Wire Protocol

### Socket events (server → client)

All ride the existing `update` envelope (no new event names — just new `t`
discriminators):

| `t` value | Payload | Meaning |
|---|---|---|
| `loops-updated` | `{t, sid, loops: Loop[]}` | Full replacement list for a session |
| `loop-fired` | `{t, sid, loopId, firedAt, fireCount}` | One loop fired (telemetry + UI badge) |
| `loop-expired` | `{t, sid, loopId}` | Loop self-deleted after expiry/one-shot |

`loops-updated` is always the source of truth — clients replace their local
list whenever they see one. `loop-fired` is a notification that fires whether
or not the local list has updated (useful for "just fired" badges).

### RPC methods (client → daemon)

Reuse the existing `rpc-call` socket event. Methods registered with the
RPCManager like `KillSession` / `AbortSession`:

| Method | Params | Returns | Purpose |
|---|---|---|---|
| `loop-create` | `{expression: string, prompt: string, recurring: bool}` | `{ok, loop?, error?}` | Create a new loop |
| `loop-delete` | `{loopId: string}` | `{ok, error?}` | Cancel and delete |
| `loop-list` | `{}` | `{loops: Loop[]}` | List loops for current session |
| `loop-pause` | `{loopId: string, paused: bool}` | `{ok, error?}` | Pause/resume |

The daemon is the authoritative owner of loop state. The server only forwards
RPC calls; it does not store loop state.

### Slash command interception (UI only)

The Flutter app intercepts `/loop` text before it reaches the agent:

- `/loop <interval> <prompt...>` → opens Create Loop sheet pre-filled
- `/loop cancel <id>` → calls `loop-delete` RPC and toasts the result
- `/loop list` → opens Loops screen

If the agent sees `/loop` text (e.g. typed from a non-Happy client), it works
naturally via Claude Code's native scheduler. The two paths do not conflict
because the daemon-side scheduler is authoritative — the Flutter side is a
client convenience.

## Architecture

### Daemon (happy-cli-go)

```
internal/
  cli/
    loop_scheduler.go      # LoopScheduler — per-session timer loop
    loop_types.go          # Loop struct + ID gen + validation
    loop_persistence.go    # Read/write loops-<sid>.json via Store
  rpc/
    loop_handlers.go       # RPC handler registrations
  persistence/
    store.go               # +ReadLoops(sid), +WriteLoops(sid, []Loop)
```

**`LoopScheduler`** owns one goroutine per loop, using `time.NewTimer` with
deterministic jitter (hash of loop ID). On fire:

1. Check `thinkingState == false && pending.len() == 0 && readyEmitted == true`
   (idle). If not idle, skip this fire — one catch-up fires when idle.
2. Build the same JSON-line user message that `_chat_screen_actions.dart:1030`
   in the daemon would build for a normal user message.
3. Inject through the existing `currentStdin.Write(dataWithNewline)` path
   under `stdinMu` (with the same close-flag handling for restart safety).
4. Update `lastFiredAt` + increment `fireCount`.
5. Emit `loop-fired` session event via `SendSessionEvent`.
6. For one-shot loops, schedule self-deletion after firing.

The scheduler is owned by `runRemoteSession` lifecycle (killed on `ctx.Done()`).

### Flutter (happy_flutter)

```
lib/
  core/
    models/
      loop.dart            # Loop model + JSON
    services/
      loop_storage.dart    # MMKV persistence (CachedStorage)
    providers/
      app_providers.dart   # +loopsNotifierProvider barrel
    api/
      loops_api.dart       # +RPC client wrappers
  core/services/
    _sync_loops.dart       # New part file in sync_service.dart
  features/
    loops/
      loops_screen.dart    # Per-session Loops screen
      loops_provider.dart  # LoopsNotifier
      loop_card.dart       # Single loop card widget
      loop_count_badge.dart # Compact badge for chat header
      create_loop_sheet.dart # Bottom sheet
  core/utils/
    sync_domain.dart       # +SyncDomain.loops enum value
  core/routing/
    app_router.dart        # +/chat/:sessionId/loops route
```

`LoopsNotifier` follows the same pattern as `SessionsNotifier`:

```dart
class LoopsNotifier extends Notifier<Map<String, List<Loop>>> {
  @override
  Map<String, List<Loop>> build() => {};

  void loadFromSync() {
    state = sync.loopsBySession;  // instant in-memory
  }

  Future<void> refreshFromSync() async {
    await sync.refreshLoops();     // server fetch
    loadFromSync();
  }

  Future<Loop> createLoop({...}) => sync.createLoop(...);
  Future<void> deleteLoop(String id) => sync.deleteLoop(id);
}
```

Subscription follows `docs/SYNC_PATTERNS.md`:

```dart
@override
void initState() {
  super.initState();
  Future<void>.microtask(() async {
    await ref.read(loopsNotifierProvider.notifier).refreshFromSync();
  });
  _syncSubscription = sync.onLoopsChanged.listen((sessionId) {
    if (!mounted) return;
    ref.read(loopsNotifierProvider.notifier).loadFromSync();
  });
}
```

### Server (happy-server)

No changes required. The server already forwards `update` events and `rpc-call`
events. The daemon emits `loops-updated` inside the existing `SendSessionEvent`
envelope (same `data.type` discriminator pattern as `ready`, `thinking_done`,
`compact-requested`).

## Testing Strategy

### Daemon (happy-cli-go)

1. **Pure unit tests** for cron expression parsing + next-fire computation
   (model after `shouldKillForStuckThinking` in `claude_remote.go:143`).
2. **LoopScheduler unit tests** — fake clock, verify jitter bounds, verify
   idle-skip behavior, verify one-shot self-delete.
3. **Loop persistence round-trip** — model after `internal/persistence/store_test.go`.
4. **RPC handler tests** — `loop-create` enforces 50-cap, validates cron
   expression, rejects when `CLAUDE_CODE_DISABLE_CRON=1`.
5. **E2E tests** in `e2e_message_relay_reconnect_test.go`:
   - `TestE2E_LoopCreateFiresOnSchedule`
   - `TestE2E_LoopDeleteStopsFiring`
   - `TestE2E_LoopHonorsIdle`
   - `TestE2E_LoopExceeds50CapRejected`

### Flutter (happy_flutter)

1. **Loop model JSON round-trip** — `test/core/models/loop_test.dart`.
2. **LoopsNotifier unit tests** — `test/core/providers/loops_notifier_test.dart`.
3. **LoopStorage round-trip** — `test/core/services/loop_storage_test.dart`.
4. **Sync event routing** — extend `test/integration/handle_update_routing_e2e_test.dart`
   with `loops-updated` / `loop-fired` cases.
5. **Slash command parser** — `test/features/chat/loop_command_parser_test.dart`.
6. **LoopsScreen widget test** — `test/features/loops/loops_screen_test.dart`.
7. **Chat header badge widget test** — `test/features/loops/loop_count_badge_test.dart`.

## Migration / Rollout

Loops are a purely additive feature. No migration is required. Existing
sessions will simply have empty loop lists.

## Future Work

- Push notifications when a loop fires (off-app awareness)
- Cross-session loop dashboard at `/settings/loops`
- `/loop-from-message` to schedule any message in history as a loop
- Server-side mirror so multiple machines share loop state
