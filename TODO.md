# happy_flutter Refactor TODO

**Status:** Phase 4a complete and shipped. Phase 4b is the active work-in-progress.

This file tracks the full-scale refactor of `happy_flutter`. It exists because the work was paused mid-stream; the next developer (or future me) should pick up at **Phase 4b**.

---

## Context

The codebase has accumulated architectural debt that is now blocking further progress: a 12,625-line `Sync` god object split across 17 part files but still one class, 28 direct `import 'sync_service.dart'` sites with `sync.*` calls inside widget `build()` methods, state mutations (`sessionAllow`/`sessionDeny`/`createSession`) firing from widget handlers, and the P0 `localId` invariant minted in a single notifier (`ChatActionNotifier`) that lives outside the testable layer. GlitchTip has documented real production impact: 55 fatal/day from `InvalidateSync` disposed, 1 fatal/day from ref-in-disposed-widget, 27 warnings/day from `CryptoSecretBox.decrypt failed`, 33 warnings/day from offline-machine session creation.

The plan decomposes `Sync` into 6 focused domain managers behind a thin `SyncCoordinator` facade, introduces a repository layer that owns cross-cutting concerns (retry, breadcrumbs, **localId minting**), and routes all UI mutations through Riverpod notifiers. The refactor is being done in **6 phases over 7 sprints** (~10.5 weeks / 5 months), keeping the 7-job CI green and the GlitchTip fixes preserved throughout. Each phase is shippable in isolation; rollback is per-phase.

Existing utilities to reuse (do not reinvent):
- `SyncSubscriptionMixin` at `lib/core/utils/sync_subscription_mixin.dart` — 8 screens already use it; the legacy `zen_home.dart` migrates to it.
- `OptimisticMutation<T>` at `lib/core/utils/optimistic_mutation.dart` — already used for session/artifact delete.
- `safePop()` at `lib/core/utils/safe_pop.dart` — for nav-after-await.
- `InvalidateSync` at `lib/core/utils/invalidate_sync.dart` — debounced server-fetch primitive.
- `WireParsers` in `lib/core/wire/` — lenient JSON coercion.
- `MessageStateMachine` in `lib/core/fsm/` — already drives the P0 lifecycle.
- `_shared.dart` `unset` sentinel for `copyWith`.

---

## Top 10 Pain Points (Impact × Effort)

