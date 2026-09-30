## Common Commands

```bash
# Dependencies
mise exec -- flutter pub get

# Analysis (errors block CI; warnings/infos do not)
mise exec -- flutter analyze

# Testing (run in CI only — never locally)
mise exec -- flutter test
mise exec -- flutter test test/services/sync_service_test.dart

# Code generation (after changing freezed/json_serializable models or ApiClient public API)
mise exec -- flutter pub run build_runner build --delete-conflicting-outputs

# l10n (English-only ARB in l10n/app_en.arb → lib/l10n_generated/); CI regenerates and diffs
mise exec -- flutter gen-l10n

# Message FSM: spec/message.fsm.yaml → lib/core/fsm/message_state.g.dart (checked in;
# hand-rolled generator, not build_runner)
mise exec -- dart run tools/fsm_codegen.dart

# Rust hot-path core (rust/happy_core; optional — app falls back to Dart when absent)
scripts/build_rust.sh android|linux

# Build APK (flavors: development, preview, production)
mise exec -- flutter build apk --debug --flavor development
mise exec -- flutter build apk --release --flavor production

# Run on device/emulator
mise exec -- flutter run
```

**Generated-code drift is a CI failure.** CI regenerates `*.g.dart`,
`*.freezed.dart`, `*.mocks.dart`, `lib/l10n_generated/**`,
`lib/core/native/generated/**` and `rust/happy_core/src/frb_generated.rs`, then
runs `git diff --exit-code`. There is no `flutter_rust_bridge.yaml`: the exact
`flutter_rust_bridge_codegen generate …` flags (pinned to 2.13.0, followed by
`dart fix --apply` + `dart format` on the output) live in the "Regenerate FRB
native bindings" step of `.github/workflows/ci.yml` — copy them from there after
changing `rust/happy_core/src/api`. Regenerating bindings without rebuilding the
`.so` leaves native tests silently no-op'ing on the Dart fallback.

**Other tooling:** `tool/e2e_confidence.sh` runs the cross-repo contract suite
against a sibling `happy-cli-go` checkout (`HAPPY_CLI_GO_PATH`, default
`../happy-cli-go`). `test_chaos/run_chaos.sh` drives a chaos proxy + Maestro on
an emulator (never in CI). `spec/messaging.tla` / `messaging.cfg` model the canonical-message
identity invariants; `proto/messaging.proto` is a schema-first design draft — the
live wire path is still JSON over Socket.IO/REST.

**Build Flavors (Android only — iOS has no flavor separation):**
- `development` — appId `.dev` suffix
- `preview` — appId `.preview` suffix
- `production` — base appId

