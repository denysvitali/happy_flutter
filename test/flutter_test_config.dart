import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test configuration — ensures google_fonts uses the bundled
/// TTF assets in `google_fonts/` instead of attempting runtime downloads,
/// so golden screenshots render real text instead of "Ahem" blocks.
///
/// Also loads Roboto Mono as `monospace` since widgets reference that
/// generic family name directly via `fontFamily: 'monospace'`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await _loadMonospaceFont();
  await testMain();
}

/// Loads Roboto Mono TTF files from `google_fonts/` and registers them
/// under the family name `monospace` so that widgets using
/// `fontFamily: 'monospace'` render real glyphs in tests.
Future<void> _loadMonospaceFont() async {
  final fontsDir = Directory('google_fonts');
  if (!fontsDir.existsSync()) return;

  final loader = FontLoader('monospace');
  final files = fontsDir
      .listSync()
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.ttf') &&
            f.uri.pathSegments.last.startsWith('RobotoMono'),
      );

  for (final file in files) {
    final bytes = file.readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(bytes.buffer)),
    );
  }

  await loader.load();
}
