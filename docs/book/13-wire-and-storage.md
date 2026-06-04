# 13. Wire & Storage

The transport layer (HTTP + WebSocket + encryption) and the on-device persistence layer. This is the boundary between the app and the outside world.

## HTTP: Dio + NativeAdapter

`lib/core/api/api_client.dart`. The HTTP client is `ApiClient` (a thin wrapper around Dio). Key facts:

- **Base URL**: from `ServerConfig` (defaults to the production server, overridable in settings).
- **Timeouts**: connect 30s, receive 60s, send 30s.
- **Interceptors**:
  - Auth (adds `Authorization: Bearer <jwt>`)
  - Retry (`retry_interceptor.dart`) for transient failures
  - Logging (`http_request_logger.dart`) for the dev network inspector
  - Error normalization (turns Dio errors into `BaseApiException`)
- **Adapter**: `NativeAdapter` via `native_adapter_helper.dart` (Cronet on Android, cupertino_http on iOS). The web variant is `native_adapter_helper_web.dart`. The `AGP 9.x + cronet_http compileSdk workaround` (in memory) is needed for the CI build.

The retry interceptor retries on 5xx and network errors with backoff. It does **not** retry on 4xx (those are caller errors). The retry uses the same `localId` if applicable; the API clients pass it through.

### Per-domain API classes

The per-domain classes are in `lib/core/api/`:

- `sessions_api.dart` — sessions
- `messages_api.dart` — messages
- `kv_api.dart` — key-value (settings store on the server)
- `friends_api.dart` — friends
- `push_api.dart` — push tokens
- `services_api.dart` — services (e.g. TTS, dictation)
- `usage_api.dart` — usage stats
- `github_api.dart` — GitHub integration
- (artifacts API is a method on `Sync`; no separate class)

Each class accepts an optional `ApiClient? client` for test injection. The default is the singleton.

## Socket: see Chapter 7

The socket is in `lib/core/api/socket_io_client.dart`. See [Chapter 7](07-socket.md) for the connection lifecycle, the fast path, and the test override hooks.

## Wire parsers: `WireParsers`

`lib/core/utils/wire_parsers.dart`. The server sometimes returns numbers as numeric strings (or vice versa) depending on the version. `WireParsers` is a set of `WireParseX` functions that handle lenient type coercion.

```dart
// WireParsers API
int wireParseInt(dynamic value, {int? defaultValue});
double wireParseDouble(dynamic value, {double? defaultValue});
String? wireParseString(dynamic value);
DateTime? wireParseDateTime(dynamic value);
bool wireParseBool(dynamic value);
List<T> wireParseList<T>(dynamic value, T Function(dynamic) parse);
```

Use these in `fromJson` factories when the field type is non-string and the wire format is uncertain. The `Message` and `Session` models use them extensively.

The convention: **always** use `WireParsers` for non-string types. Don't write `value as int` — use `wireParseInt(value)`. The cost is a function call; the benefit is robustness.

## Encryption: AES-256-GCM + NaCl

The encryption layer is in `lib/core/encryption/`. Two systems:

- **AES-256-GCM** (`aes_gcm.dart`) — new data. Symmetric, authenticated, fast.
- **NaCl** (`crypto_box.dart`, `crypto_secret_box.dart`) — legacy. Asymmetric (box) and symmetric (secret box).

The `EncryptionManager` (`encryption_manager.dart`) chooses the right system based on the message metadata. New messages are AES-256-GCM; old messages may still be NaCl. The `MessageProcessor` (`message_processor.dart`) is the orchestrator.

### The isolates

CPU-bound encryption work runs in `Isolate.run`. The pattern (from the "Isolate unsendable Future" bug fix in `7b69d1b`, `84ff0c2`):

- **Do not** capture `this` in the isolate closure.
- Pass only sendable POD args.
- The helper functions are top-level functions in `_sync_isolate_helpers.dart`.

```dart
// Correct: top-level function, POD args
final result = await Isolate.run(() => _decryptInIsolate(key, ciphertext));

// Wrong: captures `this`
final result = await Isolate.run(() => decryptInInstance(ciphertext));
```

### The encryption cache

`encryption_cache.dart` is an LRU cache of decrypted plaintexts. Decryption is expensive; caching is a significant perf win. The cache is bounded (a few hundred entries) and is invalidated on session close.

## Storage

The app uses **MMKV** for almost everything local, **FlutterSecureStorage** for secrets, and a few specialized services for specific data.

### `MMKVStorage` (the base)

`lib/core/services/mmkv_storage.dart` (+ `mmkv_storage_native.dart`, `mmkv_storage_web.dart`). The wrapper around `flutter_mmkv`. The web variant uses `shared_preferences` under the hood (MMKV is native-only).

A `Storage` singleton (`storage_service.dart`) initializes all MMKV namespaces on startup:

```dart
await Storage().initialize();
```

The initialization also runs the SharedPreferences → MMKV migration (one-time). The migration is documented in `docs/MMKV_MIGRATION_IMPLEMENTATION.md`.