| # | Pain Point | Location | Impact | Effort |
|---|-----------|----------|--------|--------|
| 1 | **Widget `build()` calls `sync.*` getters**, recomputing per frame | `features/sessions/widgets/sessions_list_content.dart:543,569,799,991,1145,1164`; `features/chat/_chat_screen_builders.dart:29,31`; `features/chat/chat_screen.dart:948,1412`; `features/sessions/session_recent_screen.dart:222-224`; `features/sidebar/sidebar_view.dart:362` | HIGH | LOW |
| 2 | **`Sync` god object (12,625 lines)**, 90+ fields, 50+ public methods, 28 importers | `core/services/sync_service.dart` + 17 part files | HIGH | HIGH |
| 3 | **State mutations from widget handlers** (`sessionAllow`/`Deny`, `createSession`, `createWorktree`, `applySettings`) | `features/chat/tools/tool_view.dart:371-416`; `features/chat/tools/ask_user_question_view.dart:543,557`; `features/sessions/new_session_dialog.dart:386,408,415`; `features/chat/encryption_debug_screen.dart:195`; `features/chat/_chat_screen_actions.dart:413,581` | HIGH | MEDIUM |
| 4 | **`session_activity_coordinator.dart` Timer/Subscription leak** (60s periodic, never cancelled) | `core/services/session_activity_coordinator.dart:41-42` | HIGH | LOW |
| 5 | **`showDialog`/`showModalBottomSheet` without `context.mounted` guard** (12 sites) | `features/settings/settings_screen.dart:408,570,614`; `features/dev/dev_logs_screen.dart:228,453`; `features/dev/network_inspector_screen.dart:415`; `features/sftp/screens/sftp_directory_manager_screen.dart:238`; `features/artifacts/edit_artifact_screen.dart:349`; `features/terminal/terminal_screen.dart:111`; `features/settings/developer_screen.dart:264,299,330,373` | HIGH | LOW |
| 6 | **`AuthStateNotifier` mixes 6 concerns** (auth state, token refresh, deep links, Sentry, lifecycle, sync invalidation) | `core/providers/auth_state_notifier.dart` (196 lines) | MEDIUM | MEDIUM |
| 7 | **No repository layer** — notifiers call `sync.*` directly; `ChatActionNotifier` is the only `localId` minter for P0 | `core/providers/chat_action_notifier.dart:9 calls`; `core/providers/sessions_notifier.dart:9`; `core/providers/settings_notifier.dart:8` | HIGH | HIGH |
| 8 | **`_sync_operations_session.dart` is 1,642 lines** with ~600-line `sendMessage` | `core/services/_sync_operations_session.dart:43,~900` | MEDIUM | MEDIUM |
| 9 | **`sessions_list_content.dart` `build()` is ~1,070 lines** mixing date/folder/unread-focus/search/empty/selection/animations | `features/sessions/widgets/sessions_list_content.dart:222` | MEDIUM | MEDIUM |
| 10 | **P0 regression test gaps** — `InvalidateSync._disposed` in Sync context, outbox retry localId preservation, DEK fallback chain | `test/services/sync_service_race_test.dart`, `test/services/message_outbox_test.dart`, `test/encryption/decrypt_failure_softening_test.dart` | HIGH | LOW |

**Skipped:** force-unwraps in `session_info_screen.dart` (typed fields, no GlitchTip cluster); `MachinesNotifier`+`SessionGitStatusNotifier` merge (low value); async-gap audit (no critical issues found).

---

## Target Architecture

```
PRESENTATION  (lib/features/**)
   Widgets (build())
     │  reads
     ▼  ref.watch(sessionsNotifierProvider).lastMessageTimestamps
   ConsumerStatefulWidget + SyncSubscriptionMixin
     │  ref.read(...).notifier.action()
     ▼
NOTIFIER LAYER  (lib/core/providers/**)
   SessionsNotifier, MessagesNotifier, MachinesNotifier,
   PermissionsNotifier, ChatActionNotifier, AuthNotifier,
   DeepLinkNotifier, SettingsNotifier, ProfileNotifier, ...
   - Owns UI state (Riverpod state)
   - Triggers repository calls
   - Emits derived state
     │  ref.read(messagesRepositoryProvider)
     ▼
REPOSITORY LAYER  (lib/core/repositories/**)  [NEW]
   MessagesRepository, SessionsRepository, MachinesRepository,
   PermissionsRepository, ArtifactsRepository, SettingsRepository
   - Wraps domain managers
   - Adds retry / timeout / breadcrumbs
   - Testable in isolation
   - Owns P0 localId minting (one place)
     │  domainManager.send(...)
     ▼
SYNC DOMAIN MANAGERS  (lib/core/sync/**)  [EXTRACTED FROM Sync]
   SessionManager    (~2200 lines)
   MessageManager    (~3700 lines)
   MachineManager    (~2200 lines)
   ArtifactManager   (~300 lines)
   SettingsManager   (~500 lines)
   SocketManager     (~1700 lines)
   IsolateHelpers    (~325 lines, free functions)
   SyncCoordinator   (~300 lines, wiring only)
     - Owns the 10 InvalidateSync instances
     - Owns stream controllers
     - Exposes create()/restore()/suspend()/resume()/shutdown()
     │  HTTP / Socket.IO / MMKV
     ▼
INFRASTRUCTURE  (lib/core/api/**, lib/core/storage/**, lib/core/encryption/**)
   SessionsApi, MessagesApi, ServicesApi, KvApi, PushApi, ...
   StorageService, SessionEncryption, ...
```

