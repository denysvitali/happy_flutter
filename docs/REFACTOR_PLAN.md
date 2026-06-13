# Happy Flutter — Full-Scale Refactor Plan

**Date:** 2026-06-13  
**Scope:** `lib/`, `test/`, CI/CD, tooling  
**Status:** Proposal — awaiting team review before implementation

---

## 1. Executive Summary

This codebase has solid bones: feature-based layout, strong localization, a mature Sync/message pipeline, and a large test suite. But several years of rapid shipping have produced a **Sync god object** (~12.6 kLOC), a **1,500-line `ChatScreen`**, **3,500+ force-unwraps**, and a **broken local build** due to a dependency/SDK version mismatch. The refactor plan below is designed to be executed in incremental, reviewable phases that keep the app shippable throughout.

### Hard numbers driving this plan

| Metric | Value | Target |
|--------|-------|--------|
| `lib/` source files | 471 | keep stable |
| `lib/` non-generated LOC | ~142 k | flat or lower |
| Sync subsystem LOC | 12,625 | < 3,000 in any single object |
| Files > 800 lines | 28 | 0 |
| `!` null-check operators | 3,548 | < 500 |
| `as` casts | 1,748 | < 500 |
| `sync.` calls inside `features/` | 137 | < 10 |
| `setState` calls | 354 | < 150 |
| Test files | 260 | keep growing |
| CI Flutter version | 3.44.0 | matches local (3.41.x or unified) |

### Top 5 problems to solve

1. **The build is broken locally.** `record: ^7.0.0` requires Dart 3.12; devenv pins Dart 3.11.5.
2. **`Sync` is a runtime god object.** It owns HTTP, WebSocket, MMKV, encryption, lifecycle, and business rules.
3. **`ChatScreen` is a presentation-layer god object.** Pagination, caches, TTS, model/profile selection, and send/delete/abort logic all live in one widget.
4. **3,548 force-unwraps and 1,748 casts** create a minefield of `Null check operator` / `TypeError` crashes.
5. **Tests are married to the `Sync` singleton.** 22 kLOC of Sync tests rely on 27 `@visibleForTesting` hooks and duplicated fake implementations.

---

## 2. Target Architecture

We move from the current "Sync owns everything" model to a layered, dependency-injected architecture.

```
Presentation (Widgets/Screens)
    └── ref.watch(provider)

State Layer (Riverpod Notifiers)
    └── thin, UI-focused state holders

Domain / Use-Case Layer
    └── business rules + orchestration (SendMessageUseCase, etc.)

Repository Layer (interfaces)
    └── remote + local coordination, caching policy

Data Layer
    ├── API clients (Dio, Socket.IO)
    ├── Local storage (MMKV, SecureStorage)
    └── Encryption workers
```

### Non-negotiable principles

- **No screen calls `sync.method()` directly.** All feature actions go through a notifier or use case.
- **No business logic in `build()` or `setState`.**
- **Models are immutable.** `freezed` everywhere except where a deliberate exception is documented.
- **Dependencies are injected via Riverpod providers**, not constructed as globals.
- **Every refactor phase ships with tests**; no structural change without coverage.

---

## 3. Refactor Phases

### Phase 0: Stabilize — Unblock the build and kill critical crashes

**Goal:** Get `flutter analyze` and `flutter test` green locally and in CI before any structural work.

| # | Task | Files / Evidence | Acceptance Criteria |
|---|------|------------------|---------------------|
| 0.1 | Fix dependency version mismatch | `pubspec.yaml` (`record: ^7.0.0` vs Dart 3.11.5) | `devenv shell -- flutter analyze` completes without version-solving errors |
| 0.2 | Resolve `go_router` / `flutterrific_opentelemetry` override | `pubspec.yaml` dependency_overrides | Remove the `go_router` override or upgrade observability package |
| 0.3 | Unify CI and local Flutter versions | `.github/workflows/ci.yml`, `devenv.nix` | CI and devenv use the same Flutter/Dart minor version |
| 0.4 | Audit top crash sites from force-unwraps | `features/chat/chat_screen.dart`, `features/machine/machine_detail_screen.dart`, `core/widgets/error_boundary.dart` | Open 5 most frequent `!` sites and replace with pattern matching or `WireParsers` |
| 0.5 | Add defensive null handling to `ChatScreen._loadInitialSettings` | `ROADMAP.md` notes 9 fatal/day from `session!.permissionMode!` | No force-unwraps in async init paths |
| 0.6 | Fix `InvalidateSync` disposed race | `lib/core/utils/invalidate_sync.dart` | Dispose no longer throws `StateError`; add stress test |
| 0.7 | Move goldens to Git LFS | `test/golden/goldens/`, `.gitattributes` | `git lfs ls-files` lists the golden PNGs |

