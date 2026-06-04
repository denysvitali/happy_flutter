# 2. Directory Tour

A walk through every `lib/` subdirectory. One paragraph per directory, with the load-bearing files called out.

## Top level

- **`lib/main.dart`** — entry point. Initializes the three globals, wires the theme, mounts the router. Anything global lives here.
- **`lib/l10n_generated/`** — generated localization code. Touch only via `flutter gen-l10n`. Do not hand-edit.

## `lib/core/` — the cross-cutting infrastructure

This is where ~80% of the code lives. The split is "what is reusable across features" vs. "what is a feature."

### `lib/core/actors/`

The `SessionActor` (single file). Encapsulates per-session work that doesn't fit cleanly in a notifier: queuing operations, sequencing, retries. Read this if you're adding a session-scoped side-effect.

### `lib/core/api/`

The HTTP + Socket.IO clients. Manual, no codegen.

- `api_client.dart` — `ApiClient` (Dio + NativeAdapter). Timeouts, interceptors, base URL.
- `native_adapter_helper.dart` / `native_adapter_helper_web.dart` — Cronet on Android, cupertino_http on iOS, with a web stub.
- `retry_interceptor.dart` — Dio interceptor for transient failures.
- `socket_io_client.dart` — the Socket.IO client (`/v1/updates`, websocket only, 2–10s reconnect delays).
- `http_cache.dart` — response cache.
- `http_request_logger.dart` — request/response logging for the dev network inspector.
- Per-domain APIs: `sessions_api.dart`, `messages_api.dart`, `kv_api.dart`, `artifacts_api`, `friends_api.dart`, `push_api.dart`, `services_api.dart`, `usage_api.dart`, `github_api.dart`.

These per-domain classes accept an optional `ApiClient?` so tests can inject a mock. `Sync` constructs them directly today.

### `lib/core/components/`

**Higher-level widgets.** Cross-feature. Things you put together for a screen.

- `app_card.dart`, `app_empty_state.dart`, `app_loading_indicator.dart`, `app_error_state.dart`, `app_section_header.dart`, `app_badge.dart`, `app_tappable.dart`, `app_status_dot.dart` — the App* primitive set.
- `avatar.dart` — user/machine avatars.
- `pressable_card.dart` — pressable surface.
- `diff_view.dart` / `diff_view_widget.dart` — code diff rendering.
- `shimmer_view.dart` — loading shimmer.
- `sidebar/` — sidebar shell (tablet/desktop; P3 roadmap item).
- `settings/` — settings-specific layouts.
- `tablet/` — tablet-specific layouts.
- `tool_view_buttons.dart` — buttons used inside tool views.
- `voice_assistant_status_bar.dart`, `transcription_startup_status_bar.dart` — top bars.
- `exit_code_badge.dart` — terminal exit-code chips.

### `lib/core/crdt/`

CRDT primitives for conflict-free merging of settings/state across devices.

- `lww_register.dart` — Last-Writer-Wins register.
- `settings_crdt.dart` — settings-specific CRDT.
- `crdt_stubs.dart` — no-op stubs for tests.

CRDT is used selectively (settings, sidechain grouping). It is *not* the main merging strategy — that is `localId` + `serverId` resolution in `_sync_messaging_merge.dart`.

### `lib/core/dialogs/`

A single `confirm_dialog.dart`. The rest of the dialogs are inline in their feature.

### `lib/core/encryption/`

The encryption layer. New and legacy.

- `aes_gcm.dart` — AES-256-GCM (new data).
- `crypto_box.dart`, `crypto_secret_box.dart` — NaCl primitives (legacy).
- `derive_key.dart` — key derivation.
- `encryption.dart`, `encryption_manager.dart`, `encryptor.dart` — the manager.
- `encryption_cache.dart` — decrypt cache (LRU).
- `artifact_encryption.dart`, `session_encryption.dart`, `machine_encryption.dart` — per-scope wrappers.
- `message_processor.dart` — the encryption processor used by the message pipeline.
- `processors/` — pluggable message processors.
- `sodium_loader.dart` + `sodium_loader_native.dart` + `sodium_loader_web.dart` — FFI bootstrap, platform split.
- `sodium_singleton.dart` — the singleton.
- `base64.dart`, `hex.dart`, `text.dart`, `hmac_sha512.dart` — small helpers.

`docs/AES_GCM_IMPLEMENTATION.md` and `docs/LIBSODIUM_INTEGRATION.md` are the reference notes.

### `lib/core/event_log/`

The event-log projection. The messaging FSM in `fsm/message_state_machine.dart` reads from this; the live state is *derived* from the log. Files: `event_log.dart`, `event_log_flag.dart`, `message_projection.dart`.

