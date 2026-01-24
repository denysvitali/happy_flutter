import 'package:flutter/material.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

/// Tool definitions with icons, subtitles, descriptions, and metadata.
///
/// Each tool definition contains:
/// - [icon]: The icon widget factory for the tool
/// - [title]: The display title (can be a string or a function)
/// - [minimal]: Whether to show minimal representation
/// - Various optional extractors for subtitle, description, and status
class ToolDefinition {
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
  final String Function(
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
  )?
  extractSubtitle;

  /// Extract description from tool data.
  final String Function(
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
  /// Icon factory for task/agent tools.
  static Widget taskIcon(double size, Color color) =>
      Icon(Icons.rocket_launch, size: size, color: color);

  /// Icon factory for terminal/bash tools.
  static Widget bashIcon(double size, Color color) =>
      Icon(Icons.terminal, size: size, color: color);

  /// Icon factory for search tools.
  static Widget searchIcon(double size, Color color) =>
      Icon(Icons.search, size: size, color: color);

  /// Icon factory for file read tools.
  static Widget readIcon(double size, Color color) =>
      Icon(Icons.visibility, size: size, color: color);

  /// Icon factory for file edit tools.
  static Widget editIcon(double size, Color color) =>
      Icon(Icons.edit, size: size, color: color);

  /// Icon factory for web fetch tools.
  static Widget webFetchIcon(double size, Color color) =>
      Icon(Icons.public, size: size, color: color);

  /// Icon factory for web search tools.
  static Widget webSearchIcon(double size, Color color) =>
      Icon(Icons.search, size: size, color: color);

  /// Icon factory for exit/plan tools.
  static Widget exitIcon(double size, Color color) =>
      Icon(Icons.exit_to_app, size: size, color: color);

  /// Icon factory for todo list tools.
  static Widget todoIcon(double size, Color color) =>
      Icon(Icons.checklist, size: size, color: color);

  /// Icon factory for reasoning tools.
  static Widget reasoningIcon(double size, Color color) =>
      Icon(Icons.lightbulb, size: size, color: color);

  /// Icon factory for question tools.
  static Widget questionIcon(double size, Color color) =>
      Icon(Icons.help_outline, size: size, color: color);

  /// Icon factory for MCP tools.
  static Widget mcpIcon(double size, Color color) =>
      Icon(Icons.extension, size: size, color: color);

  /// Default icon for unknown tools.
  static Widget defaultIcon(double size, Color color) =>
      Icon(Icons.build, size: size, color: color);

  /// Registry of known tool definitions.
  static final Map<String, ToolDefinition> tools = {
    'Task': ToolDefinition(
      icon: taskIcon,
      title: 'Task',
      isMutable: true,
      minimal: false,
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
        final path = tool['input']?['path'] as String?;
        if (path == null) return null;
        final resolvedPath = resolvePath(path, metadata);
        final basename = resolvedPath.split('/').lastOrNull ?? resolvedPath;
        return basename;
      },
    ),
    'Read': ToolDefinition(
      icon: readIcon,
      title: 'Read File',
      minimal: true,
      extractSubtitle: (tool, metadata) {
        final filePath = tool['input']?['file_path'] as String?;
        if (filePath != null) {
          return resolvePath(filePath, metadata);
        }
        // Gemini format
        final locations = tool['input']?['locations'] as List?;
        if (locations != null && locations.isNotEmpty) {
          final path = locations[0]['path'] as String?;
          if (path != null) return resolvePath(path, metadata);
        }
        return null;
      },
    ),
    'Edit': ToolDefinition(
      icon: editIcon,
      title: 'Edit File',
      isMutable: true,
      extractSubtitle: (tool, metadata) {
        final filePath = tool['input']?['file_path'] as String?;
        if (filePath != null) {
          return resolvePath(filePath, metadata);
        }
        return null;
      },
    ),
    'MultiEdit': ToolDefinition(
      icon: editIcon,
      title: 'Multi-Edit File',
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
      icon: webSearchIcon,
      title: 'Web Search',
      minimal: true,
      extractDescription: (tool, _) {
        final query = tool['input']?['query'] as String?;
        if (query == null) return null;
        final truncated = query.length > 30
            ? '${query.substring(0, 30)}...'
            : query;
        return 'Search: $truncated';
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
  };

  /// Get tool definition for a tool name.
  static ToolDefinition? get(String name) {
    return tools[name];
  }

  /// Check if a tool is known.
  static bool has(String name) => tools.containsKey(name);

  /// Get icon for a tool name.
  static Widget iconFor(String name, double size, Color color) {
    return tools[name]?.icon(size, color) ?? defaultIcon(size, color);
  }

  /// Get title for a tool.
  static String titleFor(
    String name,
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
  ) {
    final definition = tools[name];
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
    return tools[name]?.isMutable ?? true; // Default to true for unknown tools
  }

  /// Check if a tool should show minimal representation.
  static bool isMinimal(
    String name,
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
  ) {
    final definition = tools[name];
    if (definition == null) return true; // Unknown tools are minimal by default
    return definition.minimal;
  }
}