**Estimated effort:** 1–2 weeks  
**Parallelizable:** Yes; can split across 2 engineers.

---

### Phase 1: Decouple Presentation from `Sync`

**Goal:** Eliminate direct `sync.` calls from `features/` and move business logic into notifiers/use cases.

| # | Task | Current State | Target |
|---|------|---------------|--------|
| 1.1 | Extract `ChatMessagesNotifier` | `chat_screen.dart` has ~60 state fields, manual pagination caches | New notifier owns: message list, pagination, neighbor cache, visible slice |
| 1.2 | Extract `ChatInputNotifier` / `ChatSendController` | Send/abort/delete/settings logic in `_chat_screen_actions.dart` | New notifier owns: send, abort, delete, draft autosave, profile/model selection |
| 1.3 | Move session creation logic | `new_session_screen.dart` calls `sync.createSession`/`createWorktree` | `SessionsNotifier.createSession()` or `CreateSessionUseCase` |
| 1.4 | Move artifact delete | `artifact_detail_screen.dart` calls sync directly | `ArtifactsNotifier.optimisticRemove` already exists; route through it |
| 1.5 | Remove `part` files from chat | `chat_screen.dart` + `_chat_screen_actions.dart` + `_chat_screen_builders.dart` | Convert to imports; make state public enough for action classes |
| 1.6 | Replace remaining direct `sync.` in feature screens | `sessions_list_content.dart` (29), `session_debug_screen.dart` (18), etc. | All feature `sync.` calls go through providers |

**Key deliverables:**
- `lib/features/chat/providers/chat_messages_notifier.dart`
- `lib/features/chat/providers/chat_send_notifier.dart`
- `lib/features/sessions/providers/create_session_notifier.dart` (or extend existing)
- Zero direct `sync.` calls inside `lib/features/` except for legitimate lifecycle listeners.

**Estimated effort:** 3–4 weeks  
**Risk:** Medium — touches core UX paths; must preserve P0 messaging invariants.

---

### Phase 2: Repository Layer

**Goal:** Introduce repository interfaces that abstract remote and local data sources, making notifiers testable without a full `Sync` instance.

| Domain | Interface | Implementations |
|--------|-----------|-----------------|
| Sessions | `SessionsRepository` | `RemoteSessionsRepository` (Dio) + `LocalSessionsRepository` (MMKV) |
| Messages | `MessagesRepository` | `RemoteMessagesRepository` + `LocalMessagesRepository` + `MessageOutbox` |
| Machines | `MachinesRepository` | `RemoteMachinesRepository` + `LocalMachinesRepository` |
| Artifacts | `ArtifactsRepository` | already partially present; formalize |
| Settings | `SettingsRepository` | remote CRDT merge + local MMKV |
| Friends/Feed/Todos | `FriendsRepository`, `FeedRepository`, `TodosRepository` | remote + local |

**Steps:**

| # | Task | Details |
|---|------|---------|
| 2.1 | Define repository interfaces | Start with `MessagesRepository` and `SessionsRepository`; keep them small |
| 2.2 | Migrate `Sync` data methods to repositories | Move `_sync_data*.dart` content into repository implementations |
| 2.3 | Inject repositories via Riverpod | `messagesRepositoryProvider`, `sessionsRepositoryProvider`, etc. |
| 2.4 | Add fake implementations for tests | `FakeMessagesRepository`, `FakeSessionsRepository` in `test/helpers/` |
| 2.5 | Convert provider tests to use fakes | `test/providers/*` should not need `createTestSync()` |

**Estimated effort:** 4–5 weeks  
**Risk:** Medium-High — changes how every domain loads data. Roll out one domain at a time behind feature flags if needed.

---

### Phase 3: Decompose the `Sync` God Object

**Goal:** Turn `Sync` from a god object into a thin facade/coordinator that delegates to focused managers.