If you find yourself wanting to store "the current message state" as a field on a model, you probably want a `MessageStateMachine.apply(event)` projection instead. The log is the truth.

### `lib/core/fsm/`

The state machines.

- `message_state.dart` (in `types/`) and `message_state.g.dart` (generated) — the typed states.
- `message_state_machine.dart` — the transition function. **This is where legal transitions live.** Test coverage is in `test/fsm/`.

When you change a state transition, update the FSM *and* add a test in `test/fsm/message_state_machine_contract_test.dart`.

### `lib/core/i18n/`

`app_localizations.dart` — helpers around Flutter's `flutter_localizations`. ARB files live in `l10n/`.

### `lib/core/ml/`

The on-device ML layer.

- `gemma_model_config.dart` — Gemma model config.
- `ml_platform_io.dart` / `ml_platform_native.dart` / `ml_platform_stub.dart` — platform split.
- `session_ranker.dart` — used by the session list to rank candidates (offline heuristic).

If you're touching this, you probably also want to read `lib/core/services/offline_dictation_service.dart` (which uses it).

### `lib/core/models/`

The data models. **Hand-written `fromJson`/`toJson`/`copyWith`.** No `json_serializable`/`freezed` for the core models — except that the `*.freezed.dart` and `*.g.dart` files you see are for a subset (e.g. `auth.dart`, `artifact.dart`, `claude_usage_limits.dart`, `kv.dart`, `local_settings.dart`, `machine.dart`, `message.dart`, `purchases.dart`, `session.dart`, `settings.dart`, `usage.dart`, `api_update.dart`). The hand-written ones are: `auth_models.dart`, `built_in_profiles.dart`, `codex_usage_summary.dart`, `friend_request.dart`, `profile.dart`, `settings_update.dart`, `todo.dart`.

