import 'package:sodium/sodium.dart' show Sodium;
import 'package:sodium_libs/sodium_libs.dart' show SodiumInit;

Future<Sodium> loadSodium() => SodiumInit.init();
