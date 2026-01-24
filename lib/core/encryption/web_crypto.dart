import 'dart:convert';
import 'dart:typed_data';

/// Web Crypto API implementation for encryption operations.
/// Uses ECDH for key agreement and AES-GCM for authenticated encryption.
///
/// This file uses js_interop for web platform support.

import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;

/// Constants for Web Crypto encryption
class WebCryptoConstants {
  static const int ephemeralKeyBytes = 32;
  static const int ivBytes = 12;
  static const int authTagBytes = 16;
  static const int aesKeyBytes = 32;
  static const int seedBytes = 32;
}

// JS interop types
@JS()
class _CryptoKey {}

@JS()
class _CryptoKeyPair {
  external _CryptoKey get publicKey;
  external _CryptoKey get privateKey;
}

@JS('crypto')
external dynamic get _jsCrypto;

/// Web Crypto Box - uses ECDH for key agreement + AES-GCM for encryption.
class WebCryptoBox {
  static Uint8List randomIv() {
    return _getRandomValues(WebCryptoConstants.ivBytes);
  }

  static Uint8List _getRandomValues(int length) {
    final buffer = Uint8List(length);
    js_util.callMethod(_jsCrypto, 'getRandomValues', [buffer]);
    return buffer;
  }

  static Future<WebCryptoKeyPair> generateKeypair() async {
    final subtle = js_util.getProperty(_jsCrypto, 'subtle');
    final keyPair = await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'generateKey', [
        js_util.jsify({'name': 'ECDH', 'namedCurve': 'P-256'}),
        true,
        js_util.jsify(['deriveKey', 'deriveBits']),
      ]),
    );

    final publicKeyBytes = await _exportPublicKey(
      js_util.getProperty(keyPair, 'publicKey'),
    );
    final privateKeyBytes = await _exportPrivateKey(
      js_util.getProperty(keyPair, 'privateKey'),
    );

    return WebCryptoKeyPair(
      publicKey: publicKeyBytes.sublist(0, WebCryptoConstants.ephemeralKeyBytes),
      privateKey: privateKeyBytes,
    );
  }

  static Future<Uint8List> _exportPublicKey(_CryptoKey key) async {
    final subtle = js_util.getProperty(_jsCrypto, 'subtle');
    final exported = await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'exportKey', ['raw', key]),
    );
    return (exported as ByteBuffer).asUint8List();
  }

  static Future<Uint8List> _exportPrivateKey(_CryptoKey key) async {
    final subtle = js_util.getProperty(_jsCrypto, 'subtle');
    final exported = await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'exportKey', ['pkcs8', key]),
    );
    return (exported as ByteBuffer).asUint8List();
  }

  static Future<_CryptoKey> _importPublicKey(Uint8List publicKeyBytes) async {
    final subtle = js_util.getProperty(_jsCrypto, 'subtle');
    return await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'importKey', [
        'raw',
        publicKeyBytes.sublist(0, 33),
        js_util.jsify({'name': 'ECDH', 'namedCurve': 'P-256'}),
        false,
        [],
      ]),
    );
  }

  static Future<_CryptoKey> _importPrivateKey(Uint8List privateKeyBytes) async {
    final subtle = js_util.getProperty(_jsCrypto, 'subtle');
    return await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'importKey', [
        'pkcs8',
        privateKeyBytes,
        js_util.jsify({'name': 'ECDH', 'namedCurve': 'P-256'}),
        false,
        js_util.jsify(['deriveKey', 'deriveBits']),
      ]),
    );
  }

  static Future<Uint8List> deriveSharedSecret(
    Uint8List privateKeyBytes,
    Uint8List publicKeyBytes,
  ) async {
    final privateKey = await _importPrivateKey(privateKeyBytes);
    final publicKey = await _importPublicKey(publicKeyBytes);
    final subtle = js_util.getProperty(_jsCrypto, 'subtle');

    final sharedBits = await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'deriveBits', [
        js_util.jsify({'name': 'ECDH', 'public': publicKey}),
        privateKey,
        256,
      ]),
    );

    return (sharedBits as ByteBuffer).asUint8List();
  }

  static Future<Uint8List> encrypt(
    Uint8List data,
    Uint8List recipientPublicKey,
    Uint8List senderPrivateKey,
  ) async {
    final ephemeralKeypair = await generateKeypair();
    final sharedSecret = await deriveSharedSecret(
      senderPrivateKey,
      recipientPublicKey,
    );
    final aesKey = await _deriveAesKey(sharedSecret);
    final iv = randomIv();

    final subtle = js_util.getProperty(_jsCrypto, 'subtle');
    final encrypted = await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'encrypt', [
        js_util.jsify({'name': 'AES-GCM', 'iv': iv, 'tagLength': 128}),
        aesKey,
        data,
      ]),
    );

    final encryptedList = (encrypted as ByteBuffer).asUint8List();
    final resultLength = WebCryptoConstants.ephemeralKeyBytes +
        WebCryptoConstants.ivBytes +
        encryptedList.length;
    final result = Uint8List(resultLength);

    result.setAll(0, ephemeralKeypair.publicKey);
    result.setAll(WebCryptoConstants.ephemeralKeyBytes, iv);
    result.setAll(
      WebCryptoConstants.ephemeralKeyBytes + WebCryptoConstants.ivBytes,
      encryptedList,
    );

    return result;
  }

  static Future<Uint8List?> decrypt(
    Uint8List encryptedBundle,
    Uint8List recipientPrivateKey,
  ) async {
    try {
      final ephemeralPublicKey = encryptedBundle.sublist(
        0,
        WebCryptoConstants.ephemeralKeyBytes,
      );
      final iv = encryptedBundle.sublist(
        WebCryptoConstants.ephemeralKeyBytes,
        WebCryptoConstants.ephemeralKeyBytes + WebCryptoConstants.ivBytes,
      );
      final encrypted = encryptedBundle.sublist(
        WebCryptoConstants.ephemeralKeyBytes + WebCryptoConstants.ivBytes,
      );

      final sharedSecret = await deriveSharedSecret(
        recipientPrivateKey,
        ephemeralPublicKey,
      );
      final aesKey = await _deriveAesKey(sharedSecret);

      final subtle = js_util.getProperty(_jsCrypto, 'subtle');
      final decrypted = await js_util.promiseToFuture(
        js_util.callMethod(subtle, 'decrypt', [
          js_util.jsify({'name': 'AES-GCM', 'iv': iv, 'tagLength': 128}),
          aesKey,
          encrypted,
        ]),
      );

      return (decrypted as ByteBuffer).asUint8List();
    } catch (e) {
      return null;
    }
  }

  static Future<_CryptoKey> _deriveAesKey(Uint8List sharedSecret) async {
    final subtle = js_util.getProperty(_jsCrypto, 'subtle');

    final keyMaterial = await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'importKey', [
        'raw',
        sharedSecret,
        'HKDF',
        false,
        js_util.jsify(['deriveKey']),
      ]),
    );

    return await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'deriveKey', [
        js_util.jsify({
          'name': 'HKDF',
          'hash': 'SHA-256',
          'salt': Uint8List(32),
          'info': utf8.encode('happy-encryption-v1'),
        }),
        keyMaterial,
        js_util.jsify({'name': 'AES-GCM', 'length': 256}),
        false,
        js_util.jsify(['encrypt', 'decrypt']),
      ]),
    );
  }
}