> **What this is NOT:** Despite the `*.freezed.dart` files, you cannot use `copyWith` on these models like a freezed `data class`. The hand-written `copyWith` is custom (look for the `_shared.dart` `unset` sentinel pattern in some notifiers — that's a *notifier* convention, not a model convention).

Key files:
- `session.dart` — `Session` model. `Session.presence` is *always* a `String` (`'online'`/`'offline'`), never `null`. Absence on the wire maps to `'offline'`.
- `message.dart` — the message model.
- `api_update.dart` — the wire envelope.
- `machine.dart`, `artifact.dart`, `auth.dart`, `friend_request.dart`, `profile.dart`, `settings.dart`, `kv.dart`, `local_settings.dart`, `purchases.dart`, `todo.dart`, `usage.dart`, `claude_usage_limits.dart`, `codex_usage_summary.dart`, `settings_update.dart`, `auth_models.dart`, `built_in_profiles.dart`.

Timestamps are integers (milliseconds since epoch), not `DateTime`. This is deliberate — it round-trips through JSON cleanly.

### `lib/core/native_chat_list/`

A single file. The platform-view-backed chat list (used in performance-sensitive screens). Don't confuse with `lib/features/chat/chat_screen.dart` — this is the *list primitive*, not the screen.

### `lib/core/providers/`

The Riverpod layer. 19 files, all small.

- `app_providers.dart` — barrel. Re-exports the common providers.
- `auth_state_notifier.dart` — the coordinator. On auth change, calls `loadFromSync`/`clear` on every other notifier.
- `sessions_notifier.dart`, `machines_notifier.dart`, `settings_notifier.dart`, `profile_notifier.dart`, `artifacts_notifier.dart`, `friends_notifier.dart`, `current_session_notifier.dart`, `session_git_status_notifier.dart`, `todo_state_notifier.dart`, `feed_notifier.dart` — the per-domain notifiers.
- `chat_action_notifier.dart` — **a `Notifier<void>`**. Pure action dispatcher. The way `chat_screen.dart` avoids calling `sync.` directly.
- `logger_provider.dart` — `LoggerState` (debounced 200ms) + `loggerServiceProvider` (plain `Provider`, *not* `NotifierProvider`).
- `connection_notifier.dart`, `network_notifier.dart`, `sync_state_notifier.dart` — connection/network state.
- `derived_view_providers.dart` — derived views (e.g. sorted sessions).
- `offline_dictation_notifier.dart`, `sidebar_notifier.dart` — feature-specific.
- `_shared.dart` — the `unset` sentinel helper for notifier `copyWith`.

See [Chapter 10](10-riverpod.md) for the patterns.

### `lib/core/rpc/`

RPC layer. `rpc_types.dart` is referenced from `sync_service.dart`. There may be a per-feature RPC client; the in-app RPC used for sending messages is `_sync_messaging_rpc.dart` (a *part* of `Sync`, not a file in this directory).

### `lib/core/routing/`

`app_router.dart` — GoRouter setup. **~64 flat `GoRoute` entries.** Three custom page transitions: `_fadePage` (tab destinations), `_slideUpPage` (modal/creation), `_slidePage` (detail with iOS-style swipe-back). See [Chapter 12](12-routing-theme-widgets.md).

### `lib/core/services/`

The big one. ~60 files. **The single most important directory in the codebase.**

The directory mixes:

- **`Sync` and its 19 part files** (`sync_service.dart` + `_sync_*.dart`) — covered in [Part II](04-sync-anatomy.md).
- **Top-level helper services** that `Sync` calls or that screens use directly:
  - Storage: `mmkv_storage.dart` (+ `mmkv_storage_native.dart`/`_web.dart`), `server_config.dart` (+ native/web), `sessions_cache_storage.dart` (+ native/web), `cached_storage.dart`, `draft_storage.dart`, `draft_service.dart`, `pinned_sessions_storage.dart`, `session_folders_storage.dart`, `recent_commands_storage.dart`, `storage_service.dart`.
  - Auth + encryption: `auth_service.dart`, `_auth_approval_flow.dart`, `encryption_service.dart`, `encryption_keys.dart`, `crypto_worker.dart`, `token_refresh_manager.dart`, `certificate_provider.dart`.
  - Networking: `network_monitor_service.dart`, `http_request_logger.dart`.
  - Logging + Sentry: `logger_service.dart`, `dart_sentry_transport.dart`, `remote_logger.dart`, `opentelemetry_service.dart`, `sentry_tracing_service.dart`.
  - Push: `push_service.dart`, `notification_service.dart`, `live_activity_service.dart`.
  - TTS / dictation: `tts_service.dart`, `offline_tts_service.dart` (+ native/stub), `offline_dictation_service.dart` (+ native/stub), `voice_assistant_status_bar` is in `components/`.
  - Messaging helpers: `message_cache_service.dart`, `message_outbox.dart` (+ `message_outbox_sqlite.dart`), `message_cursor_manager.dart`, `message_processing_service.dart`, `inline_message_processor.dart`, `sidechain_grouper.dart`, `tool_result_processor.dart`, `session_activity_coordinator.dart`, `windowed_message_store.dart`.
  - Lifecycle: `app_lifecycle_service.dart`, `app_visibility_coordinator.dart`, `frame_metrics_service.dart`, `performance_context_service.dart`, `power_diagnostics_service.dart`.
  - Other: `changelog_service.dart`, `auto_archive_service.dart`, `smart_features_service.dart`, `video_call_service.dart`, `canary_mode.dart` (runtime invariant asserts — see `sync_service.dart` imports).

When in doubt about which `services/` file holds what, `grep -l "class .*Service" lib/core/services/` will list them.

### `lib/core/theme/`

Design tokens. The single source of truth for spacing, radii, fonts, colors, durations, touch targets, breakpoints. See [Chapter 12](12-routing-theme-widgets.md).

- `app_tokens.dart` — `AppSpacing`, `AppRadius`, `AppFontSize`, `AppDuration`, `AppTouchTarget`, `AppBreakpoint`, `AppScreenPadding`.
- `app_colors.dart` — palette.
- `app_color_scheme.dart` — light/dark `ColorScheme`.
- `app_typography.dart` — text styles.
- `file_type_colors.dart` — file-extension → color.

### `lib/core/types/`

Compile-time identity types. Read this once and never be confused again.

- `identity_types.dart` — `LocalId`, `ServerMessageId`, `SessionId`. Compile-time typedefs/classes. The "one canonical `localId`" anchor.
- `message_state.dart` — the typed `MessageState` and `MessageSendState` hierarchies (the FSM's input/output).

The comment at the top of `sync_service.dart` is worth reading in full:

> Compile-time identity types — see ROADMAP P0 "one canonical localId". Imported once at the part-file root so every `_sync_messaging*` part can reference [LocalId], [ServerMessageId], [SessionId], and the sealed [MessageState] hierarchy without an explicit import.

### `lib/core/ui/`

**Lower-level widgets.** Different from `components/`.

- `avatars/` — small avatar primitives.
- `diff/` — diff primitives (used by `components/diff_view.dart`).
- `shimmer/` — shimmer primitives.
- `status_bar/` — iOS/Android status bar handling.
- `tab_bar/` — a custom `TabBar`. **You must `hide TabBar` from `material.dart` to import it** (it's a name collision).

### `lib/core/utils/`

28 utility files. Some are core, some are sugar.

- `invalidate_sync.dart` — the debounced-fetch primitive. [Chapter 6](06-invalidate-sync.md).
- `sync_subscription_mixin.dart` — the mixin that replaces raw `sync.onDataChanged.listen(...)` calls in screens. [Chapter 11](11-screen-subscription.md).
- `safe_pop.dart` — `safePop(context)` helper. Used to fix a class of back-button crashes.
- `wire_parsers.dart` — `WireParsers` — lenient type coercion. [Chapter 13](13-wire-and-storage.md).
- `optimistic_mutation.dart` — an `OptimisticMutation<T>` primitive (planned in ROADMAP; not yet a primary pattern).
- `async_lock.dart`, `backoff.dart`, `lru_cache.dart`, `package_info_cache.dart`, `syntax_cache.dart` — small primitives.
- `ansi_parser.dart`, `shell_script_parser.dart`, `tool_error_parser.dart` — text parsers.
- `message_utils.dart`, `path_utils.dart`, `permission_description.dart`, `session_status.dart`, `session_utils.dart`, `command_utils.dart` — domain utilities.
- `clipboard_utils.dart`, `datetime_extensions.dart`, `device_utils.dart`, `json_decoders.dart`, `parse_token.dart`, `theme_helper.dart`, `utils.dart`, `version_utils.dart`, `voice_languages.dart`, `backup_key_utils.dart` — small helpers.

### `lib/core/widgets/`

Top-level app widgets.

- `auth_gate.dart` — the auth gate. **Every route wraps its child in `AuthGate`.**
- `error_boundary.dart` — error boundary widget (Sentry chaining).
- `offline_banner.dart` — offline state banner.
- `sync_progress_bar.dart` — initial-sync progress bar.

### `lib/core/wire/`

`message_envelope.dart` — the structural envelope of a server message. Different from the *semantic* parsing in `_sync_messaging_parse*.dart`.

## `lib/features/` — the user-facing features

13 feature directories. Each follows the same pattern: `_screen.dart` + `widgets/` + optional `models/`, `helpers/`, `screens/`.

- **`auth/`** — QR auth, device linking, account restore, backup key.
- **`chat/`** — chat screen, input, markdown, tool views, autocomplete, message widgets. **The biggest feature.** Files: `chat_screen.dart`, `chat_input.dart`, `message_widget.dart`, `agent_conversation_screen.dart`, `message_detail_screen.dart`, `session_files_screen.dart`, `session_file_viewer_screen.dart`, `session_info_screen.dart`, `session_recent_screen.dart`, `code_block_widget.dart`, `syntax_highlighter.dart`, `syntax_tokenizer.dart`, `chat_tts_gate.dart`, `_chat_screen_actions.dart`, `_chat_screen_builders.dart`. Subdirs: `autocomplete/`, `helpers/`, `markdown/`, `tools/`, `widgets/`. `chat_screen.dart` is the documented exception to the standard subscription template.
- **`sessions/`** — session list, new session, machine/path/profile pickers, session dismissible.
- **`settings/`** — 16 settings screens (account, claude limits, codex usage, developer, features, link device, linked devices, machines, offline voices, profile editor, profile setup catalog, profile wizard, profiles, restore account, server, settings main, settings search, theme, usage, voice, voice language). Subdirs: `helpers/`, `screens/`, `widgets/`.
- **`inbox/`** — friends, friend search, notifications. Subdirs: `models/`, `widgets/`.
- **`artifacts/`** — artifact list, detail, edit, create.
- **`machine/`** — machine detail.
- **`sftp/`** — SFTP (own models/providers/screens).
- **`terminal/`** — terminal connect and screen.
- **`user/`** — user profile.
- **`zen/`** — zen home, new, view, priority (todo/zen mode).
- **`command_palette/`** — modal command search.
- **`dev/`** — dev logs, encryption debug, network inspector, notification test, session debug.
- **`changelog/`** — in-app changelog viewer.

## Files to read next

- Pick one feature directory and read its `_screen.dart` end-to-end. `lib/features/zen/` is the simplest. `lib/features/chat/chat_screen.dart` is the most complex.
- The providers barrel `lib/core/providers/app_providers.dart`.

## Gotchas

- `lib/core/services/` is huge and *unevenly split* — `Sync`'s part files live here, but so do 50+ top-level helper services. Grep for `class .*Service` or `class Sync` to disambiguate.
- The names `ui/` and `components/` are confusing. `ui/` is lower-level, `components/` is higher-level. When in doubt, check the imports in a feature screen to see which it uses.
- `lib/core/ml/` is small but platform-split. The split is by Dart's `defaultTargetPlatform`, not by directory. The `*_native.dart` and `*_stub.dart` files are conditionally exported.
- `lib/core/types/` looks like it might be just type aliases, but `message_state.dart` is the *sealed* `MessageState` hierarchy — it's part of the FSM contract.
