import 'package:flutter/material.dart';
import 'package:happy_flutter/core/utils/command_utils.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';
import 'package:happy_flutter/core/utils/tool_input_extractor.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';

/// Tool definitions with icons, subtitles, descriptions, and metadata.
///
/// Each tool definition contains:
/// - [icon]: The icon widget factory for the tool
/// - [title]: The display title (can be a string or a function)
/// - [minimal]: Whether to show minimal representation
/// - Various optional extractors for subtitle, description, and status
class ToolDefinition {
  const ToolDefinition({
    required this.icon,
    this.title,
    this.minimal = false,
    this.hideDefaultError = false,
    this.isMutable = false,
    this.noStatus = false,
    this.extractSubtitle,
    this.extractDescription,
    this.extractStatus,
  });

  /// Icon factory function that takes size and color parameters.
  final Widget Function(double size, Color color) icon;

  /// Tool title - can be a static string or a function to compute it.
  final dynamic title;

  /// Whether to show minimal representation (no expanded content).
  final bool minimal;

  /// Whether to hide default error display for this tool.
  final bool hideDefaultError;

  /// Whether this tool can modify files (for permission handling).
  final bool isMutable;

  /// Whether to skip status display for this tool.
  final bool noStatus;

  /// Extract subtitle from tool data.
  final String? Function(
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
  )?
  extractSubtitle;

  /// Extract description from tool data.
  final String? Function(
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
  )?
  extractDescription;

  /// Extract status text from tool data.
  final String? Function(
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
  )?
  extractStatus;

  /// Create a copy with additional properties.
  ToolDefinition copyWith({bool? noStatus}) {
    return ToolDefinition(
      icon: icon,
      title: title,
      minimal: minimal,
      hideDefaultError: hideDefaultError,
      isMutable: isMutable,
      noStatus: noStatus ?? this.noStatus,
      extractSubtitle: extractSubtitle,
      extractDescription: extractDescription,
      extractStatus: extractStatus,
    );
  }
}

/// Registry of known tool definitions.
class KnownTools {
  /// Canonical display-definition names for aliases emitted by different
  /// agents or provider adapters.
  static const Map<String, String> aliases = {
    'file-edit': 'Edit',
    'read': 'Read',
    'write': 'Write',
    'bash': 'Bash',
    'grep': 'Grep',
    'ls': 'LS',
    'functions.exec_command': 'exec_command',
    'functions.apply_patch': 'CodexPatch',
    'apply_patch': 'CodexPatch',
    'exit_plan_mode': 'ExitPlanMode',
    // Grok Build ACP built-ins (happy-cli-go materialises title=tool name).
    'list_dir': 'LS',
    'read_file': 'Read',
    'run_terminal_command': 'Bash',
    'run_terminal_cmd': 'Bash',
    'search_replace': 'Edit',
    'todo_write': 'TodoWrite',
  };

  /// Returns the canonical definition name for [name].
  static String canonicalName(String name) => aliases[name] ?? name;

  /// Icon factory for task/agent tools.
  static Widget taskIcon(double size, Color color) =>
      Icon(Icons.rocket_launch_outlined, size: size, color: color);

  /// Icon factory for terminal/bash tools.
  static Widget bashIcon(double size, Color color) =>
      Icon(Icons.terminal, size: size, color: color);

  /// Icon factory for search tools.
  static Widget searchIcon(double size, Color color) =>
      Icon(Icons.search, size: size, color: color);

  /// Icon factory for file read tools.
  static Widget readIcon(double size, Color color) =>
      Icon(Icons.article_outlined, size: size, color: color);

  /// Icon factory for file edit tools.
  static Widget editIcon(double size, Color color) =>
      Icon(Icons.edit_outlined, size: size, color: color);

  /// Icon factory for web fetch tools.
  static Widget webFetchIcon(double size, Color color) =>
      Icon(Icons.public, size: size, color: color);

