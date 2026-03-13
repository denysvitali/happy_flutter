# Test Suite Update

**Date:** 2026-03-13
**Agent:** A5 — Testing Engineer

---

## Current Coverage

**134 test files** across the codebase. Estimated overall coverage: ~33%.

| Component | Tested | Total | Coverage |
|-----------|--------|-------|----------|
| Providers | 13 | 13 | **100%** |
| Services | 8 | 24 | 33% |
| Encryption | 10 | 20 | 50% |
| APIs | 6 | 12 | 50% |
| Models | 11 | 16 | 69% |
| Feature Screens | 54 | 81 | 67% |
| Utils | 13 | 20 | 65% |

---

## Strengths

- **100% provider test coverage** — all 13 notifiers tested with proper `ProviderContainer` lifecycle
- **Sync race condition tests** — 4 specialized tests covering TOCTOU, delta/full fetch recovery
- **Widget test infrastructure** — proper storage-free notifiers, MethodChannel mocks
- **Good test naming and organization**

---

## Critical Gaps (P0 — This Sprint)

### 1. `messages_api.dart` — UNTESTED (CRITICAL)

Core chat feature. No tests for message sending, fetching, or error handling.

**Needed:** 8–12 tests covering send, batch fetch, pagination, error responses.

### 2. `socket_io_client.dart` — UNTESTED (CRITICAL)

Real-time WebSocket transport. No tests for connection lifecycle, reconnection, or message handling.

**Needed:** 10–15 tests covering connect, disconnect, reconnect with backoff, event listening.

### 3. `encryption_service.dart` + `encryption_keys.dart` — UNTESTED (CRITICAL)

Core encryption orchestration and key management with zero tests.

**Needed:** 15–20 tests covering key derivation, encrypt/decrypt round-trips, session key management.

### 4. Session Creation End-to-End — INCOMPLETE

The P0 ROADMAP bug ("Session not loaded") lacks a full integration test:
1. Create session via API
2. Receive WebSocket update
3. Sync state updates
4. Send message successfully

---

## High Priority Gaps (P1 — Next Sprint)

### 5. Encryption Domain Files (10 untested)

| File | Risk |
|------|------|
| `artifact_encryption.dart` | HIGH |
| `machine_encryption.dart` | HIGH |
| `session_encryption.dart` | HIGH |
| `encryption_manager.dart` | CRITICAL |
| `encryptor.dart` | HIGH |
| `crypto_secret_box.dart` | MEDIUM |
| `sodium_loader*.dart` (3 files) | MEDIUM |
| `sodium_singleton.dart` | MEDIUM |

### 6. Untested Services (16 total)

Highest priority:
- `connected_services_service.dart` — OAuth integrations
- `github_service.dart` — GitHub OAuth
- `push_service.dart` — Push notifications
- `social_service.dart` — Friend requests
- `mmkv_storage_native.dart` — MMKV storage layer

### 7. Untested API Files

- `api_client.dart` — Dio wrapper (HIGH)
- `base_api_exception.dart` — Error handling (MEDIUM)
- `native_adapter_helper*.dart` — Platform HTTP (MEDIUM)

### 8. Untested Models

- `auth.dart` — AuthCredentials, AuthState (HIGH)
- `settings.dart` — Settings model with mutable fields (MEDIUM)
- `purchases.dart`, `local_settings.dart`, `built_in_profiles.dart` (LOW)

---

## Test Infrastructure Improvements

### Expand `test/helpers/test_helpers.dart`

Add factories for common test objects:
```dart
Session createTestSession({String? id, String? presence});
Message createTestMessage({String? sessionId, String? content});
Machine createTestMachine({String? id, String? name});
Artifact createTestArtifact({String? id});
Profile createTestProfile({String? id});
```

### Add Test Fixtures

```
test/fixtures/
├── sample_messages.json
├── sample_sessions.json
├── sample_artifacts.json
```

### Standardize Mock Patterns

- Prefer Mockito for external dependencies (APIs, services)
- Use manual mocks for singletons (AuthService, Sync)
- Document injection patterns

### CI Integration

Add to GitHub Actions workflow:
```yaml
test:
  runs-on: ubuntu-latest
  steps:
    - uses: subosito/flutter-action@v2
    - run: flutter test --coverage
    - uses: codecov/codecov-action@v3
      with:
        files: ./coverage/lcov.info
```

---

## Priority Effort Summary

| Priority | Tests Needed | Effort |
|----------|-------------|--------|
| P0 (Critical) | ~45 tests | ~15 hours |
| P1 (High) | ~50 tests | ~20 hours |
| P2 (Medium) | ~30 tests | ~10 hours |
| **Total** | **~125 tests** | **~45 hours** |
