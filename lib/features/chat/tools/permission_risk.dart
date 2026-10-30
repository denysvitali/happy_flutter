import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';

/// Plain-language consequence of approving a tool request.
///
/// Derived only from the tool name and its arguments, so it describes what
/// the request *would* do, never whether it is safe. [destructive] marks
/// hints worth a warning tint (irreversible or outward-facing changes).
enum PermissionRisk {
  delete(destructive: true),
  discard(destructive: true),
  push(destructive: true),
  publish(destructive: true),
  live(destructive: true),
  admin(destructive: true),
  network,
  command,
  editInside,
  editOutside(destructive: true),
  web;

  const PermissionRisk({this.destructive = false});

  final bool destructive;

  String label(AppLocalizations l10n) => switch (this) {
    delete => l10n.convRiskDelete,
    discard => l10n.convRiskDiscard,
    push => l10n.convRiskPush,
    publish => l10n.convRiskPublish,
    live => l10n.convRiskLive,
    admin => l10n.convRiskAdmin,
    network => l10n.convRiskNetwork,
    command => l10n.convRiskCommand,
    editInside => l10n.convRiskEditInside,
    editOutside => l10n.convRiskEditOutside,
    web => l10n.convRiskWeb,
  };

  IconData get icon => switch (this) {
    delete || discard => Icons.delete_outline_rounded,
    push || publish => Icons.upload_rounded,
    live => Icons.cloud_sync_outlined,
    admin => Icons.admin_panel_settings_outlined,
    network || web => Icons.public_rounded,
    command => Icons.terminal_rounded,
    editInside || editOutside => Icons.edit_note_rounded,
  };
}

const _editTools = {
  'Edit',
  'MultiEdit',
  'Write',
  'NotebookEdit',
  'CodexPatch',
  'CodexDiff',
};

const _commandTools = {'Bash', 'CodexBash', 'exec_command', 'shell'};

/// The single most relevant risk for a request, or null when there is
/// nothing useful to say (plans, questions, read-only tools).
PermissionRisk? permissionRiskFor(
  String toolName,
  Map<String, dynamic>? input, {
  String? workspacePath,
}) {
  if (_commandTools.contains(toolName)) {
    final command = _commandOf(input);
    return command == null ? PermissionRisk.command : commandRisk(command);
  }
  if (_editTools.contains(toolName)) {
    final path = permissionFilePath(input);
    if (path != null &&
        workspacePath != null &&
        path.startsWith('/') &&
        !_isWithin(path, workspacePath)) {
      return PermissionRisk.editOutside;
    }
    return PermissionRisk.editInside;
  }
  if (toolName == 'WebFetch' || toolName == 'WebSearch') {
    return PermissionRisk.web;
  }
  return null;
}

/// Classifies a shell command by its most consequential part.
PermissionRisk commandRisk(String command) {
  final c = ' ${command.toLowerCase()} ';
  bool has(String pattern) => RegExp(pattern).hasMatch(c);
  if (has(r'[\s;&|(]rm\s') || has(r'\bfind\b.*\s-delete\b')) {
    return PermissionRisk.delete;
  }
  if (has(r'\bgit\s+(reset\s+--hard|clean\s+-\w*f|checkout\s+--\s)') ||
      has(r'\bgit\s+restore\b')) {
    return PermissionRisk.discard;
  }
  if (has(r'\bkubectl\s') ||
      has(r'\bhelm\s+(install|upgrade|uninstall|rollback|delete)\b') ||
      has(r'\bterraform\s+(apply|destroy)\b') ||
      has(r'\bflyctl?\s+deploy\b')) {
    return _isReadOnlyKubectl(c) && !has(r'[;&|]')
        ? PermissionRisk.network
        : PermissionRisk.live;
  }
  if (has(r'\bgit\s+push\b')) return PermissionRisk.push;
  if (has(r'\b(npm|pnpm|yarn|cargo|dart|flutter)\s+(pub\s+)?publish\b') ||
      has(r'\bdocker\s+push\b') ||
      has(r'\bgh\s+(pr|release|issue)\s+(create|merge|edit|close)\b')) {
    return PermissionRisk.publish;
  }
  if (has(r'(^|\s)sudo\s')) return PermissionRisk.admin;
  if (has(r'\b(curl|wget|ssh|scp|rsync)\s')) return PermissionRisk.network;
  return PermissionRisk.command;
}

/// kubectl verbs that only read cluster state.
const _kubectlReadOnlyVerbs = {
  'get',
  'describe',
  'logs',
  'top',
  'explain',
  'version',
  'api-resources',
  'api-versions',
  'cluster-info',
};

/// kubectl global flags that take a separate value (`-n happy`). The
/// `--flag=value` form needs no entry.
const _kubectlValueFlags = {
  '-n',
  '--namespace',
  '--context',
  '--cluster',
  '--user',
  '--kubeconfig',
  '-s',
  '--server',
  '--as',
  '--as-group',
  '--token',
  '--request-timeout',
};

/// Whether a single kubectl invocation only reads. Global flags may come
/// before the verb (`kubectl -n happy get pods`), so they are skipped
/// rather than expecting the verb right after `kubectl`.
bool _isReadOnlyKubectl(String command) {
  final tokens = command.trim().split(RegExp(r'\s+'));
  final start = tokens.indexOf('kubectl');
  if (start < 0) return false;
  for (var i = start + 1; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.startsWith('-')) {
      if (!token.contains('=') && _kubectlValueFlags.contains(token)) i++;
      continue;
    }
    return _kubectlReadOnlyVerbs.contains(token);
  }
  return false;
}

String? _commandOf(Map<String, dynamic>? input) {
  final raw = input?['command'] ?? input?['cmd'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  if (raw is List) {
    final parts = raw.whereType<String>().toList();
    if (parts.isEmpty) return null;
    // Codex sends ["bash", "-lc", "<script>"]; show the script.
    if (parts.length >= 3 && parts[1] == '-lc') {
      return parts.sublist(2).join(' ');
    }
    return parts.join(' ');
  }
  return null;
}

/// The exact command a request would run, or null for non-command tools.
String? permissionCommand(String toolName, Map<String, dynamic>? input) =>
    _commandTools.contains(toolName) ? _commandOf(input) : null;

/// The file a write/edit request targets, if it names one.
String? permissionFilePath(Map<String, dynamic>? input) {
  for (final key in ['file_path', 'filePath', 'path', 'notebook_path']) {
    final value = input?[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

bool _isWithin(String path, String root) {
  final normalized = root.endsWith('/') ? root : '$root/';
  return path == root || path.startsWith(normalized);
}
