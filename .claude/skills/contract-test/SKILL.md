---
name: contract-test
description: Scaffold or extend core-messaging contract tests that pin the localId identity invariants. Use before touching core messaging code, or when the user says "add contract tests", "pin the send path", or references localId/optimistic/retry/out-of-order coverage.
---

# Core Messaging Contract Tests

The app lives or dies on one invariant:

`one user tap -> one stable localId -> one optimistic row -> one persisted message -> one retry identity -> one final merged message`

CLAUDE.md rule: **when touching core messaging code, add or update contract tests first.**

## Mandatory coverage dimensions

1. **Canonical identity** — a single `localId` survives optimistic UI, REST send, socket forwarding, outbox retry, server ack, and merge.
2. **Repeated identical sends** — two sends of `continue` produce two distinct `localId`s and two logical messages. Text is never identity.
3. **Optimistic replacement** — server ack replaces the exact placeholder **by `localId`**, never by text similarity or list position.
4. **Retry identity** — explicit retry preserves the original `localId`; a fresh user resend creates a new one.
5. **Out-of-order delivery** — socket echo before REST, REST before socket echo, echo before tail/history fetch, duplicate re-broadcast.

## Where existing suites live (extend, don't duplicate)

- `test/fsm/message_state_machine_contract_test.dart` — FSM spec: `draft -> sending -> sent/pending/failed -> merged`; illegal transitions pinned as no-ops or `ArgumentError`s.
- `test/integration/message_deduplication_e2e_test.dart` — REST-before-fetch overlap.
- `test/integration/socket_echo_before_rest_e2e_test.dart` — socket-first ordering.
- `test/integration/socket_echo_before_fetch_e2e_test.dart` — echo before tail/history fetch, broadcast-then-fetch overlap.
- Helpers: `test/integration/mock_sync_server.dart`, `test/integration/fake_session_encryption.dart`, replay fixtures in `test/integration/jsonl_replay/`.

## Test plumbing

- `Sync()` is a singleton — use `createTestSync()` from `test/helpers/test_helpers.dart` (pre-wires all 13 `InvalidateSync` fields) before `handleUpdate`.
- Escape hatches: `testSocketConnectedOverride`, `testSocketSendOverride`, `testNotifyDataChanged()`, `testSetSessionMessages()`.
- Mock HTTP: always include `requestOptions: RequestOptions(path: '')`; prefer `mockResponse<T>()`.
- Assert the invariants explicitly: **no duplicate logical message, no orphan optimistic row, no lost retry identity**.

## Workflow

1. Identify which of the 5 dimensions the code change touches.
2. Write/extend the contract test FIRST, pinning current-correct behavior.
3. Make the change; run only via CI (never the full suite locally).
4. Update the ROADMAP "Immediate Test Priorities" table if a Not Started/In Progress row is now covered.