**Key decisions (confirmed):**
- `Sync` is **deleted in Phase 5** — all 28 importers migrate to `ref.read(<domainManager>Provider)` as part of the same phase. No facade survives.
- `ChatActionNotifier` is **deleted** — split across 4 notifiers: `sendMessage`/`retryFailedMessage` → `MessagesNotifier`; `abortSession`/`deleteSession` → `SessionsNotifier`; `loadCodexModels` → new `CodexModelsNotifier`; `saveProfile` → `SettingsNotifier`.
- `MessagesRepository.sendMessage()` is the **only** place that mints `localId`. The `_nextLocalId` field on `ChatActionNotifier` is removed.
- `SyncSubscriptionMixin` stays as the screen-side pattern. The 8 adopting screens need no change; `zen_home.dart` legacy migrates to it.

---

## Phase 1: Safety Net (Sprint 1, 1 week) — Risk: LOW — **DONE**

Stop the bleeding: fix the timer leak and add `context.mounted` guards.

**Files:**
- `lib/core/services/session_activity_coordinator.dart` — add `dispose()`; cancel `_sub` and `_refreshTimer`. Call from `Sync.shutdown()`.
- `lib/features/settings/settings_screen.dart:408,570,614`
- `lib/features/terminal/terminal_screen.dart:111`
- `lib/features/dev/dev_logs_screen.dart:228,453`
- `lib/features/dev/network_inspector_screen.dart:415`
- `lib/features/sftp/screens/sftp_directory_manager_screen.dart:238`
- `lib/features/artifacts/edit_artifact_screen.dart:349`
- `lib/features/settings/developer_screen.dart:264,299,330,373`
- (all above) — wrap with `if (context.mounted)` after `await showModalBottomSheet`/`showDialog`/`safePop()`.
- `test/services/session_activity_coordinator_dispose_test.dart` (new) — asserts Timer/Sub cancelled after dispose.
- `test/widget/dialog_lifecycle_test.dart` (new) — dialog dismissed mid-await, no StateError.

**Success criteria:** `session_activity_coordinator_dispose_test.dart` passes; grep returns 0 unguarded `showDialog`/`showModalBottomSheet` callers in the listed paths; GlitchTip clusters "InvalidateSync disposed" and "Ref used in disposed widget" stay at 0.

**Verify:** `flutter test test/services/session_activity_coordinator_dispose_test.dart test/widget/dialog_lifecycle_test.dart`; `flutter analyze`; all 7 CI jobs green.

---

## Phase 2: Build-Time State Hoisting (Sprint 2, 1 week) — Risk: LOW — **DONE**

Eliminate `sync.*` getter calls inside widget `build()` methods by moving reads into notifier state.

**Files:**
- `lib/core/providers/sessions_notifier.dart` — add `lastMessageTimestamps`, `lastMessagePreviews`, `lastMessageRoles`, `unreadCounts`, `optimisticArchivedIds` (all `Map<String, …>`/`Set<String>`). Populate on `_loadFromSync` + `_applyDataChanged`.
- `lib/core/providers/messages_state_notifier.dart` (new or extend existing) — add `hasOlderMessages: Map<String, bool>`, `isLoadingOlderMessages: Map<String, bool>`.
- `lib/core/providers/current_session_notifier.dart` — add `isReadyForMessages: bool`, `usage: Map<String, SessionUsage>`.
- `lib/features/sessions/widgets/sessions_list_content.dart:543,569,799,991,1145,1164` — replace `sync.getLastMessage*` with notifier state.
- `lib/features/sessions/session_recent_screen.dart:222-224` — same.
- `lib/features/sidebar/sidebar_view.dart:362` — same.
- `lib/features/chat/_chat_screen_builders.dart:29,31` — replace `sync.isLoadingOlderMessages/hasOlderMessages`.
- `lib/features/chat/chat_screen.dart:948,1412` — replace `sync.isSessionReadyForMessages`, `sync.sessionUsage`.
- `test/providers/sessions_notifier_derived_state_test.dart` (new) — asserts derived state computed from sessions list.

