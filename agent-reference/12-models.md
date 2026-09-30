## Models

**`freezed` + `json_serializable`** for most core models (`session`, `message`, `machine`, `artifact`, `usage`, `auth`, `kv`, `local_settings`, `purchases`, `api_update`, `claude_usage_limits`) since the freezed migration (a1e03c3f); a few simpler models (`profile`, `todo`, `friend_request`, `settings_update`) remain manual `fromJson`/`toJson`/`copyWith`. Timestamps are integers (milliseconds), not `DateTime`.

**NEVER hand-edit `*.g.dart` or `*.freezed.dart` files.** After changing any annotated model, regenerate with `mise exec -- flutter pub run build_runner build --delete-conflicting-outputs` and commit the regenerated output together with the source change.

**Exception:** `Settings` uses mutable public fields (`var`, not `final`) and roundtrips through `toJson()`/`fromJson()` in `updateSetting`. Nested config classes within Settings use `final` fields normally.

**`Session.presence`** is always a `String` (`'online'` or `'offline'`), never `null`. Absence on wire maps to `'offline'`.

**`WireParsers`** utility handles lenient type coercion for JSON fields (numbers vs numeric strings from different backends).

