# 3. Core Invariants

The codebase has one reason to exist: **one user tap produces exactly one stable message**. Everything in the messaging layer exists to defend that promise. If you touch chat, **read this chapter.**

## The invariant (formal)

> For any user action that creates a message, there is exactly one `LocalId` from optimistic insert through persistence, retry, socket echo, server merge, and out-of-order delivery. Repeated identical text produces distinct `LocalId`s. Optimistic replacement matches by `LocalId`, never by text or position.

This is **P0** in `ROADMAP.md`. It is the reason for the FSM, the message-state machine tests, and most of the production-bug fixes of the last few months.

## The four sub-invariants

### 1. One canonical `localId`

Every message — optimistic or server-acked — has a `LocalId`. The same `localId` is used by:

- the optimistic insert in the UI
- the REST POST body
- the retry (if any) — retry preserves the original `localId`
- the socket echo merge target
- the outbox entry

The `LocalId` is generated **once**, on the optimistic insert, and never changes. It is *not* derived from the message text, the timestamp, the session id, or the position in the list.

**Why it matters:** Repeated text (`"continue"`, `"y"`, `"ok"`) is not identity. If you tried to dedupe by text, two consecutive `"continue"`s would collapse.

```dart
// Correct: generate once, pass it everywhere.
final localId = LocalId.generate();
sync.sendMessage(localId: localId, text: 'continue', ...);

// Wrong: never derive a localId from text or timestamp.
final localId = LocalId('continue-${DateTime.now().millisecondsSinceEpoch}');
```

### 2. Optimistic replacement is by `localId`

When the server echoes the message back over the socket (or a fetch brings it in), the optimistic row is replaced **by `localId` match**, not by:

- text similarity
- list position
- timestamp proximity
- hash of the body

This is what `_sync_messaging_merge.dart` does. The merge function takes `(localMessage: Message, serverMessage: Message)` and replaces the local one **iff** `localMessage.localId == serverMessage.localId`. If the server message has no `localId` (e.g. an inbound assistant message), it's appended as a new row, not merged.

### 3. Retry preserves the original `localId`

A retry of a failed send uses the **same** `localId` as the original. The retry does not create a new `localId`. The user, seeing a "failed" badge, taps "retry"; the local row's `localId` is reused; the server sees the same identity and treats it as the same logical message.

A **fresh** user resend — the user types the message again and taps send — is a *new* user action, gets a *new* `localId`, and produces a *second* logical message. Even if the text is byte-identical to the first send.

```dart
// In sync.sendMessage: the localId is required and is NOT regenerated on retry.
Future<SendResult> sendMessage({
  required LocalId localId,    // <-- caller passes the same one back on retry
  required String text,
  ...
});
```

### 4. Out-of-order delivery is fine

REST success can arrive after a later socket echo. A later fetch can return a page that contains the same message already in memory. The merge layer must handle all of:

- REST success → socket echo (normal)
- Socket echo → REST success (covered by `socket_echo_before_rest_e2e_test.dart`)
- Socket echo → fetch overlap (covered by `socket_echo_before_fetch_e2e_test.dart`)
- Server re-broadcast of a message the client already has

The invariant under all of these: **the set of localIds is a set, not a list. A given localId is present at most once.**

## The FSM (Finite State Machine)

The states and transitions live in `lib/core/fsm/message_state_machine.dart`, with the typed hierarchy in `lib/core/types/message_state.dart`.

States (paraphrased):

```
Draft
  → Sending
Sending
  → Sent       (REST 200)
  → Pending    (REST succeeded but no server ack yet)
  → Failed     (REST error or socket error)
Pending
  → Sent       (server ack arrives over socket)
  → Failed     (server nack)
Failed
  → Sending    (user retries)
Sent
  → Merged     (server echoes via socket; optimistic replaced by canonical)
```

Illegal transitions (e.g. `Sent → Sending`, double-optimistic, retry-on-merged, fail-on-merged) are pinned as **strict no-ops or `ArgumentError`s** in `test/fsm/message_state_machine_contract_test.dart`.

> **What this is NOT:** The FSM is not a live field on the message. It's a *projection* of the event log (`lib/core/event_log/`). The "current state" of a message is `MessageStateMachine.apply(events)` over its event history.

## The test pyramid for the invariant

Three layers:

