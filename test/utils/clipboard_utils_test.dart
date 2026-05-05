import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/clipboard_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<Object?, Object?>;
        clipboardText = args['text']! as String;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('setClipboardTextSafely', () {
    test('copies text below the byte limit unchanged', () async {
      final result = await setClipboardTextSafely('short', maxBytes: 16);

      expect(result.success, isTrue);
      expect(result.truncated, isFalse);
      expect(result.charactersCopied, 5);
      expect(result.originalCharacters, 5);
      expect(clipboardText, 'short');
    });

    test('truncates to the configured byte limit', () async {
      final result = await setClipboardTextSafely(
        'abcdef',
        maxBytes: 4,
      );

      expect(result.success, isTrue);
      expect(result.truncated, isTrue);
      expect(result.charactersCopied, 4);
      expect(result.originalCharacters, 6);
      expect(clipboardText, 'abcd');
      expect(utf8.encode(clipboardText!).length, lessThanOrEqualTo(4));
    });

    test('does not split multi-byte code points', () async {
      final result = await setClipboardTextSafely(
        'ab🙂cd',
        maxBytes: 5,
      );

      expect(result.success, isTrue);
      expect(result.truncated, isTrue);
      expect(clipboardText, 'ab');
      expect(utf8.encode(clipboardText!).length, lessThanOrEqualTo(5));
    });

    test('adds a truncation marker when it fits', () async {
      final text = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final result = await setClipboardTextSafely(text, maxBytes: 32);

      expect(result.success, isTrue);
      expect(result.truncated, isTrue);
      expect(clipboardText, endsWith('[truncated for clipboard]'));
      expect(utf8.encode(clipboardText!).length, lessThanOrEqualTo(32));
    });
  });
}