**Success criteria:** `grep -n 'sync\.get\(LastMessage\|UnreadCount\|HasOlder\|IsLoadingOlder\|IsSessionReady\|SessionUsage\)' lib/features/` returns 0 matches. Consumers rebuild only on data change. New tests pass.

**Verify:** `flutter test test/providers/`; `test/integration/session_lifecycle_e2e_test.dart`; all 7 CI jobs green.

---

## Phase 3: UI Mutation Routing (Sprint 3, 1.5 weeks) — Risk: MEDIUM — **DONE**

Move all `sync.<mutator>()` calls from widget handlers into notifier actions.

**Files:**
- `lib/core/providers/permissions_notifier.dart` (new) — `allow(sessionId, permissionId, …)`, `deny(…)`.
- `lib/core/providers/chat_action_notifier.dart` — add `retryFailedMessage(sessionId, localId)`, `loadCodexModels(machineId)`.
- `lib/core/providers/sessions_notifier.dart` — add `markSessionArchived(sessionId, archived)`, `createWorktree(…)`, `createSession(…)`.
- `lib/core/providers/encryption_notifier.dart` (new) — `clearAllCaches()`.
- `lib/features/chat/tools/tool_view.dart:371-416` — use `PermissionsNotifier`; `sendMessage` → `ChatActionNotifier`.
- `lib/features/chat/tools/ask_user_question_view.dart:543,557` — same.
- `lib/features/sessions/sessions_screen.dart:713` — use `SessionsNotifier.markSessionArchived`.
- `lib/features/sessions/widgets/session_dismissible.dart:83` — same.
- `lib/features/sessions/new_session_dialog.dart:386,408,415` — route through notifiers.
- `lib/features/chat/encryption_debug_screen.dart:195` — use `EncryptionNotifier`.
- `lib/features/chat/_chat_screen_actions.dart:413,581` — remove direct `sync.*` calls.
- `test/providers/permissions_notifier_test.dart` (new) — unit test with mock.
- `test/integration/permission_flow_e2e_test.dart` (new or extend) — e2e allow/deny.

**Success criteria:** `grep -n 'sync\.\(sessionAllow\|sessionDeny\|createSession\|createWorktree\|markSessionArchived\|applySettings\|retryFailedMessage\|machineGetCodexModels\|encryption\.clearAllCaches\)' lib/features/` returns 0 widget-handler matches. New notifier actions covered by tests.

**Verify:** `flutter test test/providers/ test/integration/permission_flow_e2e_test.dart`; manual: ask a permission, allow it, send a message, archive a session; all 7 CI jobs green.

---

## Phase 4: Repository Layer + `Sync` Decomposition — Round 1 (Sprints 4-5, 3 weeks) — Risk: HIGH

Introduce the repository layer and split `Sync` into 6 domain managers + `SyncCoordinator`. Done in two sub-sprints to limit blast radius.

### Phase 4a — Lowest-risk extractions — **DONE**

Shipped commits:
- Extract `ArtifactManager` from `_sync_data_artifacts.dart`.
- Create `ArtifactsRepository` and route `ArtifactsNotifier` through it.
- Extract `SettingsManager` from settings/profile/push/native-update parts of `_sync_operations.dart`.
- Create `SettingsRepository` and route `SettingsNotifier`/`ProfileNotifier` through it.
- Convert `Sync.artifact*`/`Sync.setting*`/`Sync.profile*`/`Sync.purchases*`/`Sync.pushToken*`/`Sync.nativeUpdate*` to 1-line forwarders.

**Phase 5 will delete these forwarders** as part of the importer migration. Until then they keep the 28 importers compiling.

### Phase 4b — `SessionManager` + `MachineManager` — **ACTIVE / NOT STARTED**

