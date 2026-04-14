import 'package:sodium/sodium.dart' show Sodium;
import 'package:sodium_libs/sodium_libs.dart' show SodiumInit;

Future<Sodium> loadSodium() async {
  final sodium = await SodiumInit.init();
  return sodium;
}
