import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:happy_flutter/core/encryption/encryptor.dart';

/// Deterministic fixture generators producing production-shaped wire data:
/// encrypted envelopes (`{'t': 'encrypted', 'c': <b64>}`), session rows,
/// and mixed Claude-Code-style transcripts (user/assistant/tool traffic).
final math.Random _rng = math.Random(1337);

const List<String> _words = <String>[
  'session', 'artifact', 'machine', 'profile', 'sync', 'message',
  'cache', 'socket', 'retry', 'outbox', 'workspace', 'agent',
  'transcript', 'projection', 'cursor', 'envelope', 'decrypt',
  'heartbeat', 'spawn', 'terminal',
];

String _text(int chars) {
  final buf = StringBuffer();
  var len = 0;
  while (len < chars) {
    final w = _words[_rng.nextInt(_words.length)];
    buf.write(w);
    buf.write(' ');
    len += w.length + 1;
  }
  return buf.toString().substring(0, math.min(chars, buf.length - 1));
}

/// Public deterministic filler text of roughly [chars] length.
String benchText(int chars) => _text(chars);

/// Output block with ANSI color escapes interleaved, mimicking shell
/// tool results that exercise the ANSI parser.
String ansiToolOutput(int chars) {
  final buf = StringBuffer();
  const codes = <String>['\x1b[32m', '\x1b[33m', '\x1b[31m', '\x1b[36m'];
  var written = 0;
  while (written < chars) {
    final code = codes[_rng.nextInt(codes.length)];
    final chunk = _text(math.min(120, chars - written));
    buf
      ..write(code)
      ..write(chunk)
      ..write('\x1b[0m\n');
    written += chunk.length + 6;
  }
  return buf.toString();
}

/// A wire envelope plus the plaintext body its ciphertext decrypts to —
/// exactly the (wireMessages, decryptedJsonList) pair that
/// `processDecryptedMessages` consumes.
class WirePair {
  WirePair({required this.wire, required this.plain});

  final Map<String, dynamic> wire;
  final dynamic plain;
}

Map<String, dynamic> _envelope(
  String id,
  int seq,
  String role,
  dynamic plain,
) {
  final jsonStr = jsonEncode(plain);
  final bytes = utf8.encode(jsonStr);
  final output = Uint8List(bytes.length + 1);
  output[0] = 0x01;
  output.setRange(1, output.length, bytes);
  return <String, dynamic>{
    'id': id,
    'seq': seq,
    'role': role,
    'content': <String, dynamic>{'t': 'encrypted', 'c': base64Encode(output)},
    'createdAt': 1700000000000 + seq * 1000,
  };
}

dynamic _bodyForRoll(int roll) {
  if (roll < 20) {
    return <String, dynamic>{
      'role': 'user',
      'content': <String, dynamic>{
        'type': 'text',
        'text': _text(60 + _rng.nextInt(140)),
      },
    };
  }
  if (roll < 55) {
    return <String, dynamic>{
      'role': 'assistant',
      'content': <String, dynamic>{
        'type': 'text',
        'text': _text(400 + _rng.nextInt(2000)),
      },
    };
  }
  if (roll < 75) {
    return <String, dynamic>{
      'role': 'assistant',
      'content': <String, dynamic>{
        'type': 'tool_use',
        'id': 'toolu_${_rng.nextInt(1 << 31).toRadixString(16)}',
        'name': ['Read', 'Bash', 'Edit'][_rng.nextInt(3)],
        'input': <String, dynamic>{
          'file_path':
              '/home/workspace/git/happy_flutter/lib/core/services/sync_service.dart',
          'command': 'rg -n "handleUpdate" lib/core/services | head -20',
          'content': _text(300 + _rng.nextInt(1500)),
        },
      },
    };
  }
  return <String, dynamic>{
    'role': 'agent',
    'content': <String, dynamic>{
      'type': 'codex',
      'data': <String, dynamic>{
        'type': 'message',
        'message': _text(100 + _rng.nextInt(600)),
      },
    },
  };
}

