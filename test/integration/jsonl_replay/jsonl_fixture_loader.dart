// Loads real Claude Code .jsonl transcripts from the local machine and
// converts each line into the wire shape that
// `processDecryptedMessages` consumes.
//
// Transcripts live at ~/.claude/projects/<encoded-path>/<sessionId>.jsonl
// with sidechain sub-agent files under
// ~/.claude/projects/<encoded-path>/<sessionId>/subagents/agent-*.jsonl
//
// This loader is intentionally kept out of production code — tests that
// rely on these fixtures must guard on [FixtureBundle.isAvailable] so CI
// (and any machine without local transcripts) skips gracefully.
library;

import 'dart:convert';
import 'dart:io';

/// One parsed line from a .jsonl transcript plus the wire envelope that
/// the Flutter parser expects to receive after decryption.
class JsonlLine {
  JsonlLine({
    required this.raw,
    required this.wireMessage,
    required this.plaintext,
  });

  /// The raw JSON object from the .jsonl file, unchanged.
  final Map<String, dynamic> raw;

  /// Wire envelope — the entry that goes into `wireMessages`.
  final Map<String, dynamic> wireMessage;

  /// Plaintext content — the entry that goes into `decryptedJsonList`.
  final Map<String, dynamic>? plaintext;

  String get type => raw['type'] as String? ?? '';
  bool get isSidechain => raw['isSidechain'] == true;
  bool get isForwarded => plaintext != null;
}

/// Types that Claude Code writes to .jsonl but happy-cli-go does not
/// forward to the server. Tests must not count these as "expected
/// rendered messages" because they never reach the Flutter parser.
const Set<String> cliLocalTypes = {
  'attachment',
  'last-prompt',
  'queue-operation',
  'ai-title',
};

/// Wraps one raw .jsonl object in the `{role, content: {type, data}}`
/// envelope produced by happy-cli-go. Returns `null` for CLI-local
/// types that are never forwarded.
Map<String, dynamic>? wrapJsonlLine(Map<String, dynamic> raw) {
  final type = raw['type'] as String? ?? '';
  if (cliLocalTypes.contains(type)) return null;
  return <String, dynamic>{
    'role': 'agent',
    'content': <String, dynamic>{
      'type': 'output',
      'data': raw,
    },
  };
}

/// Loads and wraps every line of a .jsonl file.
List<JsonlLine> loadJsonl(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final lines = file.readAsLinesSync();
  final out = <JsonlLine>[];
  var seq = 0;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, dynamic>) continue;
    final plaintext = wrapJsonlLine(decoded);
    final createdAt = _parseTimestamp(decoded['timestamp']);
    final wire = <String, dynamic>{
      'id': 'fx_${seq.toString().padLeft(6, '0')}',
      'seq': seq,
      'createdAt': createdAt,
      // Not base64 — the fake path writes plaintext directly.
      'content': plaintext,
    };
    out.add(JsonlLine(raw: decoded, wireMessage: wire, plaintext: plaintext));
    seq++;
  }
  return out;
}

int _parseTimestamp(dynamic raw) {
  if (raw is int) return raw;
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return 0;
}

/// A bundle of fixture paths for a single Claude Code session — the main
/// transcript plus any sidechain sub-agent files under `subagents/`.
class FixtureBundle {
  FixtureBundle({
    required this.label,
    required this.mainPath,
    required this.sidechainPaths,
  });

  final String label;
  final String mainPath;
  final List<String> sidechainPaths;

  bool get isAvailable => File(mainPath).existsSync();

  /// All lines from the main transcript.
  List<JsonlLine> loadMain() => loadJsonl(mainPath);

  /// All lines from every sidechain file, flattened.
  List<JsonlLine> loadSidechains() {
    final out = <JsonlLine>[];
    for (final p in sidechainPaths) {
      out.addAll(loadJsonl(p));
    }
    return out;
  }

  /// Known-good bundles used by the contract tests.
  static FixtureBundle happyFlutterInterrupts() {
    const base =
        '/home/workspace/.claude/projects/-home-workspace-git-happy-flutter';
    return FixtureBundle(
      label: 'happy_flutter interrupts + api errors',
      mainPath: '$base/0d2a4f91-7969-4c04-9c22-62bce4319308.jsonl',
      sidechainPaths: const [],
    );
  }

  static FixtureBundle gpsTrackerSidechain() {
    const base =
        '/home/workspace/.claude/projects/-home-workspace-git-gps-tracker';
    const session = 'cdbe1b65-4713-4ea2-b32a-fbb14aa3abf9';
    final subagents = Directory('$base/$session/subagents');
    final sidechainPaths = subagents.existsSync()
        ? subagents
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.jsonl'))
            .map((f) => f.path)
            .toList()
        : <String>[];
    return FixtureBundle(
      label: 'gps-tracker main + subagents',
      mainPath: '$base/$session.jsonl',
      sidechainPaths: sidechainPaths,
    );
  }
}
