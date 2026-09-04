# The happy_flutter Bible

> A reading order for the codebase. Not a spec, not a tutorial — a **map**.

## Who this is for

You're a new contributor (human or agent) about to touch `lib/`. You know Flutter and Riverpod in the abstract. You don't know *this* app. You want a path from "I have no idea" to "I can confidently edit any file in `lib/core/services/`."

This book is opinionated. It tells you which files matter and which are noise. It tells you the load-bearing invariants. It tells you which patterns to copy and which to leave alone.

## Reading order

### Part I — Orientation

1. **[The Big Picture](01-big-picture.md)** — one-paragraph mental model, the data flow, the three globals.
2. **[Directory Tour](02-directory-tour.md)** — what's in every `lib/` subdirectory, one paragraph each.
3. **[Core Invariants](03-core-invariants.md)** — the `localId` contract, the FSM, optimistic replacement, retry identity. **Read this before touching chat.**

### Part II — The Heart (Sync)

4. **[Sync: Anatomy](04-sync-anatomy.md)** — why one class, how 21 part files compose, the four concerns.
5. **[Sync Lifecycle](05-sync-lifecycle.md)** — `create` vs `restore`, `suspend`/`resume`, rapid-cycling guard.
6. **[InvalidateSync](06-invalidate-sync.md)** — the debounced-fetch primitive.
7. **[The Socket.IO Layer](07-socket.md)** — connection, reconnect, the fast path.
8. **[The Messaging Pipeline](08-messaging-pipeline.md)** — **the densest chapter.** Send → optimistic → REST → socket → merge. Trace one message end-to-end.
9. **[Outbox & Message Cache](09-outbox-and-cache.md)** — MMKV-backed offline retries + last-200 cache.

### Part III — State & UI

10. **[Riverpod v3 (manual)](10-riverpod.md)** — `Notifier<T>` patterns, the providers barrel, immutable updates.
11. **[Screen Subscription](11-screen-subscription.md)** — the standard template, `SyncSubscriptionMixin`, why `ChatScreen` is the exception.
12. **[Routing, Theme, Widgets](12-routing-theme-widgets.md)** — GoRouter, design tokens, the three widget layers.

### Part IV — Wire, Storage, Tests

13. **[Wire & Storage](13-wire-and-storage.md)** — Dio+NativeAdapter, `WireParsers`, AES+NaCl, MMKV, secrets.
14. **[Tests & Dev Loop](14-tests-and-dev.md)** — helpers, `mock_sync_server`, `mise`, CI.

## Conventions

- **File references** use `path:line` — clickable in modern editors and on GitHub.
- **"Files to read next"** at the end of each chapter is the literal next thing to open, in order.
- **"Gotchas"** blocks call out landmines. Skim them first when debugging.
- **"What this is NOT"** blocks tell you when a name is misleading. The codebase has some.

## Companion docs (kept in `docs/`)

These are reference notes, not part of the book. The book links to them where relevant.

- `ARCHITECTURE.md` — architecture review, god-object analysis
- `SYNC_PATTERNS.md` — quick-reference for Sync subscription patterns
- `PROTOCOL.md` — the wire protocol shape
- `SECURITY_AUDIT.md` — security review
- `AES_GCM_IMPLEMENTATION.md` — AES-256-GCM design
- `LIBSODIUM_INTEGRATION.md` — NaCl/libsodium integration
- `MMKV_MIGRATION_IMPLEMENTATION.md` — SharedPreferences → MMKV migration
- `DEV_OPS_CI_CD.md` — CI pipeline reference
- `UI_UX_REVIEW.md` — UI/UX review notes
- `PERFORMANCE_REPORT.md` — performance measurements

`CLAUDE.md` and `ROADMAP.md` are the authoritative agent guide and priority list — read those in addition to this book.

## Source of truth

When this book and the code disagree, the code wins. When this book and `CLAUDE.md` disagree, **`CLAUDE.md` wins** — it's the authoritative agent guide.
