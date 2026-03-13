# Code Quality & Lint Report

**Date:** 2026-03-13
**Agent:** A9 — Code Quality & Linting Enforcer
**Compliance:** 99.8% (30 violations across 281 files — all non-blocking)

---

## Summary

The codebase demonstrates **professional-grade code quality** with strict typing (`implicit-casts: false`, `implicit-dynamic: false`), consistent naming conventions, and proper null safety. All 30 violations are info/warning level.

---

## Violations Found

### Priority 1 — Fix Immediately

| # | Rule | File | Line | Fix |
|---|------|------|------|-----|
| 1 | `depend_on_referenced_packages` | `sftp/models/sftp_log.dart` | 4 | Add `path_provider` to pubspec.yaml |
| 2 | `depend_on_referenced_packages` | `sftp/providers/sftp_provider.dart` | 6 | Add `path_provider` to pubspec.yaml |
| 3 | `depend_on_referenced_packages` | `sftp/screens/sftp_connection_history_screen.dart` | 6 | Add `path_provider` to pubspec.yaml |
| 4 | `deprecated_member_use` | `sftp/providers/sftp_provider.dart` | 157 | `value:` → `initialValue:` |
| 5 | `deprecated_member_use` | `sftp/providers/sftp_provider.dart` | 175 | `value:` → `initialValue:` |
| 6 | `deprecated_member_use` | `sftp/screens/sftp_connection_history_screen.dart` | 377 | `value:` → `initialValue:` |
| 7 | `deprecated_member_use` | `sftp/screens/sftp_connection_history_screen.dart` | 415 | `value:` → `initialValue:` |
| 8 | `unawaited_futures` | `sftp/screens/sftp_connection_history_screen.dart` | 311 | `await` or wrap with `unawaited()` |

### Priority 2 — Fix Soon

| # | Rule | File | Line | Fix |
|---|------|------|------|-----|
| 9 | `unused_import` | `providers/settings_notifier.dart` | 3 | Remove `import '../models/profile.dart'` |
| 10–15 | `lines_longer_than_80_chars` | Various (6 files) | — | Break lines with trailing commas |
| 16–24 | `sort_constructors_first` | `sessions/sessions_screen.dart` | 1331+ | Move constructors above methods |

### Priority 3 — Nice to Have

| # | Rule | Count | Fix |
|---|------|-------|-----|
| 25–26 | `omit_local_variable_types` | 2 | Use `final` instead of explicit type |
| 27–28 | `use_if_null_to_convert_nulls_to_bools` | 2 | `confirmed == true` → `confirmed` |
| 29 | `cascade_invocations` | 1 | Use `..` cascade operator |
| 30 | `directives_ordering` | 1 | Sort imports alphabetically |

---

## Compliance by Category

| Category | Status |
|----------|--------|
| File naming (snake_case) | Pass |
| Class naming (PascalCase) | Pass |
| Method naming (camelCase) | Pass |
| Const constructors | Pass (99%+) |
| Type annotations | Pass |
| Null safety | Pass |
| No `print()` in lib/ | Pass (only in doc examples) |
| Immutable updates | Pass |

---

## Estimated Fix Time

All 30 violations: **2–4 hours**