This is the next body of work. Pick it up here.

**Deliverables:**
- `lib/core/sync/session_manager.dart` (new) — `fetchSessions`, `fetchSingleSession`, `deleteSession`, `markSessionArchived/Unarchived`, `isSessionOptimisticallyArchived`, `getOptimisticallyArchivedIds`, `refreshSessions`, `refreshSessionsListData`, `sessions` getter, session-message getters, session usage. Source: `_sync_data.dart` (~726 lines), `_sync_sessions.dart` (~178 lines), session parts of `_sync_operations.dart` (~390 lines), `_sync_session_restore_split.dart` (~49 lines).
- `lib/core/sync/machine_manager.dart` (new) — `createSession`, `machineBash`, `machineReadFile`, `machineGetClaudeUsageLimits`, `machineGetCodexModels`, `machineGetCodexUsage`, `createWorktree`, `machines` getter, `waitForAgentReady`, `isSessionReadyForMessages`, `killSession`, `abortSession`, `sessionRPC`, `machineRPC`. Source: `_sync_data_machines.dart` (~442 lines), `_sync_operations_session.dart` (~1642 lines), `_sync_health.dart` (~68 lines).
- `lib/core/repositories/sessions_repository.dart` (new) — wraps `SessionManager`.
- `lib/core/repositories/machines_repository.dart` (new) — wraps `MachineManager`.
- `lib/core/providers/sessions_notifier.dart`, `machines_notifier.dart` — use new repositories.
- `test/repositories/sessions_repository_test.dart`, `machines_repository_test.dart` (new).
- `test/sync/session_manager_test.dart` (new) — migrate relevant tests from `sync_service_test.dart`.

**Forwarders to keep during migration:** `Sync.fetchSessions`, `Sync.fetchSingleSession`, `Sync.deleteSession`, `Sync.markSessionArchived/Unarchived`, `Sync.isSessionOptimisticallyArchived`, `Sync.getOptimisticallyArchivedIds`, `Sync.refreshSessions`, `Sync.refreshSessionsListData`, `Sync.createSession`, `Sync.machineBash`, `Sync.machineReadFile`, `Sync.machineGetClaudeUsageLimits`, `Sync.machineGetCodexModels`, `Sync.machineGetCodexUsage`, `Sync.createWorktree`, `Sync.waitForAgentReady`, `Sync.isSessionReadyForMessages`, `Sync.killSession`, `Sync.abortSession`, `Sync.sessionRPC`, `Sync.machineRPC`. These should become 1-line forwarders to the managers so the 28 importers keep compiling.

**Success criteria:** `Sync` class drops from ~12,625 → ~7,000 lines. All 28 `import 'sync_service.dart'` sites still compile. Existing integration tests pass unchanged.

**Verify:** `flutter test` (full suite); `flutter analyze` (file sizes ≤ 800 lines); `test/integration/session_lifecycle_e2e_test.dart`, `session_spawning_e2e_test.dart`; all 7 CI jobs green. No `build_runner` regen expected.

**Rollback:** each manager migration is a single PR; revert that PR. Forwarders keep API stable.

---

## Phase 5: Repository Layer + `Sync` Decomposition — Round 2 (Sprint 6, 1.5 weeks) — Risk: HIGH — **NOT STARTED**

Extract `MessageManager`, `SocketManager`, `SyncCoordinator`. Wire `ChatActionNotifier` through `MessagesRepository` (the P0 `localId` minting path).