### The storage namespaces

MMKV is partitioned by namespace (separate "mmap" files for each). The namespaces:

- `default` — generic keys
- `server-config` — custom server URL (persists across logouts)
- `sessions-cache` — session list cache
- `messages-cache` — message cache (last 200 per session)
- `drafts` — chat input drafts
- `pinned-sessions` — pinned sessions
- `session-folders` — session folder organization
- `recent-commands` — recent command palette commands
- `outbox` — message outbox

Each namespace has its own `XxxStorage` class. The `draft_storage.dart` / `draft_service.dart` pair is an example: `draft_storage.dart` is the raw MMKV wrapper, `draft_service.dart` adds the higher-level API.

### `TokenStorage` and `APIKeyStorage`

`TokenStorage` (in `lib/core/services/auth_service.dart` and friends) stores the JWT and auth keys in **FlutterSecureStorage** (Keychain on iOS, EncryptedSharedPreferences on Android). It does **not** use MMKV.

`APIKeyStorage` is for per-profile API keys (e.g. Anthropic API keys for direct usage). Same backend.

### `ServerConfigStorage`

`lib/core/services/server_config_storage.dart` (+ native/web variants). The custom server URL. Stored in MMKV under the `server-config` namespace, but with a special property: **it persists across logouts**. When the user logs out and a new user logs in, the server URL is still there.

### `SessionsCacheStorage`

`lib/core/services/sessions_cache_storage.dart` (+ native/web variants). The cached session list. Used on cold start to show the session list instantly while the network fetch runs.

### The migration

The app migrated from `SharedPreferences` to MMKV. The migration runs once on first init. If you see old keys hanging around, it's because the migration is idempotent — old keys are deleted after the new ones are written. See `docs/MMKV_MIGRATION_IMPLEMENTATION.md`.

### What is **not** in MMKV

- JWT and auth keys — `FlutterSecureStorage`
- API keys — `FlutterSecureStorage`
- The encryption keys themselves — derived on the fly, not stored
- The `ServerConfig` URL — `MMKVStorage` (`server-config` namespace), but a special "persists across logouts" path

## The relationship to `Sync`

`Sync` reads from MMKV on `create()` / `restore()` and writes to MMKV through the storage services. The in-memory state is the source of truth at runtime; MMKV is the persistence layer.

The boundary is: `Sync` never touches MMKV directly. It goes through the storage services (`MessageCacheService`, `MessageOutbox`, `SessionsCacheStorage`, etc.). This is a hard rule for testability — you can override the storage service in tests.

## Performance notes

- **MMKV is fast.** Reads are O(1) mmap. Writes are async but cheap. The app uses MMKV for hot paths (message cache, outbox).
- **FlutterSecureStorage is slow.** Each read is a platform channel call. The app uses it only for cold-start reads (JWT, API keys) and infrequent writes (login, settings change).
- **Encryption is slow on the main thread.** That's why it's in `Isolate.run`. The pattern is mandatory.
- **The encryption cache helps a lot.** The first decrypt of a message is slow; subsequent reads are instant. The cache is LRU; the most-recently-decrypted messages are kept hot.

## Files to read next

- `lib/core/api/api_client.dart` — the HTTP client
- `lib/core/api/socket_io_client.dart` — the socket
- `lib/core/utils/wire_parsers.dart` — the parsers
- `lib/core/encryption/aes_gcm.dart` — the new encryption
- `lib/core/encryption/encryption_manager.dart` — the manager
- `lib/core/services/mmkv_storage.dart` — the storage
- `docs/AES_GCM_IMPLEMENTATION.md` — AES design
- `docs/LIBSODIUM_INTEGRATION.md` — NaCl design
- `docs/MMKV_MIGRATION_IMPLEMENTATION.md` — migration notes
- `docs/PROTOCOL.md` — the wire protocol

## Gotchas

- The `ApiClient` is constructed once. Don't construct a new one in a hot path.
- The `NativeAdapter` is platform-specific. The web variant is a stub that falls back to the default Dio adapter.
- The retry interceptor does **not** retry on 4xx. If you're seeing infinite retries, check that the error is actually 5xx or a network error.
- `WireParsers` is **the** way to parse non-string types. Don't use `as int` or `as double`.
- The encryption cache is LRU-bounded. If you see cold decrypts for messages you've seen before, the cache may have evicted them.
- `Isolate.run` closures **must not** capture `this`. This is a hard rule. Top-level functions only.
- MMKV is mmap-backed. The first access is slow; subsequent accesses are fast. The app does not "warm up" MMKV explicitly.
- `FlutterSecureStorage` is slow. Don't read from it in a hot path.
- The `ServerConfig` URL persists across logouts. This is by design (users want to point the app at a self-hosted server even across accounts).
- The `SessionsCacheStorage` is loaded on cold start to show the session list instantly. The network fetch overlays it.
- The `MessageCacheService` is debounced 500ms. The outbox is per-user, not per-device.
- The `Storage` singleton's `initialize()` is called once in `main.dart`. Don't call it elsewhere.
