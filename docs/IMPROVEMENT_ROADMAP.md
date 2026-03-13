# Improvement Roadmap

**Date:** 2026-03-13
**Compiled by:** Team Lead — synthesized from 9 agent reviews

---

## Agent Team Summary

| Agent | Role | Key Finding |
|-------|------|-------------|
| A1 | Architect | Sync singleton is a 3,700-line god object; screens bypass Riverpod |
| A2 | UI/UX | Strong token system; 20+ hardcoded font sizes, 15+ missing a11y labels |
| A3 | State Mgmt | 2 cache invalidation bugs (FeedState, TodoListState); session creation race |
| A4 | Performance | Monolithic screens, 41 ListViews without .builder, repeated Theme.of() |
| A5 | Testing | 134 tests, 100% provider coverage; messages_api, socket_io, encryption untested |
| A6 | Security | No cert pinning; Sentry uploads source maps; MMKV unencrypted |
| A7 | Documentation | Strong markdown docs; 14/15 notifiers have zero doc comments |
| A8 | CI/CD | Tests not run in CI; no iOS builds; no AAB for Play Store |
| A9 | Code Quality | 99.8% lint compliance; 30 non-blocking violations |

---

## Priority 0 — Critical Bugs (Fix This Week)

| # | Issue | Source | Impact | Effort | Files |
|---|-------|--------|--------|--------|-------|
| 1 | **FeedState cache not invalidated in copyWith()** | A3 | Stale unread counts | 15 min | `feed_notifier.dart` |
| 2 | **TodoListState cache not invalidated in copyWith()** | A3 | Stale combined todo list | 15 min | `todo_notifier.dart` |
| 3 | **Session creation race condition** (ROADMAP P0) | A3, A5 | "Session not loaded" error | 2–4 hrs | `sync_service.dart`, providers |
| 4 | **Tests not run in CI** | A8 | Broken tests can ship | 1 hr | `.github/workflows/ci.yml` |
| 5 | **Sentry uploads source maps to production** | A6 | Code exposure | 15 min | `pubspec.yaml` |

---

## Priority 1 — High Impact (This Sprint)

### Architecture & State

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 6 | Move business logic from ChatScreen to notifiers (28+ sync calls) | A1, A4 | 4–6 hrs |
| 7 | Move business logic from NewSessionScreen to notifiers | A1 | 1–2 hrs |
| 8 | Replace manual sync stream subscriptions with ref.watch() | A1, A4 | 2–3 hrs |
| 9 | Remove redundant double-load in AuthStateNotifier | A3 | 30 min |
| 10 | Standardize mutation patterns (spread operators everywhere) | A3 | 30 min |

### Security

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 11 | Implement certificate pinning for production | A6 | 4–6 hrs |
| 12 | Separate network security configs (debug/release) | A6 | 1 hr |
| 13 | Add try-finally to SecureKey operations | A6 | 1 hr |

### Testing

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 14 | Test messages_api.dart (8–12 tests) | A5 | 2–3 hrs |
| 15 | Test socket_io_client.dart (10–15 tests) | A5 | 3–4 hrs |
| 16 | Test encryption_service.dart + encryption_keys.dart (15–20 tests) | A5 | 4–5 hrs |

### CI/CD

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 17 | Add AAB builds for Play Store | A8 | 1 hr |
| 18 | Add Dependabot for dependency scanning | A8 | 30 min |

---

## Priority 2 — Medium Impact (Next Sprint)

### Performance

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 19 | Convert 41 ListView(children:) to ListView.builder() | A4 | 3–4 hrs |
| 20 | Cache Theme.of(context) in message rendering pipeline | A4 | 1–2 hrs |
| 21 | Extract expensive build computations to providers | A4 | 1–2 hrs |
| 22 | Extract search state to StateProvider | A4 | 1–2 hrs |

### UI/UX

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 23 | Replace 20+ hardcoded font sizes with AppFontSize tokens | A2 | 2 hrs |
| 24 | Add semantic labels to 15+ icon-only buttons | A2 | 2 hrs |
| 25 | Create AppCodeSyntaxColors (theme-aware code highlighting) | A2 | 2 hrs |
| 26 | Extract StatusBadge, ModalHeader reusable widgets | A2 | 2 hrs |

### Code Quality

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 27 | Add path_provider to pubspec.yaml (3 SFTP files depend on it) | A9 | 15 min |
| 28 | Fix 4 deprecated TextFormField `value:` → `initialValue:` | A9 | 15 min |
| 29 | Remove unused import in settings_notifier.dart | A9 | 5 min |
| 30 | Fix remaining 22 lint violations | A9 | 2 hrs |