**Files:**
- `lib/core/sync/message_manager.dart` (new) — `sendMessage`, `fetchMessages`, `fetchOlderMessages`, `retryFailedMessage`, `onSessionVisible/Invisible`, `messagesForSession`, `messagesRevision`, `hasOlderMessages`, `isLoadingOlderMessages`, `getUnreadCount`, `getLastMessage*`, `onSessionMessagesChanged`, `onPaginationError`. Source: `_sync_messaging.dart` (~1442 lines), `_sync_messaging_merge.dart` (~779 lines), `_sync_messaging_send.dart` (~946 lines), `_sync_messaging_rpc.dart` (~1130 lines).
- `lib/core/sync/socket_manager.dart` (new) — `create`, `restore`, `subscribeToUpdates`, `handleUpdate`, `connectionStatus`, `isReady`, `isEncryptionInitialized`, `onDataChanged`, `onDomainChanged`, `onSyncStateChanged`, `isSyncing`, `syncProgress`, `dataChangeCounter`. Source: `_sync_socket.dart` (~1025 lines), `_sync_socket_events.dart` (~690 lines).
- `lib/core/sync/sync_coordinator.dart` (new, ~300 lines) — owns the 10 `InvalidateSync` instances + stream controllers. Wires `SessionManager`, `MessageManager`, `MachineManager`, `ArtifactManager`, `SettingsManager`, `SocketManager`. Exposes `create(creds, enc)`, `restore(creds, enc)`, `suspend()`, `resume()`, `shutdown()`.
- `lib/core/repositories/messages_repository.dart` (new) — wraps `MessageManager`. **Owns the `localId` minting path** (moves from `ChatActionNotifier._nextLocalId`). Signature: `sendMessage({required sessionId, required text})` returns the minted `localId` to the notifier.
- `lib/core/repositories/permissions_repository.dart` (new) — wraps `MessageManager.sessionAllow/Deny`.
- `lib/core/providers/chat_action_notifier.dart` — **deleted**. Replaced by:
  - `MessagesNotifier.sendMessage()` + `retryFailedMessage()` (consumes `MessagesRepository.sendMessage()`)
  - `SessionsNotifier.abortSession()` + `deleteSession()`
  - `CodexModelsNotifier` (new) — `loadCodexModels(machineId)`
  - `SettingsNotifier.saveProfile()`
- `lib/core/providers/messages_state_notifier.dart` (from Phase 2) — use `MessagesRepository`.
- `lib/core/providers/permissions_notifier.dart` (from Phase 3) — use `PermissionsRepository`.
- `lib/core/services/sync_service.dart` — `Sync` is **deleted** in this phase. All 17 part files deleted. All 28 importers migrate to `ref.read(<domainManager>Provider)` calls.
- **Importer migration work** — for each of the 28 files that import `sync_service.dart`, replace `sync.<method>()` with the appropriate domain manager call. The domain manager providers are exposed via the new `lib/core/sync/` files. Migration is mechanical, but 28 files is the work.
- **Edge cases:**
  - `main.dart` and `app_lifecycle_service.dart` call `sync.suspend()/resume()/create()/restore()/shutdown()` → move to `SyncCoordinator` (or its provider).
  - `chat_screen.dart` (~14 calls) and `new_session_screen.dart` (~6 calls) need careful per-call analysis.
  - Tests using `Sync()` directly need updating to use the new managers.
- `lib/core/sync/isolate_helpers.dart` (new) — promote `_sync_isolate_helpers.dart` (~324 lines) to top-level free functions (no class).
- `test/sync/message_manager_test.dart`, `socket_manager_test.dart` (new) — migrate from `sync_service_test.dart`, `sync_service_send_protocol_test.dart`.
- `test/repositories/messages_repository_test.dart` (new) — **P0: `localId` minted in repository, not notifier.**
- `test/repositories/messages_repository_localid_test.dart` (new) — **P0: outbox retry preserves `localId`.**
- `test/services/sync_service_race_test.dart` (extend) — **P0: `InvalidateSync._disposed` guard in Sync-integrated context.**
- `test/encryption/dek_fallback_test.dart` (new) — **Regression: DEK fallback → AES MAC failure softening** (GlitchTip 27-event cluster).

