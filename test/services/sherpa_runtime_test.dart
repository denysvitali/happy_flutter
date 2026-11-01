import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sherpa_runtime.dart';

String? _lockedVersion(String lock, String package) {
  return RegExp(
    '\\n  $package:\\n(?:    .*\\n)*?    version: "([^"]+)"',
  ).firstMatch(lock)?.group(1);
}

void main() {
  test('downloaded runtime matches the resolved sherpa_onnx packages', () {
    // Release APKs fetch native libraries pinned to this version; Dart
    // bindings from a different release would call a mismatched C ABI.
    final lock = File('pubspec.lock').readAsStringSync();
    expect(_lockedVersion(lock, 'sherpa_onnx'), SherpaRuntime.version);
    expect(
      _lockedVersion(lock, 'sherpa_onnx_android_arm64'),
      SherpaRuntime.version,
    );
    expect(
      SherpaRuntime.archiveUrl,
      endsWith('sherpa_onnx_android_arm64-${SherpaRuntime.version}.tar.gz'),
    );
  });

  test('runtime archive is pinned to a full SHA-256', () {
    expect(SherpaRuntime.archiveSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}