### Security

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 31 | Encrypt MMKV storage | A6 | 2–3 hrs |
| 32 | Reject HTTP in server URL validation | A6 | 30 min |
| 33 | Redact sensitive data from error logs | A6 | 1 hr |

### Testing

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 34 | Test artifact/machine/session encryption (12–15 tests) | A5 | 3 hrs |
| 35 | Test remaining untested services (25–30 tests) | A5 | 5–6 hrs |
| 36 | Test remaining API files (10–12 tests) | A5 | 2–3 hrs |
| 37 | Expand test_helpers.dart with factories | A5 | 1 hr |

### Documentation

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 38 | Add doc comments to 14 undocumented notifiers | A7 | 2–3 hrs |
| 39 | Add doc comments to 15 model classes | A7 | 3–4 hrs |
| 40 | Document encryption_service.dart (4 → 20+ comments) | A7 | 1 hr |

---

## Priority 3 — Polish (This Quarter)

### Architecture

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 41 | Create repository interfaces (SessionsRepo, MessagesRepo) | A1 | 6–8 hrs |
| 42 | Break Sync singleton into focused managers | A1 | 16–24 hrs |
| 43 | Add use case layer for complex operations | A1 | 4–6 hrs |

### CI/CD

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 44 | iOS CI/CD pipeline (macOS runner, code signing) | A8 | 8–12 hrs |
| 45 | Play Store publishing automation | A8 | 4–6 hrs |
| 46 | Firebase App Distribution for QA | A8 | 2–3 hrs |
| 47 | Semantic versioning automation | A8 | 2 hrs |
| 48 | Fix Java version mismatch (devenv jdk21 vs CI jdk17) | A8 | 30 min |

### Documentation

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 49 | Create CONTRIBUTING.md | A7 | 1 hr |
| 50 | Create Feature Development Guide | A7 | 2–3 hrs |
| 51 | Create Encryption Strategy Guide | A7 | 2 hrs |
| 52 | Create Architecture Decision Records | A7 | 1.5 hrs |

### Security

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 53 | Implement token refresh for Socket.IO | A6 | 2–3 hrs |
| 54 | Add exponential backoff to auth polling | A6 | 1 hr |
| 55 | Validate QR code key length (32 bytes) | A6 | 30 min |

---

## Effort Summary

| Priority | Items | Total Effort |
|----------|-------|-------------|
| P0 — Critical | 5 | ~5–7 hours |
| P1 — High | 13 | ~25–35 hours |
| P2 — Medium | 19 | ~35–45 hours |
| P3 — Polish | 15 | ~50–70 hours |
| **Grand Total** | **52** | **~115–157 hours** |

---

## Suggested Sprint Plan

### Sprint 1 (Current Week)
- P0 items #1–5 (bugs, CI tests, Sentry)
- P1 items #6–7 (extract business logic from screens)

### Sprint 2
- P1 items #8–13 (architecture cleanup, security hardening)
- P1 items #14–16 (critical test gaps)

### Sprint 3
- P2 performance (#19–22)
- P2 UI/UX (#23–26)
- P2 code quality (#27–30)

### Sprint 4+
- P2 testing and documentation (#34–40)
- P3 architecture refactoring (#41–43)
- P3 CI/CD automation (#44–48)

---

## Cross-Cutting Themes

1. **Sync decoupling** — The single biggest architectural improvement. Touches A1, A3, A4, A5.
2. **Test coverage** — Critical paths (messaging, encryption, WebSocket) are untested. Touches A5, A8.
3. **Production readiness** — Certificate pinning, Sentry config, AAB builds, CI tests. Touches A6, A8.
4. **Token compliance** — Replace hardcoded values with design tokens. Touches A2, A9.
5. **Documentation debt** — 14/15 notifiers undocumented. Touches A7.

---

## Related Documents

- [Architecture Review](./ARCHITECTURE.md)
- [UI/UX Review](./UI_UX_REVIEW.md)
- [State Management Recommendation](./STATE_MGMT_RECOMMENDATION.md)
- [Performance Report](./PERFORMANCE_REPORT.md)
- [Test Suite Update](./TEST_SUITE_UPDATE.md)
- [Security Audit](./SECURITY_AUDIT.md)
- [DevOps / CI-CD Report](./DEV_OPS_CI_CD.md)
- [Code Quality & Lint Report](./CODE_QUALITY_LINT.md)
