import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';

import '../tool_section_view.dart';
import 'bash_view.dart' show CommandView;

/// Remote-shell result carried by an MCP tool (`mcp__ssh__ssh_execute` and
/// the other exec-shaped MCP tools).
///
/// The wire shape is an MCP content block whose `text` is *not* a string but
/// the exec record itself — `{stdout, stderr, exit_code, signal, success,
/// timed_out, binary_output}`. `mcpToolTextResult` rejects it (text is a Map),
/// so without this parser the call renders as a raw JSON dump: the user has to
/// read `"stdout": "REBOOT_SENT"` out of a nine-field blob instead of seeing a
/// terminal card.
class McpExecResult {
  const McpExecResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.success,
    required this.timedOut,
    required this.signalName,
    required this.binaryOutput,
  });

  /// Parses [result] when it carries an exec record, else returns null.
  ///
  /// Accepts the record directly, wrapped in MCP `content` blocks (top-level
  /// or under `result`), and with the block text as either a Map or a JSON
  /// string — servers differ on all three axes.
  static McpExecResult? tryParse(dynamic result) {
    final payload = _findExecPayload(result, 0);
    if (payload == null) return null;

    return McpExecResult(
      stdout: _asText(payload['stdout']),
      stderr: _asText(payload['stderr']),
      exitCode: WireParsers.parseInt(
        payload['exit_code'] ?? payload['exitCode'],
      ),
      success: payload['success'] as bool?,
      timedOut: (payload['timed_out'] ?? payload['timedOut']) as bool?,
      signalName: _asText(payload['signal_name'] ?? payload['signalName']),
      binaryOutput:
          (payload['binary_output'] ?? payload['binaryOutput']) as bool?,
    );
  }

  final String? stdout;
  final String? stderr;
  final int? exitCode;
  final bool? success;
  final bool? timedOut;
  final String? signalName;
  final bool? binaryOutput;

  static String? _asText(dynamic value) {
    if (value is! String) return null;
    return value.isEmpty ? null : value;
  }

  /// An exec record must at least say how the process ended; matching on
  /// `stdout` alone would swallow ordinary MCP payloads that happen to have
  /// that key.
  static bool _isExecPayload(Map<String, dynamic> map) =>
      map.containsKey('exit_code') ||
      map.containsKey('exitCode') ||
      (map.containsKey('success') &&
          (map.containsKey('stdout') || map.containsKey('stderr')));

  static Map<String, dynamic>? _findExecPayload(dynamic value, int depth) {
    if (depth > 4) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
      try {
        return _findExecPayload(jsonDecode(trimmed), depth + 1);
      } on FormatException {
        return null;
      }
    }

    final list = WireParsers.asList(value);
    if (list != null) {
      for (final item in list) {
        final found = _findExecPayload(item, depth + 1);
        if (found != null) return found;
      }
      return null;
    }

    final map = WireParsers.asMap(value);
    if (map == null) return null;
    if (_isExecPayload(map)) return map;

    for (final key in const ['text', 'content', 'result', 'output']) {
      if (!map.containsKey(key)) continue;
      final found = _findExecPayload(map[key], depth + 1);
      if (found != null) return found;
    }
    return null;
  }
}

/// Terminal card for an exec-shaped MCP tool call.
///
/// Renders the same chrome as the Bash / Codex `exec_command` views — command
/// bar, stdout, stderr, exit-code badge — plus a chip row for the fields that
/// are unique to the remote case (host/connection, timeout, signal).
class McpExecView extends StatelessWidget {
  const McpExecView({
    required this.tool,
    required this.exec,
    super.key,
    this.boxed = true,
  });

  /// The tool data map containing `name`, `input`, `result`, `state`.
  final Map<String, dynamic> tool;

  /// The parsed exec record — resolve with [McpExecResult.tryParse].
  final McpExecResult exec;

  /// Whether to wrap in the standard [ToolSectionView] frame. The detail
  /// screen supplies its own card, so it opts out.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? const {};
    final toolName = tool['name'] as String? ?? '';

    final command = _stringField(input, const [
      'command',
      'cmd',
      'script',
    ]) ?? '';
    final target = _stringField(input, const [
      'connection_id',
      'connectionId',
      'host',
      'hostname',
      'server',
      'target',
    ]);
    final cwd = _stringField(input, const ['cwd', 'workdir', 'working_dir']);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CommandView(
          command: command,
          cwd: target ?? cwd ?? _serverLabel(toolName),
          stdout: exec.stdout,
          stderr: exec.stderr,
          exitCode: exec.exitCode,
        ),
        _ExecChips(exec: exec, target: target, cwd: cwd),
      ],
    );

    return boxed ? ToolSectionView(child: body) : body;
  }

  /// `mcp__ssh__ssh_execute` → `ssh`; used only as a last-resort label when
  /// the input names no host.
  static String? _serverLabel(String toolName) {
    if (!toolName.startsWith('mcp__')) return null;
    final parts = toolName.substring(5).split('__');
    return parts.isEmpty || parts.first.isEmpty ? null : parts.first;
  }

  static String? _stringField(Map<String, dynamic> input, List<String> keys) {
    for (final key in keys) {
      final value = input[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }
}

/// Status chips for the non-stream exec fields, shown only when they carry
/// information: a green tick for a clean run, and warnings for the states
/// (timeout, signal, binary output) that silently explain empty stdout.
class _ExecChips extends StatelessWidget {
  const _ExecChips({required this.exec, this.target, this.cwd});

  final McpExecResult exec;
  final String? target;
  final String? cwd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = <Widget>[
      if (target != null)
        _Chip(icon: Icons.dns_outlined, label: target!, color: cs.tertiary),
      if (cwd != null)
        _Chip(icon: Icons.folder_outlined, label: cwd!, color: cs.secondary),
      if (exec.timedOut ?? false)
        const _Chip(
          icon: Icons.timer_off_outlined,
          label: 'timed out',
          color: AppColors.error,
        ),
      if (exec.signalName != null)
        _Chip(
          icon: Icons.bolt_outlined,
          label: 'signal ${exec.signalName}',
          color: AppColors.error,
        ),
      if (exec.binaryOutput ?? false)
        _Chip(
          icon: Icons.data_object,
          label: 'binary output',
          color: cs.onSurfaceVariant,
        ),
      if ((exec.success ?? false) && exec.exitCode == null)
        const _Chip(
          icon: Icons.check_circle_outline,
          label: 'success',
          color: AppColors.success,
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xsm),
      child: Wrap(
        spacing: AppSpacing.xsm,
        runSpacing: AppSpacing.xsm,
        children: chips,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xxs2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.xs,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
