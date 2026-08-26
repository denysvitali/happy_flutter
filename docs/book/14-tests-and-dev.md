# 14. Tests & Dev Loop

How the app is tested, how to run it locally, and how CI works. The test pyramid is unit → widget → integration, with a heavy emphasis on the messaging contract tests.

## The test pyramid

```
                   ┌─────────────────┐
                   │  E2E (24 files) │  test/integration/
                   │  + replays      │  test/integration/jsonl_replay/
                   └────────┬────────┘
                            │
                ┌───────────┴───────────┐
                │  Widget tests         │  test/widgets/, test/features/
                │  + golden tests       │  test/golden/
                └───────────┬───────────┘
                            │
       ┌────────────────────┴────────────────────┐
       │  Unit tests                            │  test/utils/, test/services/,
       │  + FSM contract tests                  │  test/fsm/, test/core/
       └─────────────────────────────────────────┘
```

## The directories

- `test/integration/` — **24 e2e files.** The load-bearing tests for the messaging invariant. Use `mock_sync_server.dart` and `fake_session_encryption.dart` helpers. Replay fixtures in `test/integration/jsonl_replay/`.
- `test/fsm/` — FSM contract tests. `message_state_machine_contract_test.dart` pins the legal transitions.
- `test/services/` — unit tests for individual services (sync, outbox, cache, etc.).
- `test/utils/` — unit tests for utilities (invalidate_sync, backoff, etc.).
- `test/core/` — unit tests for core (providers, models, etc.).
- `test/features/` — feature-specific unit/widget tests.
- `test/widgets/` — widget tests.
- `test/golden/` — golden screenshot tests. **Update after any UI change.**
- `test/helpers/` — `test_helpers.dart` with `createTestSync()`, `mockResponse<T>()`, etc.

## The e2e helpers

### `mock_sync_server.dart`

A in-memory mock of the Happy server. It speaks the wire protocol. Tests start it, configure it to return specific responses, and exercise the app against it.

```dart
final server = MockSyncServer();
server.onPost('/v1/sessions/.../messages', (req) => {'ok': true});
await sync.create();  // points at the mock
```

The mock supports session spawning, message acks, friend requests, artifact uploads, and the other endpoints the app uses.

### `fake_session_encryption.dart`

A no-op encryption layer. Tests use it to skip the real encryption and focus on the protocol.

```dart
TestWidgetsFlutterBinding.ensureInitialized();
FakeSessionEncryption.install();
```

After `install()`, `EncryptionManager` returns the fake; tests don't need to deal with real keys.

### `jsonl_replay/`

Recorded wire protocol traces. The test loads a trace, replays it against the mock, and asserts the resulting in-memory state. Used for regression tests of specific real-world scenarios.

## The test helpers (`test/helpers/test_helpers.dart`)

- `createTestSync()` — constructs a `Sync` with all `InvalidateSync` fields pre-wired to no-ops. Use this in **every** test that touches `Sync`.
- `mockResponse<T>(...)` — builds a Dio `Response<T>` with a `RequestOptions(path: '')` (the empty `path` is required by the Dio matcher).

```dart
// In a test
sync = createTestSync();
final response = mockResponse<List<Session>>(
  data: [Session(id: 'abc', ...)],
);
```

## The test config

`test/flutter_test_config.dart` runs before every test file. It:

- Calls `TestWidgetsFlutterBinding.ensureInitialized()`
- Disables Google Fonts runtime fetching
- Loads Roboto Mono for golden screenshots

You don't need to call these in your test files. They're already done.

## Provider tests

The pattern:

```dart
late ProviderContainer container;

setUp(() {
  container = ProviderContainer(overrides: [
    sessionsNotifierProvider.overrideWith(() => _FakeSessionsNotifier()),
  ]);
});

tearDown(() {
  container.dispose();
});

test('loads from sync', () async {
  await container.read(sessionsNotifierProvider.notifier).refreshFromSync();
  expect(container.read(sessionsNotifierProvider), isNotEmpty);
});
```

The override is essential. The real notifier would try to read from `Sync`, which is the singleton — bad in tests. The fake notifier stubs `build()`, `loadFromSync()`, and `refreshFromSync()`.

## MMKV stubbing in widget tests

When a widget indirectly touches MMKV (which is most of them), register a `_FakeMMKVPlatform` on `MMKVPluginPlatform.instance` **before** widget creation:

```dart
MMKVPluginPlatform.instance = _FakeMMKVPlatform();
```

Otherwise the widget test will throw when it tries to read or write MMKV.

## Sync tests

`Sync()` is a singleton. **Tests must reset its state.** Use `createTestSync()`:

```dart
setUp(() {
  sync = createTestSync();
  // ... wire up mocks, configure InvalidateSyncs
});
```

The default `Sync()` returns a dirty global. If you call it without resetting, the test sees state from a previous test.

## Mock HTTP responses

Always include `requestOptions: RequestOptions(path: '')`:

```dart
when(dio.post(any)).thenAnswer((_) async => Response(
  data: {'ok': true},
  requestOptions: RequestOptions(path: ''),
  statusCode: 200,
));
```

Use `mockResponse<T>(...)` from `test_helpers.dart` to avoid the boilerplate.

## Golden screenshots

The golden test is `test/golden/golden_test.dart`. It renders the showcase screens and compares to PNGs in `test/golden/goldens/`. The PNGs are **showcase images** used in the README and to track visual regressions.