1. **Unit** — `test/fsm/message_state_machine_contract_test.dart`, `test/fsm/message_state_machine_test.dart`. Pins legal transitions, illegal no-ops, and the two-`continue`-sends-with-distinct-localIds scenario.
2. **Unit (messaging)** — `test/services/sync_*_test.dart`. Pin the merge logic, retry, outbox, dedup.
3. **Integration (e2e)** — `test/integration/`:
   - `concurrent_send_message_e2e_test.dart` — concurrent identical sends
   - `message_deduplication_e2e_test.dart` — REST-before-socket and fetch-overlap dedup
   - `socket_echo_before_rest_e2e_test.dart` — socket first
   - `socket_echo_before_fetch_e2e_test.dart` — socket first + fetch overlap + re-broadcast
   - `lifecycle_midsend_localid_e2e_test.dart` — localId survives a suspend/resume mid-send
   - `message_outbox_e2e_test.dart` — outbox retry with preserved localId
   - `socket_inline_message_e2e_test.dart` — fast-path inline message

When changing anything in `_sync_messaging*`, the rule from `CLAUDE.md` is:

> When touching core messaging code, add or update contract tests first — repeated identical sends, optimistic replacement, retry identity, and out-of-order delivery are mandatory coverage.

## Common ways to break the invariant (don't do this)

| Mistake | Why it breaks | Where to look |
|---|---|---|
| Using `text` or `timestamp` as a dedup key | `"continue"` collides | `_sync_messaging_merge.dart` |
| Regenerating `localId` on retry | Server sees a new message | `message_outbox.dart` |
| Replacing optimistic by position | List re-ordering breaks it | `_sync_messaging_merge.dart` |
| Adding a new code path that skips the FSM | Subtle state corruption | new code in `_sync_messaging*` |
| Mutating a `Message` field instead of `copyWith` | Lost updates; race conditions | models in `lib/core/models/` |
| Skipping the e2e test for a "trivial" change | The contract drifts | `test/integration/` |

## The four sub-invariants in one diagram

```
                  tap
                   │
                   ▼
        ┌──────────────────────┐
        │ generate LocalId L   │   ← ONCE
        └──────────────────────┘
                   │
        ┌──────────┴──────────┐
        │ optimistic insert   │   ← uses L
        │ in UI               │
        └──────────┬──────────┘
                   │
        ┌──────────┴──────────┐
        │ REST POST           │   ← body carries L
        │ + MessageOutbox     │   ← outbox entry keyed by L
        │ + MessageCache      │   ← cached by L
        └──────────┬──────────┘
                   │
        ┌──────────┴──────────┐
        │ Socket "api-update" │   ← serverMessage.localId == L
        │ (or fetch)          │
        └──────────┬──────────┘
                   │
        ┌──────────┴──────────┐
        │ merge by L          │   ← replace optimistic with canonical
        │ (in _sync_messaging │
        │  _merge.dart)       │
        └──────────┬──────────┘
                   │
        ┌──────────┴──────────┐
        │ onDataChanged       │   ← debounced 100ms
        │ → notifier rebuild  │
        └──────────────────────┘
```

If any arrow in that diagram *doesn't* use `L` for identity, the invariant is broken.

## Files to read next

- `lib/core/types/identity_types.dart` — the `LocalId` type itself
- `lib/core/types/message_state.dart` — the sealed state hierarchy
- `lib/core/fsm/message_state_machine.dart` — the transition function
- `lib/core/services/_sync_messaging.dart` — the top of the messaging part files
- `lib/core/services/_sync_messaging_merge.dart` — **the merge function. Most important file in the messaging layer.**
- `test/fsm/message_state_machine_contract_test.dart` — the contract
- `test/integration/message_deduplication_e2e_test.dart` — e2e dedup proof

## Gotchas

- The FSM is a *projection*. If you store the "current state" as a field on the message and also recompute it from the event log, they will drift. Pick one — the codebase picks the projection.
- "Optimistic replacement" is what the UI sees. The merge function in `_sync_messaging_merge.dart` may keep both rows briefly during a transition; what matters is the final state.
- The `LocalId` is a *newtype* wrapper, not a plain `String`. There's a `LocalId.generate()` factory. Don't construct it from a string literal.
- A message can be `Sent` (REST success) and not yet `Merged` (server hasn't echoed). These are different states. Don't conflate them.