**Success criteria:**
- `lib/core/services/sync_service.dart` and all 17 part files are **deleted**. `grep -rn "import.*sync_service" lib/ test/` returns 0 matches.
- `MessageManager` and `SocketManager` ≤ 800 lines each (split further if not).
- `ChatActionNotifier` is **deleted**. 4 new notifier methods are in place.
- `MessagesRepository.sendMessage()` is the only `localId` minter — verified by `grep -rn '_nextLocalId\|createLocalMessageId\|nextMessageId' lib/` showing only the repository call site.
- All 4 P0 regression tests pass.

**Verify:** `flutter test`; `flutter analyze`; all 7 CI jobs green; `grep -rn 'sync\.\|import.*sync_service' lib/ test/` returns 0 matches.

---

## Phase 6: Notifier Cleanup + Widget Decomposition (Sprint 7, 1.5 weeks) — Risk: MEDIUM — **NOT STARTED**

Final cleanup: split the largest notifiers and widget files; finish `SyncSubscriptionMixin` adoption; consolidate duplicated date formatting.

**Files:**
- `lib/core/providers/auth_state_notifier.dart` — split into `AuthNotifier` (state only), `DeepLinkNotifier` (pending/active), thin `AuthOrchestrator` (coordination). Existing API preserved via re-exports.
- `lib/features/sessions/widgets/sessions_list_content.dart` — split into 5 files: `sessions_list_content.dart` (300, orchestrator), `_date_view.dart` (200), `_folder_view.dart` (200), `_unread_focus_view.dart` (200), `_shell.dart` (200, search/empty/selection).
- `lib/features/chat/tools/tool_view.dart` — split into 4: `tool_view.dart` (300, core+permission flow), `_header.dart` (200), `_permission_footer.dart` (200), `_content_router.dart` (300, switch across tool-type sub-views).
- `lib/features/chat/chat_input.dart` — split into 4: `chat_input.dart` (300, core), `_autocomplete.dart` (200), `_dictation.dart` (200), `_toolbar.dart` (200).
- `lib/core/providers/friends_notifier.dart` — rename `refreshFromSync` → `loadFromSync` (server fetch); add `applyServerState` for in-memory cache update.
- `lib/features/zen/zen_home.dart:37` — replace direct `sync.onDataChanged.listen` with `SyncSubscriptionMixin` (matches `zen_home.dart:113` pattern).
- `lib/core/utils/date_formatting.dart` (new) — unify `formatDateHeader` (`session_utils.dart:14`), `formatTimestamp` (`utils.dart`), `_localizeDateGroup` (`sessions_list_content.dart:1239`).
- `test/features/sessions/sessions_list_split_test.dart` (new) — widget test for each sub-view.
- `test/providers/auth_notifier_split_test.dart` (new) — tests for the 3 split notifiers.
- `test/utils/date_formatting_test.dart` (new) — consolidated format tests.

**Success criteria:**
- All files ≤ 800 lines (`find lib -name '*.dart' -exec wc -l {} +` shows max ≤ 800).
- `sessions_list_content.dart` ≤ 300 lines.
- `tool_view.dart` ≤ 300 lines.
- `chat_input.dart` ≤ 300 lines.
- `auth_state_notifier.dart` ≤ 100 lines per file (3 files).
- `grep -rn 'sync\.onDataChanged\.listen' lib/features/` returns 0 matches.

**Verify:** `flutter test` (full suite); `flutter analyze`; `flutter test --coverage` (coverage holds or improves); manual smoke test of all 4 split widgets; all 7 CI jobs green.

---

## Migration Order

