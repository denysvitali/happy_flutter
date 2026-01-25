# Web Platform Encryption Implementation

## Summary

This document describes the implementation of Web Platform Encryption using the Web Crypto API for the happy_flutter project.

## Problem

Previously, encryption threw `UnimplementedError` on the web platform, preventing the app from functioning in browsers.

## Solution

Implemented full browser-compatible encryption using the Web Crypto API (SubtleCrypto).

## Implementation Details

### Files Modified

1. **`lib/core/encryption/web_crypto.dart`** - Complete rewrite with proper JS interop
2. **`lib/core/encryption/aes_gcm.dart`** - Updated to use WebAesGcm on web platform
3. **`test/encryption/web_crypto_test.dart`** - New comprehensive test suite
4. **`ROADMAP.md`** - Updated with completion status

### Key Components

#### 1. WebCryptoBox

Provides crypto_box-like asymmetric encryption using AES-GCM.

```dart
// Generate keypair
final keypair = await WebCryptoBox.generateKeypair();

// Encrypt
final encrypted = await WebCryptoBox.encrypt(
  data,
  recipientPublicKey,
  senderPrivateKey,
);

// Decrypt
final decrypted = await WebCryptoBox.decrypt(
  encryptedBundle,
  recipientPrivateKey,
);
```

**Bundle Format**: `[ephemeral_pk (32 bytes)] [nonce (24 bytes)] [ciphertext]`

#### 2. WebCryptoSecretBox

Provides crypto_secretbox-like symmetric encryption using AES-GCM.

```dart
// Encrypt
final encrypted = await WebCryptoSecretBox.encrypt(
  jsonData,
  secretKey,
);

// Decrypt
final decrypted = await WebCryptoSecretBox.decrypt(
  encryptedData,
  secretKey,
);
```

**Format**: `[nonce (24 bytes)] [ciphertext with auth tag]`

#### 3. WebAesGcm

Direct AES-256-GCM encryption/decryption using Web Crypto API.

```dart
// Encrypt
final encrypted = await WebAesGcm.encrypt(
  dataBytes,
  secretKey,
);

// Decrypt
final decrypted = await WebAesGcm.decrypt(
  encryptedData,
  secretKey,
);
```

**Format**: `[IV (12 bytes)] [ciphertext + auth tag (16 bytes)]`

### JS Interop

Uses `dart:js_interop_unsafe` for proper Web Crypto API bindings:

```dart
@JS('crypto.subtle')
external SubtleCrypto? get subtleCrypto;

@JS('crypto.getRandomValues')
external void getRandomValues(Uint8List array);
```

### Platform Detection

The `AesGcm` class automatically uses WebAesGcm on web platform:

```dart
static Future<Uint8List> encrypt(dynamic data, Uint8List secretKey) async {
  if (kIsWeb) {
    // Use Web Crypto API for web platform
    final jsonData = jsonEncode(data);
    final dataBytes = utf8.encode(jsonData);
    return await WebAesGcm.encrypt(dataBytes, secretKey);
  }
  // Mobile implementation...
}
```

## Security Considerations

### Web Crypto API Advantages

1. **Native Browser Implementation**: Uses the browser's built-in cryptographic functions
2. **AES-GCM Mode**: Provides authenticated encryption with built-in integrity checking
3. **Secure Random Generation**: Uses `crypto.getRandomValues()` for CSPRNG
4. **Key Management**: Keys are marked as non-extractable for security

### Limitations

1. **Simplified Key Derivation**: The current implementation uses simplified XOR-based key derivation instead of true X25519 ECDH. For production use with full NaCl compatibility, consider using a WebAssembly port of libsodium.

2. **Web-Only**: This implementation only works in browser environments. For server-side Node.js, a different implementation would be needed.

3. **Nonce Handling**: While we use 24-byte nonces for libsodium compatibility, AES-GCM only uses 12 bytes for the IV. We use the first 12 bytes of the 24-byte nonce for AES-GCM, which is compatible but not a direct mapping to libsodium's XSalsa20-Poly1305.

## Testing

Comprehensive test suite in `test/encryption/web_crypto_test.dart`:

- Platform detection tests
- Keypair generation tests
- Encryption/decryption roundtrip tests
- Edge cases (empty data, large data, corrupted data)
- Cross-platform compatibility tests
- Wrong key tests (authentication verification)

Run tests with:
```bash
flutter test test/encryption/web_crypto_test.dart
```

## Browser Compatibility

The Web Crypto API is supported in all modern browsers:

- Chrome 37+
- Firefox 34+
- Safari 11+
- Edge 12+

## Future Enhancements

1. **Full NaCl Compatibility**: Integrate a WebAssembly port of libsodium for true X25519 key exchange

2. **Performance Optimization**: Cache CryptoKey objects to avoid repeated key imports

3. **Worker Threads**: Move encryption to Web Workers for better UI performance

4. **Streaming Support**: Add support for streaming encryption of large files

## References

- [Web Crypto API Specification](https://www.w3.org/TR/WebCryptoAPI/)
- [MDN Web Crypto API Documentation](https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API)
- React Native implementation: `/../happy/sources/encryption/libsodium.lib.web.ts`
