import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

import 'helpers/fake_mmkv_platform.dart';

/// Global test configuration — ensures google_fonts uses the bundled
/// TTF assets in `google_fonts/` instead of attempting runtime downloads,
/// so golden screenshots render real text instead of "Ahem" blocks.
///
/// Also loads Roboto Mono as `monospace` since widgets reference that
/// generic family name directly via `fontFamily: 'monospace'`.
///
/// And registers a no-op [FakeMmkvPlatform] on
/// [MMKVPluginPlatform.instance] so `MMKV.initialize()` /
/// `MMKV.defaultMMKV()` calls in the code under test don't crash with
/// `Null check operator used on a null value` from the real FFI plugin
/// (which is unavailable in the `flutter test` environment).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  MMKVPluginPlatform.instance = FakeMmkvPlatform();
  await _loadMonospaceFont();
  await testMain();
}

/// Loads Roboto Mono TTF files from `test_fonts/` and registers them
/// under the family name `monospace` so that widgets using
/// `fontFamily: 'monospace'` render real glyphs in tests. Production
/// builds rely on the platform's built-in monospace font (Roboto Mono
/// on Android, SF Mono on iOS), so the TTFs live outside the asset
/// bundle.
Future<void> _loadMonospaceFont() async {
  final fontsDir = Directory('test_fonts');
  if (!fontsDir.existsSync()) return;

  final loader = FontLoader('monospace');
  final files = fontsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.ttf'));

  for (final file in files) {
    final bytes = file.readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(bytes.buffer)),
    );
  }

  await loader.load();
}