/// A realistic mixed transcript of [count] encrypted wire messages with
/// their plaintext bodies.
///
/// Distribution mirrors an active Claude Code session: short user turns,
/// longer assistant prose, tool_use calls, and large ANSI-laden tool
/// results. Seqs start at 1.
List<WirePair> makeTranscriptPairs(int count) {
  final pairs = <WirePair>[];
  var pendingCallId = '';
  for (var i = 0; i < count; i++) {
    final seq = i + 1;
    var roll = _rng.nextInt(100);
    // Pair most pending tool uses with a large ANSI result next.
    if (pendingCallId.isNotEmpty && roll >= 75 && _rng.nextBool()) {
      final plain = <String, dynamic>{
        'role': 'user',
        'content': <String, dynamic>{
          'type': 'tool_result',
          'tool_use_id': pendingCallId,
          'output': ansiToolOutput(2000 + _rng.nextInt(18000)),
          'isError': false,
        },
      };
      pendingCallId = '';
      roll = -1;
      pairs.add(WirePair(
        wire: _envelope('bench-r-$seq', seq, 'user', plain),
        plain: plain,
      ));
      continue;
    }
    final plain = _bodyForRoll(roll);
    if (roll >= 55 && roll < 75) {
      // tool_use body: remember its call id so the next row can be its result
      final content = (plain['content'] as Map<String, dynamic>);
      pendingCallId = content['id'] as String;
    }
    final role = switch (plain['role'] as String?) {
      null => 'agent',
      'assistant' => 'assistant',
      _ => 'user',
    };
    pairs.add(WirePair(
      wire: _envelope('bench-m-$seq', seq, role, plain),
      plain: plain,
    ));
  }
  return pairs;
}

/// Wire envelopes only ([makeTranscriptPairs] projected).
List<Map<String, dynamic>> makeTranscript(int count) =>
    makeTranscriptPairs(count).map((p) => p.wire).toList();

/// Real AES-256-GCM wire rows (`0x00` version byte, like production) for
/// the same transcript, encrypted with [key].
Future<List<Map<String, dynamic>>> makeAesTranscript(
  int count,
  Uint8List key,
) async {
  final pairs = makeTranscriptPairs(count);
  final encryptor = AES256Encryption(key);
  final ciphers =
      await encryptor.encrypt(pairs.map((p) => p.plain).toList());
  final rows = <Map<String, dynamic>>[];
  for (var i = 0; i < pairs.length; i++) {
    final w = Map<String, dynamic>.of(pairs[i].wire);
    w['content'] = <String, dynamic>{
      't': 'encrypted',
      'c': base64Encode(ciphers[i]),
    };
    rows.add(w);
  }
  return rows;
}

/// Wire-shape session rows spread across [workspaces] workspaces with
/// varied presence/thinking/activity, for collection benchmarks.
List<Map<String, dynamic>> makeSessionRows(
  int count, {
  int workspaces = 8,
}) {
  final rows = <Map<String, dynamic>>[];
  for (var i = 0; i < count; i++) {
    final online = _rng.nextInt(10) == 0;
    final thinking = online && _rng.nextInt(3) == 0;
    rows.add(<String, dynamic>{
      'id': 'sess-bench-$i',
      'seq': 1000 + i,
      'createdAt': 1700000000000 + i * 3600 * 1000,
      'updatedAt': 1700100000000 + i * 61 * 1000,
      'active': true,
      'activeAt': 1700100000000 + i * 61 * 1000,
      'metadataVersion': 1,
      'agentStateVersion': 1,
      'thinking': thinking,
      'presence': online ? 'online' : 'offline',
      'lastSeq': 2000 + i * 7,
      'metadata': <String, dynamic>{
        'path': '/home/workspace/git/repo-${i % workspaces}',
        'name': 'repo-${i % workspaces}',
      },
    });
  }
  return rows;
}