  /// Icon factory for exit/plan tools.
  static Widget exitIcon(double size, Color color) =>
      Icon(Icons.exit_to_app, size: size, color: color);

  /// Icon factory for todo list tools.
  static Widget todoIcon(double size, Color color) =>
      Icon(Icons.checklist, size: size, color: color);

  /// Icon factory for reasoning tools.
  static Widget reasoningIcon(double size, Color color) =>
      Icon(Icons.lightbulb_outline, size: size, color: color);

  /// Icon factory for question tools.
  static Widget questionIcon(double size, Color color) =>
      Icon(Icons.help_outline, size: size, color: color);

  /// Icon factory for MCP tools.
  static Widget mcpIcon(double size, Color color) =>
      Icon(Icons.extension_outlined, size: size, color: color);

  /// Icon factory for notebook tools.
  static Widget notebookIcon(double size, Color color) =>
      Icon(Icons.menu_book_outlined, size: size, color: color);

  /// Icon factory for notebook edit tools.
  static Widget notebookEditIcon(double size, Color color) =>
      Icon(Icons.edit_note, size: size, color: color);

  /// Icon factory for reasoning/think tools.
  static Widget thinkIcon(double size, Color color) =>
      Icon(Icons.psychology_outlined, size: size, color: color);

  /// Icon factory for change title tools.
  static Widget titleIcon(double size, Color color) =>
      Icon(Icons.title, size: size, color: color);

  /// Icon factory for codex/patch tools.
  static Widget patchIcon(double size, Color color) =>
      Icon(Icons.difference_outlined, size: size, color: color);

  /// Icon factory for codex/diff tools.
  static Widget diffIcon(double size, Color color) =>
      Icon(Icons.difference_outlined, size: size, color: color);

  /// Default icon for unknown tools.
  static Widget defaultIcon(double size, Color color) =>
      Icon(Icons.build_outlined, size: size, color: color);

  /// Tool names of the Codex MCP session tools (`mcp__codex__*`).
  ///
  /// Single source of truth — the view registry, this registry, and the
  /// message detail screen all key off this set.
  static const Set<String> codexMcpToolNames = {
    'mcp__codex__codex',
    'mcp__codex__codex-reply',
  };