/// Web Crypto Secret Box - AES-GCM encryption with a shared key.
class WebCryptoSecretBox {
  static Uint8List randomIv() {
    return WebCryptoBox.randomIv();
  }

  static Future<Uint8List> encrypt(dynamic data, Uint8List secretKey) async {
    final iv = WebCryptoBox.randomIv();

    Uint8List dataBytes;
    if (data is Uint8List) {
      dataBytes = data;
    } else {
      final jsonData = jsonEncode(data);
      dataBytes = Uint8List.fromList(utf8.encode(jsonData));
    }

    final subtle = js_util.getProperty(_jsCrypto, 'subtle');
    final key = await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'importKey', [
        'raw',
        secretKey.sublist(0, WebCryptoConstants.aesKeyBytes),
        js_util.jsify({'name': 'AES-GCM', 'length': 256}),
        false,
        js_util.jsify(['encrypt']),
      ]),
    );

    final encrypted = await js_util.promiseToFuture(
      js_util.callMethod(subtle, 'encrypt', [
        js_util.jsify({'name': 'AES-GCM', 'iv': iv, 'tagLength': 128}),
        key,
        dataBytes,
      ]),
    );

    final encryptedList = (encrypted as ByteBuffer).asUint8List();
    final result = Uint8List(WebCryptoConstants.ivBytes + encryptedList.length);
    result.setAll(0, iv);
    result.setAll(WebCryptoConstants.ivBytes, encryptedList);

    return result;
  }

  static Future<dynamic> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) async {
    try {
      final iv = encryptedData.sublist(0, WebCryptoConstants.ivBytes);
      final encrypted = encryptedData.sublist(WebCryptoConstants.ivBytes);

      final subtle = js_util.getProperty(_jsCrypto, 'subtle');
      final key = await js_util.promiseToFuture(
        js_util.callMethod(subtle, 'importKey', [
          'raw',
          secretKey.sublist(0, WebCryptoConstants.aesKeyBytes),
          js_util.jsify({'name': 'AES-GCM', 'length': 256}),
          false,
          js_util.jsify(['decrypt']),
        ]),
      );

      final decrypted = await js_util.promiseToFuture(
        js_util.callMethod(subtle, 'decrypt', [
          js_util.jsify({'name': 'AES-GCM', 'iv': iv, 'tagLength': 128}),
          key,
          encrypted,
        ]),
      );

      final decryptedBytes = (decrypted as ByteBuffer).asUint8List();

      try {
        final jsonString = utf8.decode(decryptedBytes);
        return jsonDecode(jsonString);
      } catch (_) {
        return decryptedBytes;
      }
    } catch (e) {
      return null;
    }
  }
}

class WebCryptoKeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;

  WebCryptoKeyPair({
    required this.publicKey,
    required this.privateKey,
  });
}
