import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

import 'helpers/fake_mmkv_platform.dart';

/// Global test configuration — loads bundled TTF assets so golden screenshots
/// render real text instead of "Ahem" blocks.
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
  MMKVPluginPlatform.instance = FakeMmkvPlatform();
  await _loadInterFont();
  await _loadMonospaceFont();
  await _loadMaterialIconsFont();
  await testMain();
}

/// Loads the Material icon font from the Flutter SDK cache so `Icon()`
/// glyphs render in golden screenshots instead of tofu boxes. The test
/// harness only auto-loads Ahem; `FLUTTER_ROOT` is set by `flutter test`.
Future<void> _loadMaterialIconsFont() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  await _loadFontFile(
    family: 'MaterialIcons',
    path:
        '$flutterRoot/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf',
  );
}

/// Loads the app's bundled Inter TTF files under the family name used by
/// ThemeHelper. Production builds load these through pubspec font declarations.
Future<void> _loadInterFont() async {
  await _loadFontsFromDirectory(family: 'Inter', directoryPath: 'google_fonts');
  await _loadFontFile(
    family: 'Inter_regular',
    path: 'google_fonts/Inter-Regular.ttf',
  );
  await _loadFontFile(
    family: 'Inter_500',
    path: 'google_fonts/Inter-Medium.ttf',
  );
  await _loadFontFile(
    family: 'Inter_600',
    path: 'google_fonts/Inter-SemiBold.ttf',
  );
  await _loadFontFile(
    family: 'Inter_700',
    path: 'google_fonts/Inter-Bold.ttf',
  );
}

/// Loads Roboto Mono TTF files from `test_fonts/` and registers them
/// under the family name `monospace` so that widgets using
/// `fontFamily: 'monospace'` render real glyphs in tests. Production
/// builds rely on the platform's built-in monospace font (Roboto Mono
/// on Android, SF Mono on iOS), so the TTFs live outside the asset
/// bundle.
Future<void> _loadMonospaceFont() async {
  await _loadFontsFromDirectory(
    family: 'monospace',
    directoryPath: 'test_fonts',
  );
}

Future<void> _loadFontsFromDirectory({
  required String family,
  required String directoryPath,
}) async {
  final fontsDir = Directory(directoryPath);
  if (!fontsDir.existsSync()) return;

  final loader = FontLoader(family);
  final files = fontsDir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.ttf'),
  );

  for (final file in files) {
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }

  await loader.load();
}

Future<void> _loadFontFile({
  required String family,
  required String path,
}) async {
  final file = File(path);
  if (!file.existsSync()) return;

  final loader = FontLoader(family);
  final bytes = file.readAsBytesSync();
  loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}
