import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:test/test.dart';

void main() {
  group('long speech chunking', () {
    test('keeps short text in one chunk', () {
      expect(TtsService.splitForSpeech('Short reply.'), ['Short reply.']);
    });

    test('splits long text at sentence boundaries', () {
      final chunks = TtsService.splitForSpeech(
        'First sentence. Second sentence. Third sentence.',
        maxChars: 32,
      );

      expect(chunks, [
        'First sentence.',
        'Second sentence.',
        'Third sentence.',
      ]);
      expect(
        chunks.join(' '),
        'First sentence. Second sentence. Third sentence.',
      );
    });

    test('hard-splits a long unbroken token', () {
      final chunks = TtsService.splitForSpeech('abcdefghij', maxChars: 4);
      expect(chunks, ['abcd', 'efgh', 'ij']);
    });
  });
}