**Target managers:**

| Manager | Responsibility | Source material |
|---------|---------------|-----------------|
| `SessionLifecycleManager` | Session create, spawn, delete, abort, git status | `_sync_operations_session.dart` |
| `MessageManager` | Send, receive, merge, dedupe, pagination state | `_sync_messaging*.dart` |
| `MachineManager` | Machine list, reachability, metadata | `_sync_data_machines.dart` |
| `ArtifactManager` | Artifact CRUD, decryption | `_sync_data_artifacts.dart` |
| `SettingsManager` | Settings CRDT, apply, dispatch | `_sync_data_settings.dart` |
| `SocketManager` | Socket.IO connect, disconnect, subscribe, RPC | `_sync_socket.dart`, `_sync_messaging_rpc.dart` |
| `LifecycleManager` | App suspend/resume, timer management | `_sync_lifecycle.dart` |
| `OutboxCoordinator` | Failed-send retry, backoff, flush | `message_outbox.dart` |

**Steps:**

| # | Task | Details |
|---|------|---------|
| 3.1 | Extract `MessageManager` first | Highest P0 priority; preserves messaging invariants |
| 3.2 | Extract `SessionLifecycleManager` | Second highest; session creation is flaky |
| 3.3 | Extract `SocketManager` and `OutboxCoordinator` | Isolates WebSocket and retry logic |
| 3.4 | Extract remaining managers | Settings, machines, artifacts, lifecycle |
| 3.5 | Keep `Sync` as a facade | `Sync` exposes the old API for backward compatibility during migration; mark methods `@Deprecated` |
| 3.6 | Remove `part` declarations | Each manager is a standalone file with imports |

**Estimated effort:** 6–8 weeks  
**Risk:** High — must not regress messaging. Recommended: do this **after** Phase 2 repositories exist, so managers depend on repositories, not raw `ApiClient`.

---

### Phase 4: Domain / Use-Case Layer

**Goal:** Encapsulate complex multi-step operations in testable use cases.

| Use Case | Responsibility | Replaces |
|----------|---------------|----------|
| `SendMessageUseCase` | Validate, encrypt, optimistic row, REST send, outbox enqueue, socket forward | `sync.sendMessage` + `_sync_messaging_send.dart` |
| `CreateSessionUseCase` | Validate machine, ping, spawn, optimistic placeholder, 3-attempt recovery | `sync.createSession` flow |
| `AbortSessionUseCase` | Cancel in-flight agent, clean up optimistic state | `sync.abortSession` |
| `DeleteSessionUseCase` | Optimistic delete, remote delete, cleanup | `SessionsNotifier.delete` / `sync.deleteSession` |
| `RetryMessageUseCase` | Retry by `localId`, preserving identity | `MessageOutbox` + chat retry UI |

**Steps:**

| # | Task | Details |
|------|------|---------|
| 4.1 | Implement `SendMessageUseCase` | Must pass existing P0 contract tests |
| 4.2 | Implement `CreateSessionUseCase` | Must preserve offline-machine guards |
| 4.3 | Wire use cases into notifiers | Notifiers become thin adapters |
| 4.4 | Add use-case-level contract tests | Each use case gets its own test file |

**Estimated effort:** 3–4 weeks  
**Risk:** Medium — mostly mechanical once repositories exist.

---

### Phase 5: Type Safety & Code Quality

**Goal:** Eliminate the bulk of runtime crashes from `!` and `as`, and enforce immutability.

| # | Task | Details |
|---|------|---------|
| 5.1 | Migrate `Settings` to `freezed` | Replace mutable `var` fields with `final`; move CRDT logic to `SettingsRepository` |
| 5.2 | Replace JSON `as` casts with `WireParsers` | Start with models and API response parsing |
| 5.3 | Audit top 100 `!` sites | Replace with null-aware patterns; add regression tests for each crash |
| 5.4 | Reduce `dynamic` in public APIs | Use `Object?` / sealed classes; start with chat tool views |
| 5.5 | Enforce 800-line file limit | Add a CI check or custom lint |
| 5.6 | Remove `print` and silent `catch (_)` | Already mostly clean; finish the stragglers |
| 5.7 | Centralize error formatting | `lib/core/utils/error_formatters.dart` replaces 3 duplicate `_formatError` helpers |
| 5.8 | Add `very_good_analysis` or custom lint | Tighten analysis_options; currently `test/` is excluded |