  /// Registry of known tool definitions.
  static final Map<String, ToolDefinition> tools = {
    'Task': ToolDefinition(
      icon: taskIcon,
      title: 'Task',
      isMutable: true,
      minimal: false,
      extractSubtitle: (tool, _) {
        final input = WireParsers.asMap(tool['input']);
        return input?['subagent_type'] as String?;
      },
      extractStatus: (tool, _) {
        final children = WireParsers.asList(tool['children']);
        final count = children?.length ?? 0;
        return count > 0 ? '$count steps' : null;
      },
    ),
    'Agent': ToolDefinition(
      icon: taskIcon,
      title: 'Agent',
      isMutable: true,
      minimal: false,
      extractSubtitle: (tool, _) {
        final input = WireParsers.asMap(tool['input']);
        return input?['subagent_type'] as String?;
      },
      extractStatus: (tool, _) {
        final children = WireParsers.asList(tool['children']);
        final count = children?.length ?? 0;
        return count > 0 ? '$count steps' : null;
      },
    ),
    'Workflow': ToolDefinition(
      icon: taskIcon,
      title: 'Workflow',
      isMutable: true,
      minimal: false,
      extractSubtitle: (tool, _) {
        final input = WireParsers.asMap(tool['input']);
        return input?['name'] as String? ?? input?['workflowName'] as String?;
      },
      extractStatus: (tool, _) {
        final children = WireParsers.asList(tool['children']);
        final count = children?.length ?? 0;
        return count > 0 ? '$count steps' : null;
      },
    ),
    'Bash': ToolDefinition(
      icon: bashIcon,
      title: 'Terminal',
      minimal: true,
      hideDefaultError: true,
      isMutable: true,
      extractSubtitle: (tool, _) => tool['input']?['command'] as String?,
      extractDescription: (tool, _) {
        final cmd = tool['input']?['command'] as String?;
        if (cmd == null) return null;
        final firstWord = cmd.split(' ').first;
        if ([
          'cd',
          'ls',
          'pwd',
          'mkdir',
          'rm',
          'cp',
          'mv',
          'npm',
          'yarn',
          'git',
        ].contains(firstWord)) {
          return '$firstWord command';
        }
        return cmd.length > 20 ? '${cmd.substring(0, 20)}...' : cmd;
      },
    ),
    'exec_command': ToolDefinition(
      icon: bashIcon,
      title: 'Terminal',
      minimal: false,
      hideDefaultError: true,
      extractSubtitle: (tool, _) {
        final input = WireParsers.asMap(tool['input']);
        return input?['cmd'] as String? ?? input?['command'] as String?;
      },
    ),
    'functions.exec_command': ToolDefinition(
      icon: bashIcon,
      title: 'Terminal',
      minimal: false,
      hideDefaultError: true,
      extractSubtitle: (tool, _) {
        final input = WireParsers.asMap(tool['input']);
        return input?['cmd'] as String? ?? input?['command'] as String?;
      },
    ),
    'Glob': ToolDefinition(
      icon: searchIcon,
      title: 'Search Files',
      minimal: true,
      extractDescription: (tool, _) {
        final pattern = tool['input']?['pattern'] as String?;
        return pattern != null ? 'Pattern: $pattern' : null;
      },
    ),
    'Grep': ToolDefinition(
      icon: searchIcon,
      title: 'Search Content',
      minimal: true,
      extractDescription: (tool, _) {
        final pattern = tool['input']?['pattern'] as String?;
        if (pattern == null) return null;
        final truncated = pattern.length > 20
            ? '${pattern.substring(0, 20)}...'
            : pattern;
        return 'grep($truncated)';
      },
    ),
    'LS': ToolDefinition(
      icon: searchIcon,
      title: 'List Files',
      minimal: true,
      extractDescription: (tool, metadata) {
        final input = WireParsers.asMap(tool['input']) ?? const {};
        final path = extractFilePath(input);
        if (path == null) return null;
        final resolvedPath = resolvePath(path, metadata);
        final basename = resolvedPath.split('/').lastOrNull ?? resolvedPath;
        return basename;
      },
    ),
    'Read': ToolDefinition(
      icon: readIcon,
      title: 'Read File',
      minimal: false,
      extractSubtitle: (tool, metadata) {
        final input = WireParsers.asMap(tool['input']) ?? const {};
        final filePath = extractFilePath(input);
        if (filePath != null) {
          return resolvePath(filePath, metadata);
        }
        return null;
      },
    ),
    'Edit': ToolDefinition(
      icon: editIcon,
      title: 'Apply Changes',
      isMutable: true,
      extractSubtitle: (tool, metadata) {
        final input = WireParsers.asMap(tool['input']) ?? const {};
        final filePath = extractFilePath(input);
        if (filePath != null) {
          return resolvePath(filePath, metadata);
        }
        return null;
      },
    ),
    'file-edit': ToolDefinition(
      icon: editIcon,
      title: 'Edit File',
      isMutable: true,
      extractSubtitle: (tool, metadata) {
        final input = WireParsers.asMap(tool['input']);
        final filePath =
            input?['filePath'] as String? ??
            input?['file_path'] as String? ??
            input?['path'] as String?;
        if (filePath != null) {
          return resolvePath(filePath, metadata);
        }
        return null;
      },
    ),
    'MultiEdit': ToolDefinition(
      icon: editIcon,
      title: 'Apply Changes',
      isMutable: true,
      minimal: false,
      extractSubtitle: (tool, metadata) {
        final filePath = tool['input']?['file_path'] as String?;
        if (filePath != null) {
          final editCount = (tool['input']?['edits'] as List?)?.length ?? 0;
          if (editCount > 1) {
            return '$editCount edits to ${resolvePath(filePath, metadata)}';
          }
          return resolvePath(filePath, metadata);
        }
        return null;
      },
      extractStatus: (tool, metadata) {
        final filePath = tool['input']?['file_path'] as String?;
        if (filePath != null) {
          final editCount = (tool['input']?['edits'] as List?)?.length ?? 0;
          if (editCount > 0) {
            return '$editCount edits';
          }
          return resolvePath(filePath, metadata);
        }
        return null;
      },
    ),
    'Write': ToolDefinition(
      icon: editIcon,
      title: 'Apply Changes',
      isMutable: true,
      extractSubtitle: (tool, metadata) {
        final input = WireParsers.asMap(tool['input']) ?? const {};
        final filePath = extractFilePath(input);
        if (filePath != null) {
          return resolvePath(filePath, metadata);
        }
        return null;
      },
    ),
    'WebFetch': ToolDefinition(
      icon: webFetchIcon,
      title: 'Fetch URL',
      minimal: true,
      extractDescription: (tool, _) {
        final url = tool['input']?['url'] as String?;
        if (url == null) return null;
        try {
          final uri = Uri.parse(url);
          return 'Fetch ${uri.host}';
        } catch (_) {
          return 'Fetch URL';
        }
      },
    ),
    'WebSearch': ToolDefinition(
      icon: webFetchIcon,
      title: 'Web Search',
      minimal: true,
      extractSubtitle: _extractWebSearchDescription,
      extractDescription: _extractWebSearchDescription,
    ),
    'web_search': ToolDefinition(
      icon: webFetchIcon,
      title: 'Web Search',
      minimal: true,
      extractSubtitle: _extractWebSearchDescription,
      extractDescription: _extractWebSearchDescription,
    ),
    'web_search_preview': ToolDefinition(
      icon: webFetchIcon,
      title: 'Web Search',
      minimal: true,
      extractSubtitle: _extractWebSearchDescription,
      extractDescription: _extractWebSearchDescription,
    ),
    'ToolSearch': ToolDefinition(
      icon: searchIcon,
      title: 'Tool Search',
      minimal: true,
      extractDescription: (tool, _) {
        final query = tool['input']?['query'] as String?;
        if (query == null) return null;
        final truncated = query.length > 40
            ? '${query.substring(0, 40)}...'
            : query;
        return truncated;
      },
    ),
    'TodoWrite': ToolDefinition(
      icon: todoIcon,
      title: 'Todo List',
      noStatus: true,
      minimal: false,
      extractDescription: (tool, _) {
        final todos = tool['input']?['todos'] as List?;
        if (todos != null) {
          return '${todos.length} items';
        }
        return null;
      },
    ),
    'todo_list': ToolDefinition(
      icon: todoIcon,
      title: 'Todo List',
      noStatus: true,
      minimal: false,
      extractDescription: (tool, _) {
        final items = tool['input']?['items'] as List?;
        if (items != null) {
          return '${items.length} items';
        }
        final todos = tool['input']?['todos'] as List?;
        if (todos != null) {
          return '${todos.length} items';
        }
        return null;
      },
    ),
    'TaskCreate': ToolDefinition(
      icon: todoIcon,
      title: 'Create Task',
      // NOT minimal — the body widget must mount so its initState can
      // push the parsed item into todoStateNotifierProvider. Collapsed
      // tools skip body instantiation entirely.
      extractSubtitle: (tool, _) {
        final input = WireParsers.asMap(tool['input']);
        return input?['subject'] as String? ?? input?['description'] as String?;
      },
    ),
    'TaskUpdate': ToolDefinition(
      icon: todoIcon,
      title: 'Update Task',
      extractSubtitle: (tool, _) {
        final input = WireParsers.asMap(tool['input']);
        return input?['activeForm'] as String? ?? input?['subject'] as String?;
      },
    ),
    'TaskList': ToolDefinition(icon: todoIcon, title: 'List Tasks'),
    'TaskGet': ToolDefinition(
      icon: todoIcon,
      title: 'Get Task',
      extractSubtitle: (tool, _) {
        final input = WireParsers.asMap(tool['input']);
        final taskId = input?['taskId'] as String? ?? input?['id'] as String?;
        return taskId != null ? '#$taskId' : null;
      },
    ),
    'ExitPlanMode': ToolDefinition(icon: exitIcon, title: 'Plan Proposal'),
    'exit_plan_mode': ToolDefinition(icon: exitIcon, title: 'Plan Proposal'),
    'AskUserQuestion': ToolDefinition(
      icon: questionIcon,
      title: 'Question',
      minimal: false,
      noStatus: true,
      extractSubtitle: (tool, _) {
        final questions = tool['input']?['questions'] as List?;
        if (questions == null || questions.isEmpty) return null;
        if (questions.length == 1) {
          return questions[0]['question'] as String?;
        }
        return '${questions.length} questions';
      },
    ),
    // Lowercase variants for Gemini
    'read': ToolDefinition(
      icon: readIcon,
      title: 'Read File',
      minimal: false,
      extractSubtitle: (tool, metadata) {
        // Gemini format uses locations array
        final locations = tool['input']?['locations'] as List?;
        if (locations != null && locations.isNotEmpty) {
          final path = locations[0]['path'] as String?;
          if (path != null) return resolvePath(path, metadata);
        }
        final filePath = tool['input']?['file_path'] as String?;
        if (filePath != null) return resolvePath(filePath, metadata);
        return null;
      },
    ),
    'search': ToolDefinition(icon: searchIcon, title: 'Search', minimal: true),
    'edit': ToolDefinition(
      icon: editIcon,
      title: 'Edit File',
      isMutable: true,
      extractSubtitle: (tool, metadata) {
        // Gemini sends data in nested structure
        final toolCall = WireParsers.asMap(tool['input']?['toolCall']);
        if (toolCall != null) {
          final content = toolCall['content'] as List?;
          if (content != null && content.isNotEmpty) {
            final path = content[0]['path'] as String?;
            if (path != null) return resolvePath(path, metadata);
          }
          final title = toolCall['title'] as String?;
          if (title != null && title.startsWith('Writing to ')) {
            return title.replaceFirst('Writing to ', '');
          }
        }
        final input = tool['input']?['input'] as List?;
        if (input != null && input.isNotEmpty) {
          final path = input[0]['path'] as String?;
          if (path != null) return resolvePath(path, metadata);
        }
        final path = tool['input']?['path'] as String?;
        if (path != null) return resolvePath(path, metadata);
        return null;
      },
    ),
    'shell': ToolDefinition(
      icon: bashIcon,
      title: 'Shell',
      minimal: true,
      isMutable: true,
    ),
    'execute': ToolDefinition(
      icon: bashIcon,
      title: 'Execute',
      minimal: true,
      isMutable: true,
      extractSubtitle: (tool, _) {
        final toolCall = WireParsers.asMap(tool['input']?['toolCall']);
        final title = toolCall?['title'] as String?;
        if (title != null) {
          // Extract command from title like "rm file.txt [cwd /path] (description)"
          final bracketIdx = title.indexOf(' [');
          if (bracketIdx > 0) {
            return title.substring(0, bracketIdx);
          }
          return title;
        }
        return null;
      },
    ),
    'think': ToolDefinition(
      icon: reasoningIcon,
      title: 'Reasoning',
      minimal: true,
    ),
    'change_title': ToolDefinition(
      icon: titleIcon,
      title: 'Change Title',
      minimal: true,
      noStatus: true,
    ),
    // Pi-specific lowercase tools. Pi emits tool names in lowercase, so
    // mirror the Title-case Claude entries to keep icon/title parity.
    'bash': ToolDefinition(
      icon: bashIcon,
      title: 'Terminal',
      minimal: true,
      hideDefaultError: true,
      isMutable: true,
      extractSubtitle: (tool, _) => tool['input']?['command'] as String?,
      extractDescription: (tool, _) {
        final cmd = tool['input']?['command'] as String?;
        if (cmd == null) return null;
        final firstWord = cmd.split(' ').first;
        if ([
          'cd',
          'ls',
          'pwd',
          'mkdir',
          'rm',
          'cp',
          'mv',
          'npm',
          'yarn',
          'git',
        ].contains(firstWord)) {
          return '$firstWord command';
        }
        return cmd.length > 20 ? '${cmd.substring(0, 20)}...' : cmd;
      },
    ),
    'write': ToolDefinition(
      icon: editIcon,
      title: 'Write File',
      isMutable: true,
      extractSubtitle: (tool, metadata) {
        final filePath = tool['input']?['file_path'] as String?;
        if (filePath != null) {
          return resolvePath(filePath, metadata);
        }
        return null;
      },
    ),
    'grep': ToolDefinition(
      icon: searchIcon,
      title: 'Search Content',
      minimal: true,
      extractDescription: (tool, _) {
        final pattern = tool['input']?['pattern'] as String?;
        if (pattern == null) return null;
        final truncated = pattern.length > 20
            ? '${pattern.substring(0, 20)}...'
            : pattern;
        return 'grep($truncated)';
      },
    ),
    'find': ToolDefinition(
      icon: searchIcon,
      title: 'Search Files',
      minimal: true,
      extractDescription: (tool, _) {
        final pattern = tool['input']?['pattern'] as String?;
        return pattern != null ? 'Pattern: $pattern' : null;
      },
    ),
    'ls': ToolDefinition(
      icon: searchIcon,
      title: 'List Files',
      minimal: true,
      extractDescription: (tool, metadata) {
        final path = tool['input']?['path'] as String?;
        if (path == null) return null;
        final resolvedPath = resolvePath(path, metadata);
        final basename = resolvedPath.split('/').lastOrNull ?? resolvedPath;
        return basename;
      },
    ),
    // Codex tools
    'CodexBash': ToolDefinition(
      icon: bashIcon,
      title: 'Terminal',
      minimal: true,
      hideDefaultError: true,
      isMutable: true,
      extractSubtitle: (tool, _) {
        final parsedCmd = tool['input']?['parsed_cmd'] as List?;
        if (parsedCmd != null && parsedCmd.isNotEmpty) {
          final cmd = WireParsers.asMap(parsedCmd[0]);
          return cleanShellCommand(cmd?['cmd'] as String?);
        }
        final command = tool['input']?['command'] as List?;
        if (command != null && command.isNotEmpty) {
          return cleanShellCommand(command.join(' '));
        }
        return null;
      },
    ),
    'CodexPatch': ToolDefinition(
      icon: patchIcon,
      title: 'Apply Changes',
      minimal: false,
      hideDefaultError: true,
      isMutable: true,
      extractSubtitle: (tool, _) {
        final input = WireParsers.asMap(tool['input']);
        final changes = WireParsers.asMap(input?['changes']);
        if (changes != null && changes.isNotEmpty) {
          final files = changes.keys.toList();
          if (files.length == 1) {
            return files[0].split('/').lastOrNull ?? files[0];
          }
          return '${files.length} files';
        }
        return _extractPatchSubtitle(tool);
      },
    ),
    'apply_patch': ToolDefinition(
      icon: patchIcon,
      title: 'Apply Changes',
      minimal: false,
      hideDefaultError: true,
      isMutable: true,
      extractSubtitle: (tool, _) => _extractPatchSubtitle(tool),
    ),
    'functions.apply_patch': ToolDefinition(
      icon: patchIcon,
      title: 'Apply Changes',
      minimal: false,
      hideDefaultError: true,
      isMutable: true,
      extractSubtitle: (tool, _) => _extractPatchSubtitle(tool),
    ),
    'CodexDiff': ToolDefinition(
      icon: diffIcon,
      title: 'View Diff',
      minimal: false,
      hideDefaultError: true,
      noStatus: true,
      extractSubtitle: (tool, _) {
        final diff = tool['input']?['unified_diff'] as String?;
        if (diff != null) {
          for (final line in diff.split('\n')) {
            if (line.startsWith('+++ b/') || line.startsWith('+++ ')) {
              return line.replaceFirst(RegExp(r'^\+\+\+ (b/)?'), '');
            }
          }
        }
        return null;
      },
    ),
    // Codex MCP session tools (mcp__codex__*). Title/icon come from the
    // generic MCP branch in ToolView — these entries only mark the tool
    // non-minimal (the CodexMcpView body renders the full prompt + config)
    // and surface the first prompt line as the collapsed-header subtitle.
    ...<String, ToolDefinition>{
      for (final name in codexMcpToolNames)
        name: ToolDefinition(
          icon: mcpIcon,
          title: name == 'mcp__codex__codex-reply' ? 'Codex Reply' : 'Codex',
          minimal: false,
          extractSubtitle: _extractCodexPromptSubtitle,
        ),
    },
    // Gemini-specific tools
    'GeminiReasoning': ToolDefinition(
      icon: reasoningIcon,
      title: 'Reasoning',
      minimal: true,
    ),
    'GeminiBash': ToolDefinition(
      icon: bashIcon,
      title: 'Terminal',
      minimal: true,
      hideDefaultError: true,
      isMutable: true,
    ),
    'GeminiPatch': ToolDefinition(
      icon: patchIcon,
      title: 'Apply Changes',
      minimal: false,
      hideDefaultError: true,
      isMutable: true,
    ),
    'GeminiDiff': ToolDefinition(
      icon: diffIcon,
      title: 'View Diff',
      minimal: false,
      hideDefaultError: true,
      noStatus: true,
    ),
    // Notebook tools
    'NotebookRead': ToolDefinition(
      icon: notebookIcon,
      title: 'Read Notebook',
      minimal: true,
      extractSubtitle: (tool, metadata) {
        final path = tool['input']?['notebook_path'] as String?;
        if (path != null) return resolvePath(path, metadata);
        return null;
      },
    ),
    'NotebookEdit': ToolDefinition(
      icon: notebookEditIcon,
      title: 'Edit Notebook',
      isMutable: true,
      minimal: false,
      extractSubtitle: (tool, metadata) {
        final path = tool['input']?['notebook_path'] as String?;
        if (path != null) {
          final mode = tool['input']?['edit_mode'] as String? ?? 'replace';
          return '$mode in ${path.split('/').lastOrNull ?? path}';
        }
        return null;
      },
    ),
  };

