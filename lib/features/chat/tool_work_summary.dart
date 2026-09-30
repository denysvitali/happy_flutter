import '../../core/i18n/app_localizations.dart';
import '../../core/utils/tool_result_parser.dart';
import '../../core/wire/wire_parsers.dart';
import 'tools/known_tools.dart';
import 'tools/tool_view_helpers.dart';

/// A factual presentation of recorded tool work, never a test-pass inference.
class ToolWorkSummary {
  ToolWorkSummary.fromTools(Iterable<Map<String, dynamic>> tools) {
    for (final tool in tools) {
      final state = tool['state'];
      final name = family(tool);
      if (isCommand(name)) commandTools.add(tool);
      final permission = WireParsers.asMap(tool['permission']);
      if (isPermissionPending(permission)) approvals++;
      final exitCode = isCommand(name) && state == 'completed'
          ? parseExitCode(tool['result'])
          : null;
      if (state == 'error' || (exitCode != null && exitCode != 0)) {
        failures.add(tool);
      } else if (state == 'canceled') {
        canceled++;
      } else if (state != 'completed') {
        pending++;
        if (state == 'running') {
          running++;
          activeTool = tool;
        }
      } else if (name == 'read') {
        final paths = filePaths(tool).toList();
        if (paths.isEmpty) {
          _readsWithoutPath++;
        } else {
          _readPaths.addAll(paths);
        }
      } else if (isEdit(name)) {
        final paths = filePaths(tool).toList();
        if (paths.isEmpty) editsWithoutPath++;
        for (final path in paths) {
          changedFiles[path] = tool;
        }
      } else if (isCommand(name)) {
        commands++;
      } else {
        otherCompleted++;
      }
    }
  }

  final changedFiles = <String, Map<String, dynamic>>{};
  final _readPaths = <String>{};
  final failures = <Map<String, dynamic>>[];
  final commandTools = <Map<String, dynamic>>[];
  int _readsWithoutPath = 0;
  int editsWithoutPath = 0;
  int commands = 0;
  int otherCompleted = 0;
  int pending = 0;
  int running = 0;
  int canceled = 0;
  int approvals = 0;
  Map<String, dynamic>? activeTool;

  int get readFiles => _readPaths.length + _readsWithoutPath;
  int get failed => failures.length;

  static String family(Map<String, dynamic> tool) {
    final raw = tool['name'];
    return KnownTools.canonicalName(raw is String ? raw : '').toLowerCase();
  }

  static bool isEdit(String name) => const {
    'edit',
    'write',
    'multiedit',
    'codexpatch',
    'codexdiff',
    'geminiedit',
    'replace',
    'write_file',
    'edit_file',
  }.contains(name);

  static bool isCommand(String name) => const {
    'bash',
    'codexbash',
    'exec_command',
    'geminiexecute',
    'shell',
    'execute',
    'ssh_execute',
  }.contains(name);

  static Iterable<String> filePaths(Map<String, dynamic> tool) sync* {
    final input = WireParsers.asMap(tool['input']);
    if (input != null) {
      for (final key in ['file_path', 'filePath', 'target_file', 'path']) {
        final path = input[key];
        if (path is String && path.trim().isNotEmpty) {
          yield path;
          break;
        }
      }
    }
    if (family(tool) != 'codexpatch' && family(tool) != 'codexdiff') return;
    for (final source in [tool['input'], tool['result'], tool['content']]) {
      final map = WireParsers.asMap(source);
      final changes = map?['changes'];
      if (changes is Map) {
        final path = changes['path'] ?? changes['file_path'];
        if (path is String && path.isNotEmpty) {
          yield path;
        } else {
          for (final key in changes.keys.whereType<String>()) {
            if (key.isNotEmpty) yield key;
          }
        }
      } else if (changes is List) {
        for (final change in changes) {
          final data = WireParsers.asMap(change);
          final path = data?['path'] ?? data?['file_path'];
          if (path is String && path.isNotEmpty) yield path;
        }
      }
      final patch = map?['patch'] ?? map?['input'] ?? source;
      if (patch is String) {
        // Match headers only; never allocate the output as a line list.
        for (final match in RegExp(
          r'^\*\*\* (?:Update|Add|Delete) File: (.+)$',
          multiLine: true,
        ).allMatches(patch)) {
          yield match.group(1)!.trim();
        }
      }
    }
  }

  String describe(AppLocalizations l10n) => [
    if (readFiles > 0) l10n.chatWorkReadFiles(readFiles),
    if (changedFiles.isNotEmpty) l10n.chatWorkEditedFiles(changedFiles.length),
    if (editsWithoutPath > 0) l10n.chatWorkEdits(editsWithoutPath),
    if (commands > 0) l10n.chatWorkCommands(commands),
    if (otherCompleted > 0) l10n.chatWorkOther(otherCompleted),
    if (failed > 0) l10n.chatWorkFailed(failed),
    if (pending > 0) l10n.chatWorkPending(pending),
    if (canceled > 0) l10n.chatWorkCanceled(canceled),
    if (approvals > 0) l10n.chatWorkApprovals(approvals),
  ].join(' · ');

  String? activityLabel(AppLocalizations l10n) {
    final tool = activeTool;
    if (tool == null) return null;
    final name = family(tool);
    if (isEdit(name)) return l10n.chatWorkEditing;
    if (name == 'read') return l10n.chatWorkReading;
    if (isCommand(name)) return l10n.chatWorkRunningCommands;
    if (const {'grep', 'glob', 'ls', 'websearch', 'webfetch'}.contains(name)) {
      return l10n.chatWorkSearching;
    }
    return l10n.chatWorkUsing(
      tool['name'] is String ? tool['name'] as String : l10n.chatWorkTools,
    );
  }
}

/// The latest resident turn only. Earlier answers and child answers cannot
/// become the current turn's result. No durable messages are changed.
class ChatTurnWork {
  ChatTurnWork._(this.summary, this.answer, this.startedAt);
  factory ChatTurnWork.fromMessages(List<Map<String, dynamic>> messages) {
    var start = (messages.length - 1000).clamp(0, messages.length);
    int? startedAt;
    for (var i = messages.length - 1; i >= start; i--) {
      final message = messages[i];
      if (message['role'] == 'user' && message['isSidechain'] != true) {
        start = i + 1;
        final timestamp = message['createdAt'];
        if (timestamp is num) startedAt = timestamp.toInt();
        break;
      }
    }
    final tools = <Map<String, dynamic>>[];
    Map<String, dynamic>? answer;
    for (var i = start; i < messages.length; i++) {
      final message = messages[i];
      if (message['kind'] == 'tool-call') tools.add(message);
      if (message['isSidechain'] == true || message['isThinking'] == true) {
        continue;
      }
      final content = message['content'];
      if ((message['role'] == 'agent' || message['role'] == 'assistant') &&
          (message['kind'] == 'text' || message['kind'] == null) &&
          content is String &&
          content.trim().isNotEmpty) {
        answer = message;
      }
    }
    return ChatTurnWork._(ToolWorkSummary.fromTools(tools), answer, startedAt);
  }

  final ToolWorkSummary summary;
  final Map<String, dynamic>? answer;
  final int? startedAt;
  bool get hasResult =>
      answer != null ||
      summary.failed > 0 ||
      summary.changedFiles.isNotEmpty ||
      summary.commands > 0;
}
