import 'package:sodium/sodium.dart' show Sodium;

import 'sodium_loader.dart';

/// Shared Sodium instance — lazy-initialized once per app lifecycle.
///
/// Both [CryptoSecretBox] and [CryptoBox] use this singleton instead of
/// each maintaining their own `static Sodium?` field, which avoids loading
/// the native library twice and wasting memory.
final Future<Sodium> sodiumSingleton = loadSodium();
