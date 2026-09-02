# DevOps / CI-CD

**Updated:** 2026-08-11

## Main workflow

`.github/workflows/ci.yml` defines the `Happy Flutter CI/CD` workflow. It runs
analysis, tests, release builds, and web deployment in parallel. The signed APK
publishes directly from its build job; quality results remain visible without
suppressing the per-commit Android release.

| Job | Purpose |
|-----|---------|
| Analyze Code | Strict Flutter analysis with dependency resolution skipped |
| Verify Generated Code | Reject generated Dart and localization drift |
| Build iOS | Compile an unsigned release-mode iOS app |
| Test | 10 main / 15 other duration-balanced non-golden test shards |
| Upload Coverage | Merge shard coverage and upload it to Codecov |
| Golden Screenshots | Verify PR goldens or generate requested replacements |
| Quality Gate | Combine analyze, codegen, iOS, test, and golden results |
| Build Debug APK | Build non-main and manually requested debug artifacts |
| Build Release APK | Build and immediately publish the signed production APK |
| Build Linux x64 + arm64 | Build both Linux desktop bundles on native x64 and ARM64 runners |
| Attach Linux | Add both Linux archives to the existing GitHub Release |
| Build/Deploy Web | Build the web app and deploy GitHub Pages |

## Release invariant

Every push to `main`, including documentation-only pushes, starts a release.
The APK and Linux jobs start immediately. The release-mode APK creates a
release named `v<pubspec-version>-<run-number * 100>` as soon as it builds; the
Linux job attaches its archive afterward. Each push uses a unique workflow
concurrency group, so GitHub cannot replace an older pending main run when new
commits arrive. Pull requests still cancel superseded runs, and Pages deploys
are latest-wins.

The signed APK remains arm64-only, R8-minified, resource-shrunk, and uploaded
with its debug information. Dart obfuscation is deliberately off — the app is
open source and unobfuscated release stacks make GlitchTip triage cheaper.
The x64 Linux archive is built on `ubuntu-latest`; the arm64 archive uses
GitHub's native `ubuntu-24.04-arm` runner. Both archives and the web
deployment remain part of the same workflow.

## Test sharding

Test files are assigned by `.github/scripts/select_test_shard.py`. The planner
uses timings captured in `.github/test-durations.json` and applies a
longest-first balancing pass. Main uses 10 shards so overlapping per-commit
release runs retain capacity under the shared runner quota; tests still finish
before the longer Android and iOS builds. Pull requests and develop use 15
shards for lower isolated latency. New tests receive the configured default
estimate (the median measured file), so they are included automatically even
before timing data is refreshed; the analyze job runs
`select_test_shard.py --check` to prove every non-golden file lands in exactly
one shard for both shard counts. Each shard runs `flutter test
--concurrency=4` (one `flutter_tester` per vCPU of the GitHub-hosted runner;
test files are separate processes with in-process MMKV fakes, so they share no
state) and writes `--file-reporter=json:test-results.json`, uploaded as the
`test-results-shard-<N>` artifact. Refresh the timings from a main run with
`.github/scripts/update_test_durations.py` (see its docstring); it also parses
legacy serial expanded-reporter logs.

Golden tests are excluded from these shards and run only in the dedicated
golden job. Full Flutter tests and golden updates must run in CI, not locally.

## Caching

`.github/actions/setup-flutter/action.yml` keeps separate SDK caches for host,
Android, iOS, and web jobs. Each cache excludes platform engines that the
consumer cannot use, and exact cache hits skip redundant platform precaching.
The first rollout restores the previous full SDK cache before writing the
trimmed variants, avoiding a cold toolchain download.

Android builds additionally cache Gradle dependencies, the NDK, CMake, pub
downloads, and native-hook outputs. Release reruns can restore an exact
SHA/build-number APK cache without recompiling.

## Required secrets

| Secret | Purpose |
|--------|---------|
| `KEYSTORE_BASE64` | Production signing keystore |
| `KEYSTORE_STORE_PASSWORD` | Keystore password |
| `KEYSTORE_KEY_PASSWORD` | Signing key password |
| `KEYSTORE_KEY_ALIAS` | Signing key alias |
| `SENTRY_AUTH_TOKEN` | Native symbols and web source maps |
| `CODECOV_TOKEN` | Coverage upload |

## Manual operations

The workflow dispatch inputs select debug/release builds and the target flavor.
Set `update_goldens` to generate and upload refreshed golden PNGs. Releases are
created by pushes to `main`; do not create tags or GitHub Releases manually.
