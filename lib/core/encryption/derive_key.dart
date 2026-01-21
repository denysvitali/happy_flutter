import 'dart:typed_data';
import 'hmac_sha512.dart';
import 'text.dart';

/// Key tree state for hierarchical key derivation
class KeyTreeState {
  final Uint8List key;
  final Uint8List chainCode;

  KeyTreeState(this.key, this.chainCode);
}

/// Key derivation utilities using BIP32-like structure
class DeriveKey {
  /// Derive root key from seed
  static Future<KeyTreeState> deriveRoot(Uint8List seed, String usage) async {
    final usageBytes = TextUtils.encodeUtf8('$usage Master Seed');
    final I = await HmacSha512.compute(usageBytes, seed);

    return KeyTreeState(
      I.sublist(0, 32),
      I.sublist(32),
    );
  }

  /// Derive child key from chain code
  static Future<KeyTreeState> deriveChild(Uint8List chainCode, String index) async {
    // Prepare data: prepend 0x00 for separator
    final data = Uint8List(1 + index.length);
    data[0] = 0x00;
    data.setAll(1, TextUtils.encodeUtf8(index));

    // Derive key
    final I = await HmacSha512.compute(chainCode, data);

    return KeyTreeState(
      I.sublist(0, 32),
      I.sublist(32),
    );
  }

  /// Derive key from master with usage and path
  static Future<Uint8List> derive(
    Uint8List master,
    String usage,
    List<String> path,
  ) async {
    KeyTreeState state = await deriveRoot(master, usage);

    for (final index in path) {
      state = await deriveChild(state.chainCode, index);
    }

    return state.key;
  }
}
