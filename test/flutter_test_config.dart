import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

import 'helpers/fake_mmkv_platform.dart';

/// Global test configuration that loads the app font and registers a no-op
/// [FakeMmkvPlatform] on
/// [MMKVPluginPlatform.instance] so `MMKV.initialize()` /
/// `MMKV.defaultMMKV()` calls in the code under test don't crash with
/// `Null check operator used on a null value` from the real FFI plugin
/// (which is unavailable in the `flutter test` environment).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  MMKVPluginPlatform.instance = FakeMmkvPlatform();
  await _loadInterFont();
  await testMain();
}

/// Loads the app's bundled Inter files under the families used by ThemeHelper.
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
  await _loadFontFile(family: 'Inter_700', path: 'google_fonts/Inter-Bold.ttf');
}

Future<void> _loadFontsFromDirectory({
  required String family,
  required String directoryPath,
}) async {
  final fontsDir = Directory(directoryPath);
  if (!fontsDir.existsSync()) return;

  final loader = FontLoader(family);
  final files = fontsDir.listSync().whereType<File>().where(
    (file) => file.path.endsWith('.ttf'),
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
