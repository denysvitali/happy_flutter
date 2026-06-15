// sodium 4.x consolidated the native bindings into the main `sodium`
// package (no more `sodium_libs`). `SodiumInit.init()` now loads the
// bundled libsodium assets via build-hooks.
import 'package:sodium/sodium.dart' show Sodium, SodiumInit;

Future<Sodium> loadSodium() async {
  final sodium = await SodiumInit.init();
  return sodium;
}
