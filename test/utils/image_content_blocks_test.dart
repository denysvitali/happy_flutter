import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/image_content_blocks.dart';

void main() {
  group('stripInlineImageData', () {
    test('returns message unchanged when no image blocks present', () {
      final message = <String, dynamic>{
        'id': 'm1',
        'content': 'hello',
        'raw': <String, dynamic>{
          'role': 'user',
          'content': <String, dynamic>{'type': 'text', 'text': 'hello'},
        },
      };

      final result = stripInlineImageData(message);
      expect(identical(result, message), isTrue);
    });

    test('returns message unchanged when raw content is not a list', () {
      final message = <String, dynamic>{
        'id': 'm1',
        'raw': <String, dynamic>{'role': 'user', 'content': 'plain'},
      };

      final result = stripInlineImageData(message);
      expect(identical(result, message), isTrue);
    });

    test('hollows base64 image data and marks it omitted', () {
      final message = <String, dynamic>{
        'id': 'm1',
        'content': '[image]',
        'raw': <String, dynamic>{
          'role': 'user',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': 'look'},
            <String, dynamic>{
              'type': 'image',
              'source': <String, dynamic>{
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': 'aGVsbG8=',
              },
            },
          ],
        },
      };

      final result = stripInlineImageData(message);
      expect(identical(result, message), isFalse);

      // Original message must not be mutated (it is the live
      // in-memory copy that retry/outbox still need intact).
      final originalContent =
          (message['raw'] as Map<String, dynamic>)['content'] as List<dynamic>;
      expect(
        ((originalContent[1] as Map<String, dynamic>)['source']
            as Map<String, dynamic>)['data'],
        'aGVsbG8=',
      );

      final raw = result['raw'] as Map<String, dynamic>;
      final content = raw['content'] as List<dynamic>;
      expect((content[0] as Map<String, dynamic>)['text'], 'look');
      final source =
          (content[1] as Map<String, dynamic>)['source']
              as Map<String, dynamic>;
      expect(source['data'], '');
      expect(source['omitted'], isTrue);
      expect(source['media_type'], 'image/jpeg');
    });

    test('leaves url-source image blocks untouched', () {
      final message = <String, dynamic>{
        'id': 'm1',
        'raw': <String, dynamic>{
          'role': 'user',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'image',
              'source': <String, dynamic>{
                'type': 'url',
                'url': 'https://example.com/x.png',
              },
            },
          ],
        },
      };

      final result = stripInlineImageData(message);
      expect(identical(result, message), isTrue);
    });
  });

  group('hasStrippedImageBlocks', () {
    test('false for plain text content', () {
      expect(
        hasStrippedImageBlocks(<String, dynamic>{
          'content': <String, dynamic>{'type': 'text', 'text': 'hi'},
        }),
        isFalse,
      );
    });

    test('false for intact base64 image', () {
      expect(
        hasStrippedImageBlocks(<String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'image',
              'source': <String, dynamic>{
                'type': 'base64',
                'media_type': 'image/png',
                'data': 'aW1n',
              },
            },
          ],
        }),
        isFalse,
      );
    });

    test('true for omitted marker', () {
      expect(
        hasStrippedImageBlocks(<String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'image',
              'source': <String, dynamic>{
                'type': 'base64',
                'media_type': 'image/png',
                'data': '',
                'omitted': true,
              },
            },
          ],
        }),
        isTrue,
      );
    });

    test('true for empty data without marker', () {
      expect(
        hasStrippedImageBlocks(<String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'image',
              'source': <String, dynamic>{
                'type': 'base64',
                'media_type': 'image/png',
                'data': '',
              },
            },
          ],
        }),
        isTrue,
      );
    });

    test('false for url-source image', () {
      expect(
        hasStrippedImageBlocks(<String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'image',
              'source': <String, dynamic>{
                'type': 'url',
                'url': 'https://example.com/x.png',
              },
            },
          ],
        }),
        isFalse,
      );
    });
  });

  group('strippedImageRefreshAfterSeq', () {
    test('returns the sequence before the earliest stripped image', () {
      final messages = <Map<String, dynamic>>[
        <String, dynamic>{
          'seq': 8,
          'raw': <String, dynamic>{
            'content': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'image',
                'source': <String, dynamic>{
                  'type': 'base64',
                  'data': '',
                  'omitted': true,
                },
              },
            ],
          },
        },
        <String, dynamic>{
          'seq': 4,
          'raw': <String, dynamic>{
            'content': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'image',
                'source': <String, dynamic>{'type': 'base64', 'data': ''},
              },
            ],
          },
        },
      ];

      expect(strippedImageRefreshAfterSeq(messages), 3);
    });

    test('returns null when all image data is intact', () {
      expect(
        strippedImageRefreshAfterSeq([
          <String, dynamic>{
            'seq': 4,
            'raw': <String, dynamic>{
              'content': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'image',
                  'source': <String, dynamic>{'type': 'base64', 'data': 'aW1n'},
                },
              ],
            },
          },
        ]),
        isNull,
      );
    });
  });
}
