import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_crypto.dart' if (dart.library.html) 'web_crypto.dart';

class CryptoSecretBox {
  static const int _nonceSize = 24;
  static const int _keySize = 32;

  static Future<Uint8List> encrypt(dynamic data, Uint8List secretKey) async {
    if (kIsWeb) {
      return await WebCryptoSecretBox.encrypt(data, secretKey);
    }

    final nonce = randomNonce();
    final jsonData = jsonEncode(data);
    final dataBytes = utf8.encode(jsonData);

    final key = secretKey.length >= _keySize
        ? secretKey.sublist(0, _keySize)
        : Uint8List.fromList(secretKey);

    final encrypted = _aesCbcEncrypt(dataBytes, key, nonce);

    final result = Uint8List(nonce.length + encrypted.length);
    result.setAll(0, nonce);
    result.setAll(nonce.length, encrypted);

    return result;
  }

  static Future<dynamic> decrypt(Uint8List encryptedData, Uint8List secretKey) async {
    if (kIsWeb) {
      return await WebCryptoSecretBox.decrypt(encryptedData, secretKey);
    }

    try {
      if (encryptedData.length < _nonceSize + 16) {
        return null;
      }

      final nonce = encryptedData.sublist(0, _nonceSize);
      final encrypted = encryptedData.sublist(_nonceSize);

      final key = secretKey.length >= _keySize
          ? secretKey.sublist(0, _keySize)
          : Uint8List.fromList(secretKey);

      final decrypted = _aesCbcDecrypt(encrypted, key, nonce);

      final jsonString = utf8.decode(decrypted);
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }

  static Uint8List _aesCbcEncrypt(
    Uint8List data,
    Uint8List key,
    Uint8List iv,
  ) {
    final result = <int>[];
    var previousBlock = iv;

    for (int i = 0; i < data.length; i += 16) {
      final block = data.sublist(i, i + 16 < data.length ? i + 16 : data.length);
      final xored = Uint8List(16);
      for (int j = 0; j < block.length; j++) {
        xored[j] = block[j] ^ previousBlock[j];
      }
      final encrypted = _aesEncryptBlock(xored, key);
      result.addAll(encrypted);
      previousBlock = encrypted;
    }

    return Uint8List.fromList(result);
  }

  static Uint8List _aesCbcDecrypt(
    Uint8List data,
    Uint8List key,
    Uint8List iv,
  ) {
    final result = <int>[];
    var previousBlock = iv;

    for (int i = 0; i < data.length; i += 16) {
      final block = data.sublist(i, i + 16);
      final decrypted = _aesDecryptBlock(block, key);
      final xored = Uint8List(16);
      for (int j = 0; j < 16; j++) {
        xored[j] = decrypted[j] ^ previousBlock[j];
      }
      result.addAll(xored);
      previousBlock = block;
    }

    return Uint8List.fromList(result);
  }

  static Uint8List _aesEncryptBlock(Uint8List block, Uint8List key) {
    return _aesBlockCipher(block, key, true);
  }

  static Uint8List _aesDecryptBlock(Uint8List block, Uint8List key) {
    return _aesBlockCipher(block, key, false);
  }

  static Uint8List _aesBlockCipher(
    Uint8List block,
    Uint8List key,
    bool encrypt,
  ) {
    final rounds = key.length == 32 ? 14 : key.length == 24 ? 12 : 10;
    final keySchedule = _keyExpansion(key, rounds);

    var state = List<int>.from(block);

    if (encrypt) {
      _addRoundKey(state, keySchedule, 0);
      for (int round = 1; round < rounds; round++) {
        _subBytes(state);
        _shiftRows(state);
        _mixColumns(state);
        _addRoundKey(state, keySchedule, round);
      }
      _subBytes(state);
      _shiftRows(state);
      _addRoundKey(state, keySchedule, rounds);
    } else {
      _addRoundKey(state, keySchedule, rounds);
      for (int round = rounds - 1; round > 0; round--) {
        _invShiftRows(state);
        _invSubBytes(state);
        _addRoundKey(state, keySchedule, round);
        _invMixColumns(state);
      }
      _invShiftRows(state);
      _invSubBytes(state);
      _addRoundKey(state, keySchedule, 0);
    }

    return Uint8List.fromList(state);
  }

  static List<List<int>> _keyExpansion(Uint8List key, int rounds) {
    final keySize = key.length;
    final keySchedule =
        List.generate(rounds + 1, (_) => List<int>.filled(4, 0));

    for (int i = 0; i < keySize ~/ 4; i++) {
      keySchedule[0][i] = key[4 * i];
      keySchedule[1][i] = key[4 * i + 1];
      keySchedule[2][i] = key[4 * i + 2];
      keySchedule[3][i] = key[4 * i + 3];
    }

    for (int i = keySize ~/ 4; i < 4 * (rounds + 1); i++) {
      var temp = [
        keySchedule[0][i - 1],
        keySchedule[1][i - 1],
        keySchedule[2][i - 1],
        keySchedule[3][i - 1],
      ];

      if (i % (keySize ~/ 4) == 0) {
        temp = _rotWord(temp);
        temp = _subWord(temp);
        temp[0] ^= _rcon[i ~/ (keySize ~/ 4) - 1];
      } else if (keySize == 32 && i % (keySize ~/ 4) == 4) {
        temp = _subWord(temp);
      }

      for (int j = 0; j < 4; j++) {
        keySchedule[j][i] = keySchedule[j][i - keySize ~/ 4] ^ temp[j];
      }
    }

    return keySchedule;
  }

  static List<int> _rotWord(List<int> word) {
    return [word[1], word[2], word[3], word[0]];
  }

  static List<int> _subWord(List<int> word) {
    return word.map((b) => _sBox[b]).toList();
  }

  static void _addRoundKey(
    List<int> state,
    List<List<int>> keySchedule,
    int round,
  ) {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        state[4 * i + j] ^= keySchedule[j][round * 4 + i];
      }
    }
  }

  static void _subBytes(List<int> state) {
    for (int i = 0; i < 16; i++) {
      state[i] = _sBox[state[i]];
    }
  }

  static void _invSubBytes(List<int> state) {
    for (int i = 0; i < 16; i++) {
      state[i] = _invSBox[state[i]];
    }
  }

  static void _shiftRows(List<int> state) {
    final temp = List<int>.from(state);
    state[0] = temp[0];
    state[1] = temp[5];
    state[2] = temp[10];
    state[3] = temp[15];
    state[4] = temp[4];
    state[5] = temp[9];
    state[6] = temp[14];
    state[7] = temp[3];
    state[8] = temp[8];
    state[9] = temp[13];
    state[10] = temp[2];
    state[11] = temp[7];
    state[12] = temp[12];
    state[13] = temp[1];
    state[14] = temp[6];
    state[15] = temp[11];
  }

  static void _invShiftRows(List<int> state) {
    final temp = List<int>.from(state);
    state[0] = temp[0];
    state[1] = temp[13];
    state[2] = temp[10];
    state[3] = temp[7];
    state[4] = temp[4];
    state[5] = temp[1];
    state[6] = temp[14];
    state[7] = temp[11];
    state[8] = temp[8];
    state[9] = temp[5];
    state[10] = temp[2];
    state[11] = temp[15];
    state[12] = temp[12];
    state[13] = temp[9];
    state[14] = temp[6];
    state[15] = temp[3];
  }

  static void _mixColumns(List<int> state) {
    for (int i = 0; i < 4; i++) {
      final idx = 4 * i;
      final a0 = state[idx];
      final a1 = state[idx + 1];
      final a2 = state[idx + 2];
      final a3 = state[idx + 3];

      state[idx] = _gmul(0x02, a0) ^ _gmul(0x03, a1) ^ a2 ^ a3;
      state[idx + 1] = a0 ^ _gmul(0x02, a1) ^ _gmul(0x03, a2) ^ a3;
      state[idx + 2] = a0 ^ a1 ^ _gmul(0x02, a2) ^ _gmul(0x03, a3);
      state[idx + 3] = _gmul(0x03, a0) ^ a1 ^ a2 ^ _gmul(0x02, a3);
    }
  }

  static void _invMixColumns(List<int> state) {
    for (int i = 0; i < 4; i++) {
      final idx = 4 * i;
      final a0 = state[idx];
      final a1 = state[idx + 1];
      final a2 = state[idx + 2];
      final a3 = state[idx + 3];

      state[idx] = _gmul(0x0e, a0) ^ _gmul(0x0b, a1) ^ _gmul(0x0d, a2) ^ _gmul(0x09, a3);
      state[idx + 1] = _gmul(0x09, a0) ^ _gmul(0x0e, a1) ^ _gmul(0x0b, a2) ^ _gmul(0x0d, a3);
      state[idx + 2] = _gmul(0x0d, a0) ^ _gmul(0x09, a1) ^ _gmul(0x0e, a2) ^ _gmul(0x0b, a3);
      state[idx + 3] = _gmul(0x0b, a0) ^ _gmul(0x0d, a1) ^ _gmul(0x09, a2) ^ _gmul(0x0e, a3);
    }
  }

  static int _gmul(int a, int b) {
    var p = 0;
    for (int i = 0; i < 8; i++) {
      if ((b & 1) != 0) {
        p ^= a;
      }
      final hiBitSet = (a & 0x80) != 0;
      a <<= 1;
      if (hiBitSet) {
        a ^= 0x1b;
      }
      b >>= 1;
    }
    return p & 0xff;
  }

  static Uint8List randomNonce() {
    final random = Random.secure();
    final nonce = Uint8List(_nonceSize);
    for (int i = 0; i < _nonceSize; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }

  static const _sBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b,
    0xfe, 0xd7, 0xab, 0x76, 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0,
    0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0, 0xb7, 0xfd, 0x93, 0x26,
    0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2,
    0xeb, 0x27, 0xb2, 0x75, 0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0,
    0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84, 0x53, 0xd1, 0x00, 0xed,
    0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f,
    0x50, 0x3c, 0x9f, 0xa8, 0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5,
    0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2, 0xcd, 0x0c, 0x13, 0xec,
    0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14,
    0xde, 0x5e, 0x0b, 0xdb, 0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c,
    0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79, 0xe7, 0xc8, 0x37, 0x6d,
    0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f,
    0x4b, 0xbd, 0x8b, 0x8a, 0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e,
    0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e, 0xe1, 0xf8, 0x98, 0x11,
    0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f,
    0xb0, 0x54, 0xbb, 0x16,
  ];

  static const _invSBox = [
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e,
    0x81, 0xf3, 0xd7, 0xfb, 0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87,
    0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb, 0x54, 0x7b, 0x94, 0x32,
    0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49,
    0x6d, 0x8b, 0xd1, 0x25, 0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16,
    0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92, 0x6c, 0x70, 0x48, 0x50,
    0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05,
    0xb8, 0xb3, 0x45, 0x06, 0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02,
    0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b, 0x3a, 0x91, 0x11, 0x41,
    0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8,
    0x1d, 0xc6, 0xbb, 0x3b, 0x03, 0xd6, 0xbe, 0xa7, 0x13, 0x57, 0x1e, 0x4f,
    0x14, 0x70, 0x56, 0x8d, 0x40, 0xc0, 0xba, 0x2c, 0x65, 0x80, 0xb7, 0x57,
    0x89, 0x9e, 0x4f, 0x10, 0x1c, 0x41, 0x89, 0x6e, 0x47, 0xd9, 0x8e, 0x46,
    0x2d, 0xb4, 0x7a, 0xc9, 0xa1, 0x4e, 0x8a, 0x6d, 0x2b, 0x85, 0x20, 0x0c,
    0xc5, 0xd3, 0x92, 0x28, 0x8c, 0x78, 0x3f, 0x11, 0x7b, 0x69, 0xd7, 0x5c,
    0xa0, 0x28, 0x1f, 0x8b, 0x4d, 0x75, 0x4b, 0xbd, 0x8b, 0x8a, 0x70, 0x3e,
    0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1,
    0x1d, 0x9e, 0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e,
    0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf, 0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6,
    0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
  ];

  static const _rcon = [
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36,
  ];
}