**Estimated effort:** 4–6 weeks  
**Risk:** Low-Medium — many small changes; can be done incrementally.

---

### Phase 6: Test Architecture Modernization

**Goal:** Reduce test coupling to `Sync`, eliminate flakiness, and make tests fast and deterministic.

| # | Task | Details |
|---|------|---------|
| 6.1 | Create `SyncTestHarness` | One helper that sets up fakes, Dio mock server, and teardown |
| 6.2 | Centralize fake implementations | `FakeEncryption`, `FakeSessionEncryption`, `FakeMessagesRepository` in `test/helpers/` |
| 6.3 | Remove 22 copied `_stubAllSyncs` blocks | Use `SyncTestHarness.stubAll()` |
| 6.4 | Replace real `Future.delayed` waits | Use `fake_async`, deterministic pump helpers, or `await pumpEventQueue()` |
| 6.5 | Run native-dependent tests in CI | Install libsodium/MMKV native libs or add macOS runner |
| 6.6 | Shard tests by runtime | Use historical timings instead of alphabetical file ranges |
| 6.7 | Fix coverage merging | Use `lcov --add-tracefile` instead of `grep -v TN:` |
| 6.8 | Add iOS build smoke test | `flutter build ios --no-codesign` in CI |

**Estimated effort:** 3–4 weeks  
**Risk:** Medium — test changes can mask regressions if not done carefully.

---

### Phase 7: CI/CD & Tooling

| # | Task | Details |
|---|------|---------|
| 7.1 | Add AAB build job | Required for Play Store |
| 7.2 | Fix NDK/plugin compileSdk workaround | Move from `sed` in CI to a local Gradle plugin patch or fork |
| 7.3 | Align JDK | Use JDK 17 in devenv to match Android build config |
| 7.4 | Add pre-commit hooks via devenv | `flutter analyze` + fast unit-test subset |
| 7.5 | Update `docs/DEV_OPS_CI_CD.md` | Document current CI reality (tests now run, sharding, etc.) |
| 7.6 | Add performance regression CI | Track cold-start and `fetchMessages` p95 |

**Estimated effort:** 2–3 weeks  
**Risk:** Low.

---

## 4. Suggested Execution Order

```
Phase 0  ──►  Phase 1  ──►  Phase 2  ──►  Phase 3  ──►  Phase 4
(build)       (screens)    (repos)      (managers)   (use cases)
   │              │            │             │             │
   └──────────────┴────────────┴─────────────┴─────────────┘
                Phase 5, 6, 7 run in parallel / follow-on
```

**Rationale:**
- Stabilize first so every subsequent phase has green CI.
- Decouple screens from `Sync` so we know what APIs the repository layer must expose.
- Build repositories so managers have a clean data abstraction.
- Decompose `Sync` into managers once repositories exist.
- Add use cases after the domain is already clean.

---

## 5. Migration Strategy

### 5.1 One domain at a time

Do not refactor all domains simultaneously. Recommended order:

1. **Messages** (P0)
2. **Sessions** (P0)
3. **Machines** (affects session creation)
4. **Artifacts**
5. **Settings**
6. **Friends / Feed / Todos**

### 5.2 Backward compatibility

- Keep the existing `Sync` public API intact during each phase.
- New code lives alongside old code; old code calls into new abstractions.
- Remove deprecated `Sync` methods only after all callers migrate.

### 5.3 Feature flags

For risky changes (messaging, session creation), consider gating behind a remote flag so the new path can be rolled back without a release.

### 5.4 Testing strategy per phase

| Phase | Required tests |
|-------|---------------|
| 0 | Unit tests for crash fixes; build/CI verification |
| 1 | Widget tests for refactored screens; notifier tests |
| 2 | Repository contract tests with fake + real remote doubles |
| 3 | Manager unit tests; full P0 messaging contract suite must pass |
| 4 | Use-case contract tests; integration tests unchanged or expanded |
| 5 | Regression tests for every null-safety fix |
| 6 | All existing tests pass faster; no new skips |
| 7 | CI green on all platforms |

---

