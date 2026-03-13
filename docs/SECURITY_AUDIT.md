# Security Audit

**Date:** 2026-03-13
**Agent:** A6 — Security & Privacy Auditor
**Overall Risk Assessment:** MEDIUM

---

## Summary

No critical vulnerabilities. Strong crypto practices (AES-256-GCM, libsodium NaCl, Ed25519 signatures) and secure credential storage (`flutter_secure_storage`). Three high-severity findings require attention before production.

---

## High Severity

### 1. Certificate Pinning Not Implemented

**File:** `lib/core/services/certificate_provider.dart` (lines 80–85)

`_getBundledCertificates()` returns `null` — no pinning to production server certificates. Relies entirely on system CA validation.

**Risk:** MITM attacks if a CA is compromised or DNS is spoofed.

**Fix:**
1. Bundle production certificates in `assets/certs/`
2. Implement public key pinning as secondary defense
3. Add certificate rotation mechanism

### 2. Network Security Config — No Debug/Release Separation

**File:** `android/app/src/main/res/xml/network_security_config.xml`

Single config trusts both system and user-installed certificates. Production builds should not trust user certificates.

**Fix:** Create separate configs:
- `network_security_config_debug.xml` — accepts user certs (development)
- `network_security_config_release.xml` — system certs only (production)

### 3. Sentry Uploads Source Maps and Debug Symbols

**File:** `pubspec.yaml` (lines 94–103)

```yaml
sentry:
  upload_debug_symbols: true
  upload_source_maps: true
  upload_sources: true
```

Exposes original source code, function names, and variable names to Sentry servers.

**Fix:** Disable for production builds. Use obfuscation for release builds.

---

## Medium Severity

### 4. Sensitive Data in Logs

**File:** `lib/core/services/auth_service.dart` (line 463)

Error logging includes server URL and partial public key. Could assist reconnaissance.

**Fix:** Redact server URLs and never log cryptographic material.

### 5. SecureKey Disposal Gap

**File:** `lib/core/services/auth_service.dart` (lines 717–738)

`_signChallenge()` may leak SecureKey if `crypto.sign.detached()` throws before `dispose()`.

**Fix:** Wrap in try-finally:
```dart
try {
  return sodium.crypto.sign.detached(message: challenge, secretKey: secretKey);
} finally {
  if (_cachedKeypairSecret == null) secretKey.dispose();
}
```

### 6. MMKV Storage Not Encrypted

**File:** `lib/core/services/mmkv_storage_native.dart`

Settings and drafts stored in plaintext MMKV. Device theft exposes data.

**Fix:** Encrypt MMKV data or store sensitive settings in `flutter_secure_storage`.

### 7. Server URL Validation Allows HTTP

**File:** `lib/core/services/server_config.dart` (lines 87–114)

Validation accepts `http://` scheme. No domain whitelist.

**Fix:** Reject HTTP entirely. Consider domain whitelist for production.

---

## Low Severity

| # | Finding | File | Fix |
|---|---------|------|-----|
| 8 | Socket.IO auth token in connection options — visible in memory | `socket_io_client.dart` | Implement token refresh |
| 9 | Base64 encoding used for crypto material — could be confused with encryption | `encryption/base64.dart` | Add clarifying comments |
| 10 | No client-side rate limiting on auth polling | `auth_service.dart` | Add exponential backoff |
| 11 | Sentry DSN not validated | `sync_service.dart` | Use environment-specific DSNs |
| 12 | QR code data no length validation | `auth_service.dart` | Validate decoded key is 32 bytes |

---

## Good Practices Observed

- Authentication tokens in `flutter_secure_storage`
- AES-256-GCM and libsodium NaCl used correctly
- `sodium.randombytes` for cryptographic randomness
- HTTPS by default
- Proper key derivation via `Encryption.create()`
- No stack traces in user-facing errors
- Native HTTP clients via NativeAdapter
- Appropriate platform permissions
- Credentials properly disposed after use

---

## Remediation Priority

| Timeline | Actions |
|----------|---------|
| **Immediate** | Disable Sentry source uploads in production; separate network security configs |
| **Short-term** | Implement certificate pinning; try-finally for SecureKey; encrypt MMKV |
| **Medium-term** | Token refresh for Socket.IO; rate limiting; QR code validation |
