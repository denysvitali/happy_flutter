## Testing

**Unit, widget, and integration tests.** Integration tests in `test/integration/` cover session spawning, message deduplication, routing, pagination, cold starts, reconnection, and concurrent sends (29 files, 22 of them `*_e2e_test.dart`). They use `mock_sync_server.dart` and `fake_session_encryption.dart` helpers, plus replay fixtures under `test/integration/jsonl_replay/`.

**Global test config:** `test/flutter_test_config.dart` runs before every test file — calls `TestWidgetsFlutterBinding.ensureInitialized()`, loads the app's Inter font, and registers the MMKV test fake.

**Provider tests:** Use `ProviderContainer` directly. Always `container.dispose()` in `tearDown`.

**Storage overrides:** `SettingsNotifier.updateSetting` touches MMKV. Use overrides in tests:

```dart
ProviderContainer(overrides: [
  settingsNotifierProvider.overrideWith(() => _StorageFreeSettingsNotifier()),
])
```

**MMKV stubbing in widget tests:** When a widget indirectly touches MMKV, register a `_FakeMMKVPlatform` on `MMKVPluginPlatform.instance` before widget creation.

**Sync tests:** `Sync()` returns the singleton — set all InvalidateSync fields before calling `handleUpdate`. Use `createTestSync()` from `test/helpers/test_helpers.dart`.

**Mock HTTP responses:** Always include `requestOptions: RequestOptions(path: '')`. Use `mockResponse<T>()` helper from `test/helpers/test_helpers.dart`.

**API tests:** Use `mockito` with generated `.mocks.dart` files adjacent to each test file.

**Widget tests:** Wrap in `ProviderScope(overrides: [...])` inside `MaterialApp`. Stub notifiers override `build()`, `loadFromSync()`, and `refreshFromSync()`.

**Library identity:** Import app code through `package:happy_flutter/...` in
tests. Mixing that with relative `../../../lib/...` imports can load the same
model under two library identities and fail compilation with incompatible
types bearing the same name.

**Finder gotcha (rediscovered twice — broke tests both times):** `find.text(x, findRichText: true)` is an EXACT match. A header rendering title+subtitle in one RichText (e.g. `'Apply Changes  new_file.dart'`) won't match `'Apply Changes'` — use `find.textContaining(x, findRichText: true)`.

When inspecting `SelectableText` properties, find the widget by type and
`data`. `find.text` can match its inner `EditableText`, so casting that finder
result to `SelectableText` fails.

**Test helpers** in `test/helpers/test_helpers.dart`: `createTestSync()`, `mockResponse<T>()`.

### Benchmarks

`benchmark/` holds mocked-backend benchmarks run by the dedicated
**Mocked-backend benchmarks** CI job on every push (never locally — same
RAM rule as tests). The job builds the Rust core before measuring native AES
encryption and the terminal preview path, and checks Rust copy stripping.
Scenarios:
session-collection compute, message-pipeline
stages, raw AES-256-GCM crypto, and the two production ingress routes
(socket inline ingest, REST first-load tail fetch) over the integration
suite's `MockSyncServer`. Messaging numbers use a plaintext-passthrough
encryptor so they isolate pipeline cost; real crypto lives in the crypto
group. Results render into the job summary (markdown + CSV artifact
`benchmark-results-*`) via `.github/scripts/bench_summary.py`. Numbers are
JIT-mode relative indicators, not production AOT latencies — compare runs,
don't quote absolutes.
