import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/chat_message_search.dart';

/// In-conversation search: the chat screen flattens each resident row to
/// bounded plain text and matches against it. These tests pin the parts a
/// wrong implementation would silently get wrong — tool payloads and sidechain
/// children being searchable, control rows being skipped, snippets staying
/// readable, and the character budget actually bounding memory.

Map<String, dynamic> _textRow(String id, String content, {String? localId}) =>
    <String, dynamic>{
      'id': id,
      if (localId != null) 'localId': localId,
      'seq': 1,
      'createdAt': 1700000000000,
      'role': 'agent',
      'kind': 'text',
      'content': content,
    };

void main() {
  test('matches message content case-insensitively', () {
    final messages = [
      _textRow('a', 'Renderer RCE is proven'),
      _textRow('b', 'nothing to see here'),
    ];

    final matches = searchChatMessages(messages, 'renderer rce');

    expect(matches, hasLength(1));
    expect(matches.single.key, 'a');
    expect(matches.single.snippet, contains('Renderer RCE'));
  });

  test('matches tool input, result and tool name', () {
    final tool = <String, dynamic>{
      'id': 't1',
      'seq': 2,
      'createdAt': 1700000000001,
      'role': 'agent',
      'kind': 'tool-call',
      'name': 'Bash',
      'input': <String, dynamic>{'command': 'rg exfat_get_uniname'},
      'result': <String, dynamic>{'stdout': 'kernel/exfat_namei.c:441'},
    };

    expect(searchChatMessages([tool], 'exfat_get_uniname'), hasLength(1));
    expect(searchChatMessages([tool], 'kernel/exfat_namei'), hasLength(1));
    expect(searchChatMessages([tool], 'Bash'), hasLength(1));
    // Payload *keys* are not indexed — only values a user can read. Indexing
    // keys would make `stdout` hit every Bash row in the session.
    expect(searchChatMessages([tool], 'stdout'), isEmpty);
  });

  test('searches sidechain children under their parent row key', () {
    // Children are rendered inline under the Task row, so revealing the
    // parent is the only thing the chat list can do — the match must carry
    // the parent's key, never a child id the list has no index for.
    final task = <String, dynamic>{
      'id': 'task-1',
      'seq': 5,
      'createdAt': 1700000000005,
      'role': 'agent',
      'kind': 'tool-call',
      'name': 'Task',
      'children': <Map<String, dynamic>>[
        _textRow('child-1', 'the orphan parent is missing'),
      ],
    };

    final matches = searchChatMessages([task], 'orphan parent');

    expect(matches, hasLength(1));
    expect(matches.single.key, 'task-1');
  });

  test('an optimistic row is found by its localId key', () {
    final optimistic = <String, dynamic>{
      'id': 'local-1',
      'localId': 'local-1',
      'seq': 0,
      'createdAt': 1700000000000,
      'role': 'user',
      'kind': 'text',
      'content': 'Is the chain proven yet?',
    };

    final matches = searchChatMessages([optimistic], 'chain proven');

    expect(matches.single.key, 'local-1');
  });

  test('control rows and keyless rows are skipped', () {
    final messages = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'divider-1',
        'kind': 'model-change',
        'fromModel': 'deepseek-flash',
        'toModel': 'fable',
      },
      <String, dynamic>{'kind': 'text', 'content': 'deepseek-flash'},
    ];

    expect(searchChatMessages(messages, 'deepseek-flash'), isEmpty);
  });

  test('an empty or whitespace query matches nothing', () {
    final messages = [_textRow('a', 'anything')];

    expect(searchChatMessages(messages, ''), isEmpty);
    expect(searchChatMessages(messages, '   '), isEmpty);
  });

  test('each row contributes at most one match', () {
    final messages = [_textRow('a', 'needle needle needle')];

    expect(searchChatMessages(messages, 'needle'), hasLength(1));
  });

  test('matches come back in transcript order', () {
    final messages = [
      _textRow('a', 'needle first'),
      _textRow('b', 'not it'),
      _textRow('c', 'needle second'),
    ];

    expect(
      searchChatMessages(messages, 'needle').map((m) => m.key),
      ['a', 'c'],
    );
  });

  test('snippets collapse whitespace and mark truncation', () {
    final messages = [
      _textRow(
        'a',
        '${'x' * 200}\n\n  the needle\tis here  \n${'y' * 200}',
      ),
    ];

    final snippet = searchChatMessages(messages, 'needle').single.snippet;

    expect(snippet, contains('the needle is here'));
    expect(snippet.contains('\n'), isFalse);
    expect(snippet.startsWith('…'), isTrue);
    expect(snippet.endsWith('…'), isTrue);
  });

  test('the per-row text budget bounds what a huge tool output costs', () {
    final huge = <String, dynamic>{
      'id': 'big',
      'kind': 'tool-call',
      'name': 'Bash',
      'result': <String, dynamic>{'stdout': 'a' * 100000 + 'needle'},
    };

    final text = chatMessageSearchText(huge, maxChars: 100);

    expect(text.length, lessThanOrEqualTo(101));
    expect(text, isNot(contains('needle')));
  });

  test('the prebuilt index and the one-shot helper agree', () {
    final messages = [_textRow('a', 'alpha'), _textRow('b', 'beta')];

    final indexed = findChatSearchMatches(
      'beta',
      index: buildChatSearchIndex(messages),
    );

    expect(indexed.single.key, searchChatMessages(messages, 'beta').single.key);
  });

  group('grapheme safety', () {
    // U+1F600: one grapheme, two UTF-16 code units.
    const emoji = '\u{1F600}';

    test('a hit beside emoji yields a well-formed snippet', () {
      // The radius counts user-perceived characters, not UTF-16 units.
      final messages = [_textRow('a', '${emoji * 45}needle${emoji * 45}')];

      final snippet = searchChatMessages(messages, 'needle').single.snippet;

      expect(_hasLoneSurrogate(snippet), isFalse);
      expect(snippet, contains('needle'));
      expect(snippet, contains(emoji));
    });

    test('snippet edges land on grapheme boundaries', () {
      for (final cluster in [emoji, 'é', '👩🏽‍💻', '🇮🇹']) {
        final before = cluster * 45;
        final text = '${before}needle${cluster * 45}';
        final snippet = buildSearchSnippet(text, before.length, 6);

        expect(_hasLoneSurrogate(snippet), isFalse);
        expect(snippet, '…${cluster * 40}needle${cluster * 40}…');
      }
    });

    test('a partial grapheme hit includes its whole cluster', () {
      const cluster = '👩🏽‍💻';
      final text = '${'a' * 50}$cluster${'b' * 50}';
      final snippet = buildSearchSnippet(text, 52, 2);

      expect(snippet, '…${'a' * 40}$cluster${'b' * 40}…');
    });

    test('the per-row text budget never splits a surrogate pair', () {
      final huge = <String, dynamic>{
        'id': 'big',
        'kind': 'tool-call',
        'name': 'Bash',
        'result': <String, dynamic>{'stdout': '${emoji * 60}needle'},
      };

      final text = chatMessageSearchText(huge, maxChars: 101);

      expect(_hasLoneSurrogate(text), isFalse);
      expect(text.length, lessThanOrEqualTo(102));
      expect(text, isNot(contains('needle')));
    });
  });
}

/// True when [text] contains a high surrogate with no following low one, or
/// a low surrogate with no preceding high one — the exact malformation
/// Flutter's text layout rejects with `string is not well-formed UTF-16`.
bool _hasLoneSurrogate(String text) {
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 >= text.length) return true;
      final next = text.codeUnitAt(i + 1);
      if (next < 0xDC00 || next > 0xDFFF) return true;
      i++; // consume the pair
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return true;
    }
  }
  return false;
}