**Viewport:** phone, set via `tester.view.physicalSize = Size(390*2, 844*2)` with `devicePixelRatio = 2.0`.

**When to update goldens:** after **any** UI change that affects visual output. Run:

```bash
mise exec -- flutter test test/golden/golden_test.dart --update-goldens
```

Then commit the updated PNGs. Do not leave stale goldens — they will cause false test failures for other contributors.

**Git LFS:** the PNGs are tracked via Git LFS (see `.gitattributes`). Contributors must have `git-lfs` installed (`git lfs install`).

## Dev loop: mise

The app uses [mise](https://mise.jdx.dev/) to pin Flutter, Dart, Java, and
Make.
**All Flutter commands go through mise:**

```bash
# Install the pinned toolchain
mise install

# Install dependencies
mise exec -- flutter pub get

# Analyze
mise exec -- flutter analyze

# Run all tests
mise exec -- flutter test

# Run a specific test
mise exec -- flutter test test/services/sync_service_test.dart

# Update goldens
mise exec -- flutter test test/golden/golden_test.dart --update-goldens

# Code generation (after changing ApiClient public API)
mise exec -- flutter pub run build_runner build

# Build APK
mise exec -- flutter build apk --debug --flavor development
mise exec -- flutter build apk --release --flavor production

# Run on device/emulator
mise exec -- flutter run
```

`.mise.toml` pins the toolchain. Don't run `flutter` directly; use
`mise exec --` or enable direnv so `use mise` puts the pinned tools on PATH.

### Build flavors (Android only)

- `development` — appId `.dev` suffix
- `preview` — appId `.preview` suffix
- `production` — base appId

iOS has no flavor separation.

## CI

The CI pipeline runs on GitHub Actions. The jobs (from `docs/DEV_OPS_CI_CD.md`):

1. **analyze** — `flutter analyze --no-fatal-infos --no-fatal-warnings`
2. **test + coverage** — `flutter test --coverage` with Codecov upload
3. **golden** — golden tests (read-only; no `--update-goldens`)
4. **build-debug** — debug APK
5. **build-release** — release APK
6. **build-web** — web build
7. **deploy-web** — deploy web build (on `v*` tags only)

The `v*` tag pipeline attaches the APK to the GitHub release. The Linux x64 binary attachment was added in `2d19860f`. Dart obfuscation was dropped 2026-08-26 — the app is open source.

### The CI blockers

`flutter analyze` is run with `--no-fatal-infos --no-fatal-warnings`. Only **errors** block the build. The errors that block are:

- `missing_required_param`
- `missing_return`
- `must_be_immutable`

(Other analyzer diagnostics are warnings/infos and don't block.)

## The dependency overrides

`pubspec.yaml` has `dependency_overrides` for compatibility with Flutter 3.38.7:

- `shared_preferences_android: 2.4.20` (2.4.18 and 2.4.21 lack `SharedPreferencesPlugin`)
- `sodium_libs: 3.4.6+3`

The AGP 9.x + cronet_http compileSdk workaround (in memory) is a CI sed patch; the underlying issue is that `sentry_flutter` pins `jni 0.14.2`, which blocks `cronet_http` upgrade. If you touch Android build files, be aware of this.

## GlitchTip for production issues

When asked about app crashes, production errors, regressions, or latest issues, use GlitchTip:

- **Scope:** organization `default`, project `happy_flutter`.
- Active issues:

  ```text
  mcp__glitchtip__.list_issues(
    organization_slug: "default",
    project_slug: "happy_flutter",
    query: "is:unresolved",
    sort: "-last_seen",
    limit: 15
  )
  ```
- For actionable issues, call `mcp__glitchtip__.get_latest_event(issue_id)` and inspect tags, release, environment, device, breadcrumbs, and stack data.
- Don't resolve or ignore GlitchTip issues unless the user asks for that action.

## Files to read next

- `test/helpers/test_helpers.dart` — the helpers
- `test/integration/mock_sync_server.dart` — the mock
- `test/integration/fake_session_encryption.dart` — the fake encryption
- `test/fsm/message_state_machine_contract_test.dart` — the contract
- `test/golden/golden_test.dart` — the goldens
- `docs/DEV_OPS_CI_CD.md` — CI reference
- `ROADMAP.md` — production issues and priorities

## Gotchas

- `Sync()` is a singleton. Tests must reset it. Use `createTestSync()`.
- The `mockResponse<T>()` helper requires `RequestOptions(path: '')`. Don't forget it.
- Widget tests that touch MMKV need a `_FakeMMKVPlatform` registration. Don't forget it.
- Golden tests are read-only in CI. Locally, update with `--update-goldens` and commit the new PNGs.
- The dev loop goes through `mise exec --`. Don't run `flutter` directly.
- The CI blocks on errors only. Warnings/infos don't block.
- The build flavors are Android-only. iOS has no flavor separation.
- Don't try to debug a release build locally — use the `development` flavor.
- GlitchTip is the production error tracker. Sentry (the SDK) is wired up; GlitchTip is the server.
- The `createTestSync()` helper pre-wires all `InvalidateSync` fields to no-ops. If you need real invalidation in a test, override them per-field.
- The e2e tests use `mock_sync_server.dart`. If a test fails after a wire-protocol change, the mock may be out of date.
- The `jsonl_replay/` fixtures are recorded real-world traces. Update them when the wire protocol changes.
- The `flutter analyze` errors that block are the three listed above. Other diagnostics don't block. Don't waste time fixing non-blocking warnings before merging.
