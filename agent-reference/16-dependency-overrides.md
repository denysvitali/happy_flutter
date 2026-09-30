## Dependency Overrides

`pubspec.yaml` has **~30 `dependency_overrides`** in three groups, each with an
inline comment explaining the pin. Read those comments before touching any of
them — several encode Flutter-SDK constraints that a bump silently breaks:

1. **Platform-implementation pins** — `shared_preferences_android`,
   `mmkv_platform_interface`, `flutter_secure_storage_linux`, `go_router`,
   `dartastic_opentelemetry*`.
2. **Force-upgrade block (2026-06-15)** — unblocks transitive constraints
   flagged by `pub upgrade`. **Never force-bump a package whose latest release
   declares Dart 3.12**: overrides bypass pub's SDK check, so it resolves and
   then fails at compile time. mise pins Flutter 3.41 / Dart 3.11.
3. **Caps** — `cupertino_http` (3.x breaks `flutter build linux`),
   `jni`/`cronet_http`/`path_provider_android` (held by `sentry_flutter`'s
   hard pin on `jni` 0.14.2).