  /// Get tool definition for a tool name.
  static ToolDefinition? get(String name) {
    return tools[canonicalName(name)];
  }

  /// Check if a tool is known.
  static bool has(String name) => tools.containsKey(canonicalName(name));

  /// Get icon for a tool name.
  static Widget iconFor(String name, double size, Color color) {
    return tools[canonicalName(name)]?.icon(size, color) ??
        defaultIcon(size, color);
  }

  /// Get title for a tool.
  static String titleFor(
    String name,
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
  ) {
    final definition = tools[canonicalName(name)];
    if (definition == null) return name;

    if (definition.title is String) {
      return definition.title;
    } else if (definition.title
        is String Function(Map<String, dynamic>, Map<String, dynamic>?)) {
      return definition.title(tool, metadata);
    }
    return name;
  }

  /// Check if a tool is mutable (can modify files).
  static bool isMutable(String name) {
    return tools[canonicalName(name)]?.isMutable ??
        true; // Default to true for unknown tools
  }

  /// Check if a tool should show minimal representation.
  static bool isMinimal(
    String name,
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
  ) {
    final definition = tools[canonicalName(name)];
    if (definition == null) return true; // Unknown tools are minimal by default
    return definition.minimal;
  }

  static String? _extractCodexPromptSubtitle(
    Map<String, dynamic> tool,
    Map<String, dynamic>? _,
  ) {
    final input = WireParsers.asMap(tool['input']);
    final prompt = input?['prompt'] as String?;
    if (prompt == null) return null;
    final firstLine = prompt
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return null;
    const maxLen = 80;
    return firstLine.length > maxLen
        ? '${firstLine.substring(0, maxLen)}…'
        : firstLine;
  }

