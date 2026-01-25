# libsodium Integration - 24-byte Nonce Alignment

## Overview

This document describes the implementation of libsodium compatibility to achieve 24-byte nonce alignment with the React Native implementation, resolving P0 #2 from the roadmap.

## Problem Statement

The Flutter implementation previously used:
- **16-byte nonces** with custom AES-CBC implementation in `CryptoBox`
- **24-byte nonces** with custom AES-CBC implementation in `CryptoSecretBox`
- Manual key derivation and shared secret computation

The React Native implementation uses:
- **24-byte nonces** via `@more-tech/react-native-libsodium`
- `crypto_box_easy()` and `crypto_box_open_easy()` for public key encryption
- `crypto_secretbox_easy()` and `crypto_secretbox_open_easy()` for symmetric encryption
- Built-in libsodium keypair generation and key exchange

This incompatibility prevented data exchange between platforms.

## Solution

### 1. Updated CryptoBox Implementation

**File**: `/lib/core/encryption/crypto_box.dart`

#### Changes:
- Migrated from custom AES-CBC to `sodium` package's `crypto_box_easy`/`crypto_box.openEasy`
- Updated nonce size from 16 to 24 bytes (`crypto_box_NONCEBYTES`)
- Removed manual shared secret computation (now handled by libsodium)
- Updated all methods to async API

#### Key Constants:
```dart
class CryptoBoxConstants {
  static const int publicKeyBytes = 32;   // crypto_box_PUBLICKEYBYTES
  static const int secretKeyBytes = 32;   // crypto_box_SECRETKEYBYTES
  static const int nonceBytes = 24;       // crypto_box_NONCEBYTES (was 16)
  static const int seedBytes = 32;        // crypto_box_SEEDBYTES
  static const int macBytes = 16;         // crypto_box_MACBYTES
}
```

#### API Changes:
```dart
// Before: synchronous
final keypair = CryptoBox.generateKeypair();
final nonce = CryptoBox.randomNonce();

// After: asynchronous
final keypair = await CryptoBox.generateKeypair();
final nonce = await CryptoBox.randomNonce();
```

### 2. Updated CryptoSecretBox Implementation

**File**: `/lib/core/encryption/crypto_secret_box.dart`

#### Changes:
- Migrated from custom AES-CBC to `sodium` package's `crypto_secretbox_easy`/`crypto_secretbox.openEasy`
- Maintained 24-byte nonce size (`crypto_secretbox_NONCEBYTES`)
- Removed custom AES implementation (~200 lines of S-box tables and operations)

#### Key Constants:
```dart
class CryptoSecretBox {
  static const int _nonceSize = 24;  // crypto_secretbox_NONCEBYTES
  static const int _keySize = 32;    // crypto_secretbox_KEYBYTES
}
```

### 3. Bundle Format Compatibility

Both implementations now match the React Native bundle format:

#### CryptoBox Bundle:
```
[ephemeral public key: 32 bytes][nonce: 24 bytes][ciphertext: N bytes]
```

#### CryptoSecretBox Bundle:
```
[nonce: 24 bytes][ciphertext: N bytes]
```

This matches the format in `/../happy/sources/encryption/libsodium.ts`:
```typescript
// React Native format
result.set(ephemeralKeyPair.publicKey, 0);
result.set(nonce, ephemeralKeyPair.publicKey.length);
result.set(encrypted, ephemeralKeyPair.publicKey.length + nonce.length);
```

## Key Derivation Compatibility

The `DeriveKey` implementation (`/lib/core/encryption/derive_key.dart`) was already compatible:
- Uses HMAC-SHA512 for key derivation (BIP32-like structure)
- Matches React Native's `deriveKey` implementation in `/../happy/sources/encryption/deriveKey.ts`
- No changes required

## Testing

### New Test File: `test/encryption/libsodium_test.dart`

Comprehensive tests covering:
- **Constants verification**: Ensures 24-byte nonce sizes
- **Nonce generation**: Randomness and uniqueness
- **Keypair generation**: Deterministic from seed, unique when random
- **Encryption/decryption roundtrip**: Correctness verification
- **Bundle format validation**: Cross-platform compatibility
- **Edge cases**: Empty data, large data, corrupted data
- **Error handling**: Wrong keys, short bundles
- **Key derivation**: Consistency and path differentiation

### Updated Tests: `test/encryption/crypto_box_test.dart`

- Updated all tests to use async API
- Verified 24-byte nonce in bundle format tests
- Removed obsolete `computeSharedSecret` tests

## Dependencies

The `sodium` package (v3.1.0) was already in `pubspec.yaml` but not properly utilized.

## Migration Notes

### Breaking Changes:
1. **All CryptoBox methods are now async**: Any code calling `CryptoBox` methods must use `await`
2. **Nonce size changed from 16 to 24 bytes**: Affects bundle format parsing
3. **Removed `CryptoBox.computeSharedSecret`**: No longer needed with libsodium

### Code Migration Example:

```dart
// Before
final keypair = CryptoBox.keypairFromSeed(seed);
final nonce = CryptoBox.randomNonce();
final encrypted = await CryptoBox.encrypt(data, pubKey, privKey);

// After
final keypair = await CryptoBox.keypairFromSeed(seed);
final nonce = await CryptoBox.randomNonce();
final encrypted = await CryptoBox.encrypt(data, pubKey, privKey);
```

## Verification

### Manual Testing:
To verify cross-platform compatibility, you can:

1. Encrypt data in React Native:
```typescript
import { encryptBox } from '@/encryption/libsodium';
const encrypted = encryptBox(data, recipientPublicKey);
```

2. Decrypt in Flutter:
```dart
final decrypted = await CryptoBox.decrypt(encrypted, recipientSecretKey);
```

3. Verify data matches

### Test Coverage:
- **CryptoBox tests**: 20+ test cases
- **CryptoSecretBox tests**: 10+ test cases
- **libsodium compatibility tests**: 30+ test cases
- **Total coverage**: 60+ test cases for encryption

## Files Modified

1. `/lib/core/encryption/crypto_box.dart` - Migrated to libsodium
2. `/lib/core/encryption/crypto_secret_box.dart` - Migrated to libsodium
3. `/test/encryption/crypto_box_test.dart` - Updated to async API
4. `/test/encryption/libsodium_test.dart` - New comprehensive tests
5. `/ROADMAP.md` - Updated progress tracking

## Next Steps

1. **Test cross-platform encryption**: Verify data exchange with React Native app
2. **Update web platform**: Ensure web crypto also uses 24-byte nonces
3. **Performance testing**: Compare libsodium performance vs previous implementation
4. **P0 #1**: Implement true AES-256-GCM encryption for data encryption keys

## References

- React Native implementation: `/../happy/sources/encryption/libsodium.ts`
- libsodium documentation: https://libsodium.gitbook.io/doc/
- sodium package: https://pub.dev/packages/sodium
- ROADMAP P0 #2: `/ROADMAP.md#2-libsodium-integration