## 6. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Messaging regression | Medium | Critical | Phase 3 is gated by existing P0 contract tests; no merge without full suite green |
| Long-running branch diverges | High | High | Merge to `main` at the end of every phase, even if work is incomplete behind deprecated APIs |
| Test flakiness increases | Medium | Medium | Replace `Future.delayed` before adding new integration tests; run each shard 3× in CI |
| Performance regression | Low | High | Add cold-start / fetchMessages benchmarks before and after Phase 3 |
| Team churn / context loss | Medium | Medium | Document decisions in this plan; keep ADRs for major architectural choices |
| iOS/macOS regressions | Medium | Medium | Add `flutter build ios --no-codesign` CI job in Phase 0 |

---

## 7. Success Metrics

| Metric | Current | 6-month target |
|--------|---------|----------------|
| `flutter analyze` green locally | ❌ | ✅ |
| CI Flutter == local Flutter | ❌ | ✅ |
| Files > 800 lines | 28 | ≤ 5 |
| `sync.` calls in `features/` | 137 | ≤ 10 |
| `!` operators | 3,548 | ≤ 500 |
| `as` casts | 1,748 | ≤ 500 |
| `setState` calls | 354 | ≤ 150 |
| Test runtime (CI) | ~15 min × 8 shards | ≤ 12 min × 6 shards |
| Null-check-operator crashes | 21 fatal/day | 0 |
| Sync singleton LOC | 12,625 | ≤ 2,000 facade + managers |

---

## 8. Quick Wins (can be done this week)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| Q1 | Pin `record: ^6.2.1` and fix `pubspec.yaml` | 1 hr | Unblocks local build |
| Q2 | Unify CI + local Flutter to 3.44.x or 3.41.x | 2 hr | Eliminates "works on my machine" |
| Q3 | Replace top 10 `!` crash sites with pattern matching | 1 day | Reduces fatal crashes |
| Q4 | Move goldens to Git LFS | 30 min | Stops repo bloat |
| Q5 | Centralize `_formatError` duplicates | 2 hr | Removes duplicate code |
| Q6 | Delete/merge 22 copied `_stubAllSyncs` into `test_helpers.dart` | 1 day | Cleaner tests |
| Q7 | Add `flutter build ios --no-codesign` CI job | 2 hr | Catches iOS regressions |

---

## 9. Open Questions / Decisions Needed

1. **Flutter version:** Bump devenv to 3.44.x to match CI, or pin CI to 3.41.x?
2. **Code generation:** Continue checking in `*.g.dart` / `*.freezed.dart`, or generate in CI?
3. **Riverpod code generation:** Project currently avoids `@riverpod`. Keep manual notifiers or adopt code gen for new providers?
4. **Repository scope:** Should `MessagesRepository` own the outbox, or should `OutboxCoordinator` remain separate?
5. **Settings migration:** Is the mutable `Settings` exception still justified, or do we migrate fully to `freezed`?

---

## 10. Appendix: Files to watch during each phase

### Phase 0
- `pubspec.yaml`
- `.github/workflows/ci.yml`
- `devenv.nix`
- `lib/core/utils/invalidate_sync.dart`
- `lib/features/chat/chat_screen.dart`
- `lib/features/machine/machine_detail_screen.dart`

### Phase 1
- `lib/features/chat/chat_screen.dart`
- `lib/features/chat/_chat_screen_actions.dart`
- `lib/features/chat/_chat_screen_builders.dart`
- `lib/features/sessions/widgets/sessions_list_content.dart`
- `lib/features/sessions/new_session_screen.dart`
- `lib/features/artifacts/artifact_detail_screen.dart`

### Phase 2–4
- `lib/core/services/sync_service.dart`
- `lib/core/services/_sync_*.dart`
- `lib/core/providers/*`
- `lib/core/api/*`
- `lib/core/models/*`

### Phase 5
- `lib/core/models/settings.dart`
- `lib/core/providers/settings_notifier.dart`
- `lib/core/utils/utils.dart`
- `lib/core/utils/wire_parsers.dart`
- `lib/features/chat/tools/*`

### Phase 6–7
- `test/helpers/test_helpers.dart`
- `test/helpers/fake_mmkv_platform.dart`
- `test/services/sync_service_test.dart`
- `test/integration/*`
- `.github/workflows/ci.yml`
- `docs/DEV_OPS_CI_CD.md`