| Sprint | Item | Phase | Risk | Status |
|--------|------|-------|------|--------|
| 1 | Fix `session_activity_coordinator` Timer/Subscription leak + 12 `context.mounted` guards | 1 | LOW | Done |
| 2 | Hoist build-time `sync.*` reads into notifier state | 2 | LOW | Done |
| 3 | Route widget-handler mutations through notifiers | 3 | MEDIUM | Done |
| 4a | Extract `ArtifactManager` + `SettingsManager`; create `ArtifactsRepository`, `SettingsRepository` | 4 | HIGH | Done |
| 4b | Extract `SessionManager` + `MachineManager`; create `SessionsRepository`, `MachinesRepository` | 4 | HIGH | **Active** |
| 5 | Extract `MessageManager` + `SocketManager` + `SyncCoordinator`; create `MessagesRepository` (owns `localId`); delete `Sync` facade; delete `ChatActionNotifier`; migrate 28 importers | 5 | HIGH | Not started |
| 6 | Split `auth_state_notifier`, `sessions_list_content`, `tool_view`, `chat_input`; migrate `zen_home.dart` to `SyncSubscriptionMixin`; unify date formatting; rename `FriendsNotifier` methods | 6 | MEDIUM | Not started |

Total: **7 sprints** (~10.5 weeks / 5 months). Plan targets 6-12 months, so ~2-6 months of slack for retries, GlitchTip triage, `build_runner` regen.

**Sequence rationale:** Sprint 1 first (stops bleeding, unblocks everything). Sprints 2-3 are low-risk UI cleanups building muscle memory. Sprint 4a is the easiest decomposition (artifacts/settings have small surface). 4b and 5 are the high-risk extractions. Sprint 6 is final cleanup, gated on 4-5 being stable.

---

## Out of Scope

1. **Model changes** — no `freezed`/`json_serializable` regen needed. File a follow-up if a refactor exposes a model gap.
2. **i18n generated files** — `lib/l10n_generated/*.dart` are regenerated; do not edit.
3. **Encryption internals** — only the Phase 5 P0 DEK fallback regression test touches `lib/core/encryption/`. The 27-event GlitchTip fix is already on main.
4. **`SessionsApi` / `MessagesApi` dead code** — flagged as unused by notifiers; may be used by auth flow / debug screens. Verify in a follow-up; do not delete here.
5. **`MachinesNotifier` + `SessionGitStatusNotifier` merge** — low-priority; defer.
6. **Force-unwraps in `session_info_screen.dart`** — 14 sites found, but no GlitchTip cluster. Leave alone.
7. **CRDT logic in `SettingsNotifier`** — contained and tested; defer.
8. **`auth_service_test.dart` skipped tests** requiring native sodium — needs native test runner.
9. **ANR (foreground `nativePollOnce` + background `__sfvwrite`) GlitchTip cluster** (2 fatal) — requires native symbolicated stack analysis.
10. **TTS fallback noise regression test** — separate concern, opportunistic.
11. **`test/integration/jsonl_replay/`** test data generators — out of scope.
12. **Custom `OfflineDictationNotifier` in `zen_home.dart` legacy** — only the `SyncSubscriptionMixin` migration is in scope; the rest of the legacy `zen_home` deletes in a follow-up.

---

## How to Resume

1. Read this file and `docs/REFACTOR_PLAN.md` if present.
2. Start Phase 4b by reading `lib/core/services/_sync_data.dart`, `lib/core/services/_sync_sessions.dart`, `lib/core/services/_sync_operations_session.dart`, `lib/core/services/_sync_session_restore_split.dart`, `lib/core/services/_sync_data_machines.dart`, and `lib/core/services/_sync_health.dart`.
3. Follow the pattern established by `lib/core/sync/artifact_manager.dart` and `lib/core/sync/settings_manager.dart`:
   - Extract state and methods into a manager class in `lib/core/sync/`.
   - Use `InvalidateSync Function()` getters in the constructor to avoid initialization-order cycles.
   - Keep `Sync` methods as thin forwarders until Phase 5 deletes the facade.
   - Create repository wrappers in `lib/core/repositories/`.
   - Route `SessionsNotifier` and `MachinesNotifier` through the repositories.
4. Run `flutter analyze` frequently; run the spawning/lifecycle integration tests before declaring Phase 4b done.
5. Do **not** start Phase 5 until Phase 4b is green and merged.
