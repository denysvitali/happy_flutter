# DevOps / CI-CD

**Updated:** 2026-08-08

## Main workflow

`.github/workflows/ci.yml` defines the `Happy Flutter CI/CD` workflow. It runs
analysis, tests, release builds, and web deployment in parallel so release
production is not serialized behind the test suite.

| Job | Purpose |
|-----|---------|
| Analyze Code | Strict Flutter analysis with dependency resolution skipped |
| Test | 15 duration-balanced shards for all non-golden tests |
| Upload Coverage | Merge shard coverage and upload it to Codecov |
| Golden Screenshots | Verify PR goldens or generate requested replacements |
| Build Debug APK | Build non-main and manually requested debug artifacts |
| Build Release APK | Build the signed, obfuscated production APK |
| Build Linux x64 | Build and archive the Linux desktop bundle |
| Publish GitHub Release | Publish the APK and Linux archive |
| Build/Deploy Web | Build the web app and deploy GitHub Pages |

## Release invariant

Every push to `main`, including documentation-only pushes, starts a release.
The APK and Linux jobs start immediately and publish a release named
`v<pubspec-version>-<run-number * 100>`. Main runs are never cancelled by the
workflow concurrency policy, so a later push cannot suppress an earlier
release.

The signed APK remains arm64-only, R8-minified, resource-shrunk, obfuscated,
and uploaded with its debug information. The Linux archive and web deployment
remain part of the same workflow.

## Test sharding

Test files are assigned by `.github/scripts/select_test_shard.py`. The planner
uses timings captured in `.github/test-durations.json` and applies a
longest-first balancing pass across 15 shards. New tests receive the configured
default estimate, so they are included automatically even before timing data is
refreshed. Each shard still runs tests serially to control memory usage.

Golden tests are excluded from these shards and run only in the dedicated
golden job. Full Flutter tests and golden updates must run in CI, not locally.

## Caching

`.github/actions/setup-flutter/action.yml` keeps separate SDK caches for host,
Android, and web jobs. Each cache excludes platform engines that the consumer
cannot use. The first rollout restores the previous full SDK cache before
writing the trimmed variants, avoiding a cold toolchain download.

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