  static String? _extractPatchSubtitle(Map<String, dynamic> tool) {
    final patch =
        _extractPatchText(tool['input']) ??
        _extractPatchText(tool['content']) ??
        _extractPatchText(tool['raw']) ??
        _extractPatchText(tool['result']);
    if (patch == null) return null;

    final files = <String>[];
    for (final line in patch.split('\n')) {
      final file = _patchFileFromLine(line);
      if (file != null && !files.contains(file)) files.add(file);
    }
    if (files.length == 1) return files.single.split('/').lastOrNull;
    if (files.length > 1) return '${files.length} files';
    return null;
  }

  static String? _extractWebSearchDescription(
    Map<String, dynamic> tool,
    Map<String, dynamic>? _,
  ) {
    final result = WireParsers.asMap(tool['result']);
    final nestedResult = WireParsers.asMap(result?['result']);
    final candidates = <Map<String, dynamic>?>[
      WireParsers.asMap(tool['input']),
      WireParsers.asMap(result?['action']),
      WireParsers.asMap(nestedResult?['action']),
      result,
      nestedResult,
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      for (final key in const ['query', 'search_query']) {
        final value = candidate[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        final summary = _firstWebSearchListValue(value);
        if (summary != null) return summary;
      }
      final queries = _firstWebSearchListValue(candidate['queries']);
      if (queries != null) return queries;
      final opened = _firstWebSearchListValue(candidate['open']);
      if (opened != null) return 'Open $opened';
    }
    return null;
  }

  static String? _firstWebSearchListValue(dynamic value) {
    final items = WireParsers.asList(value);
    if (items == null || items.isEmpty) return null;
    final labels = <String>[];
    for (final item in items.take(2)) {
      final map = WireParsers.asMap(item);
      final label = map?['q'] ?? map?['query'] ?? map?['ref_id'] ?? item;
      final text = label.toString().trim();
      if (text.isNotEmpty) labels.add(text);
    }
    return labels.isEmpty ? null : labels.join(', ');
  }

  static String? _extractPatchText(dynamic input) {
    if (input is String && input.contains('*** Begin Patch')) return input;
    final inputMap = WireParsers.asMap(input);
    if (inputMap == null) {
      final inputList = WireParsers.asList(input);
      return inputList != null ? _findPatchText(inputList) : null;
    }
    for (final key in const ['patch', 'input', 'content']) {
      final value = inputMap[key];
      if (value is String && value.contains('*** Begin Patch')) return value;
    }
    return _findPatchText(inputMap);
  }

  static String? _findPatchText(dynamic value) {
    if (value is String && value.contains('*** Begin Patch')) return value;
    final map = WireParsers.asMap(value);
    if (map != null) {
      for (final entry in map.values) {
        final patch = _findPatchText(entry);
        if (patch != null) return patch;
      }
      return null;
    }
    final list = WireParsers.asList(value);
    if (list != null) {
      for (final item in list) {
        final patch = _findPatchText(item);
        if (patch != null) return patch;
      }
    }
    return null;
  }

  static String? _patchFileFromLine(String line) {
    for (final prefix in const [
      '*** Add File: ',
      '*** Update File: ',
      '*** Delete File: ',
    ]) {
      if (line.startsWith(prefix)) return line.substring(prefix.length);
    }
    return null;
  }
}
