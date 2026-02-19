import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/sync_service.dart';
import '../utils/tool_error_parser.dart';
import 'elapsed_time.dart';
import 'known_tools.dart';
import 'permission_footer.dart';
import 'tool_error.dart';
import 'tool_section_view.dart';
import 'tool_status_indicator.dart';
import 'views/ask_user_question_view.dart';
import 'views/bash_view.dart';
import 'views/codex_bash_view.dart';
import 'views/codex_diff_view.dart';
import 'views/codex_patch_view.dart';
import 'views/edit_view.dart';
import 'views/exit_plan_tool_view.dart';
import 'views/gemini_edit_view.dart';
import 'views/gemini_execute_view.dart';
import 'views/glob_view.dart';
import 'views/grep_view.dart';
import 'views/ls_view.dart';
import 'views/multi_edit_view.dart';
import 'views/read_view.dart';
import 'views/task_view.dart';
import 'views/todo_view.dart';
import 'views/web_fetch_view.dart';
import 'views/web_search_view.dart';
import 'views/write_view.dart';

/// Duration before auto-collapsing a completed/error tool.
const _kAutoCollapseDelay = Duration(seconds: 3);

/// Returns the left border accent color for a given tool state.
Color _stateAccentColor(ToolState state) {
  switch (state) {
    case ToolState.running:
      return const Color(0xFF2196F3); // blue
    case ToolState.completed:
      return const Color(0xFF34C759); // green
    case ToolState.error:
      return const Color(0xFFFF3B30); // red
    case ToolState.pending:
      return const Color(0xFF8E8E93); // grey
  }
}

/// Accent color for permission-required state (orange).
const Color _permissionColor = Color(0xFFFF9500);

/// Map of MCP server name tokens to representative emojis.
const Map<String, String> _mcpServerEmojis = {
  'linear': '\u{1F4CB}',
  'github': '\u{1F4BE}',
  'gitlab': '\u{1F9A8}',
  'jira': '\u{1F4DD}',
  'slack': '\u{1F4AC}',
  'notion': '\u{1F4D3}',
  'postgres': '\u{1F5C3}',
  'mysql': '\u{1F5C3}',
  'sqlite': '\u{1F5C3}',
  'filesystem': '\u{1F4C1}',
  'brave': '\u{1F310}',
  'puppeteer': '\u{1F916}',
  'fetch': '\u{1F310}',
  'memory': '\u{1F9E0}',
  'everything': '\u{1F50D}',
  'sequential': '\u{1F4BB}',
};

/// Resolves a representative emoji from an MCP server name token.
String _mcpServerEmoji(String serverToken) {
  final key = serverToken.toLowerCase();
  for (final entry in _mcpServerEmojis.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return '\u{1F527}'; // wrench fallback
}

/// Main ToolView component with header, status, and elapsed time.
///
/// Displays tool call information with:
/// - Colored left border accent indicating tool state
/// - Tool icon and title
/// - Chevron expand/collapse toggle (animated)
/// - Optional subtitle/description
/// - Status indicator with pulsing animation while running
/// - Elapsed time for running tools
/// - Tool-specific content view (collapsible with AnimatedSize)
/// - Green checkmark flash when transitioning running -> completed
/// - Permission footer (if applicable)
class ToolView extends StatefulWidget {
  /// Creates a [ToolView].
  const ToolView({
    required this.tool,
    super.key,
    this.metadata,
    this.messages,
    this.sessionId,
    this.onPress,
  });

  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata (e.g., working directory).
  final Map<String, dynamic>? metadata;

  /// Optional list of messages (for Task tool).
  final List<Map<String, dynamic>>? messages;

  /// Session ID for permission actions.
  final String? sessionId;

  /// Callback when the tool header is pressed.
  final VoidCallback? onPress;

  @override
  State<ToolView> createState() => _ToolViewState();
}

class _ToolViewState extends State<ToolView> with TickerProviderStateMixin {
  bool _expanded = true;
  bool _showCheckFlash = false;
  ToolState? _prevState;
  Timer? _collapseTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  late final AnimationController _chevronController;
  late final Animation<double> _chevronAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _chevronAnim = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronController, curve: Curves.easeInOut),
    );

    final initial = _parseToolState(
      widget.tool['state'] as String? ?? 'pending',
    );
    _prevState = initial;

    if (initial == ToolState.running) {
      _expanded = true;
      _chevronController.forward();
      _pulseController.repeat(reverse: true);
    } else {
      _expanded = false;
    }
  }

  @override
  void didUpdateWidget(ToolView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newState = _parseToolState(
      widget.tool['state'] as String? ?? 'pending',
    );

    if (_prevState == newState) return;

    if (_prevState == ToolState.running &&
        newState == ToolState.completed) {
      _pulseController
        ..stop()
        ..reset();
      setState(() => _showCheckFlash = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showCheckFlash = false);
      });
      _scheduleAutoCollapse();
    } else if (_prevState == ToolState.running &&
        newState == ToolState.error) {
      _pulseController
        ..stop()
        ..reset();
      _scheduleAutoCollapse();
    } else if (newState == ToolState.running) {
      _collapseTimer?.cancel();
      if (!_expanded) _setExpanded(true);
      _pulseController.repeat(reverse: true);
    }

    _prevState = newState;
  }

  void _scheduleAutoCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_kAutoCollapseDelay, () {
      if (mounted && _expanded) _setExpanded(false);
    });
  }

  void _setExpanded(bool value) {
    setState(() => _expanded = value);
    if (value) {
      _chevronController.forward();
    } else {
      _chevronController.reverse();
    }
  }

  void _toggleExpanded() {
    _collapseTimer?.cancel();
    _setExpanded(!_expanded);
  }

  void _handlePermissionAllow(
    Map<String, dynamic> permission,
  ) {
    final permId = permission['id'] as String?;
    if (permId == null || widget.sessionId == null) return;
    sync.sessionAllow(widget.sessionId!, permId);
  }

  void _handlePermissionDeny(Map<String, dynamic> permission) {
    final permId = permission['id'] as String?;
    if (permId == null || widget.sessionId == null) return;
    sync.sessionDeny(widget.sessionId!, permId);
  }

  void _handlePermissionAllowAllEdits(
    Map<String, dynamic> permission,
  ) {
    final permId = permission['id'] as String?;
    if (permId == null || widget.sessionId == null) return;
    sync.sessionAllow(
      widget.sessionId!,
      permId,
      mode: 'acceptEdits',
    );
  }

  void _handlePermissionAllowForSession(
    Map<String, dynamic> permission,
    String toolName,
    Map<String, dynamic>? toolInput,
  ) {
    final permId = permission['id'] as String?;
    if (permId == null || widget.sessionId == null) return;
    final List<String> allowTools;
    if (toolName == 'Bash') {
      final command = toolInput?['command'] as String? ?? '';
      allowTools = ['Bash($command)'];
    } else {
      allowTools = [toolName];
    }
    sync.sessionAllow(
      widget.sessionId!,
      permId,
      allowTools: allowTools,
    );
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _pulseController.dispose();
    _chevronController.dispose();
    super.dispose();
  }

  ToolState _parseToolState(String state) {
    switch (state) {
      case 'running':
        return ToolState.running;
      case 'completed':
        return ToolState.completed;
      case 'error':
        return ToolState.error;
      default:
        return ToolState.pending;
    }
  }

  /// Format MCP tool name for display.
  ///
  /// Example: `mcp__linear__create_issue` -> `Linear: Create Issue`
  String _formatMCPTitle(String toolName) {
    final withoutPrefix = toolName.replaceFirst('mcp__', '');
    final parts = withoutPrefix.split('__');
    if (parts.length >= 2) {
      final serverName = _snakeToPascal(parts[0]);
      final toolPart = _snakeToPascal(parts.skip(1).join('_'));
      return '$serverName: $toolPart';
    }
    return 'MCP: ${_snakeToPascal(withoutPrefix)}';
  }

  String _snakeToPascal(String str) {
    return str.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = widget.tool['name'] as String? ?? 'Unknown';
    final toolState = widget.tool['state'] as String? ?? 'pending';
    final toolInput = widget.tool['input'] as Map<String, dynamic>?;
    final toolResult = widget.tool['result'];
    final permission = widget.tool['permission'] as Map<String, dynamic>?;
    final createdAt = widget.tool['createdAt'] as int?;

    final knownTool = KnownTools.get(toolName);
    final isMCP = toolName.startsWith('mcp__');

    // Determine tool title
    var toolTitle = toolName;
    if (isMCP) {
      toolTitle = _formatMCPTitle(toolName);
    } else if (knownTool != null) {
      if (knownTool.title is String) {
        toolTitle = knownTool.title as String;
      } else if (knownTool.title is String Function(
        Map<String, dynamic>,
        Map<String, dynamic>?,
      )) {
        toolTitle = (knownTool.title as String Function(
          Map<String, dynamic>,
          Map<String, dynamic>?,
        ))(widget.tool, widget.metadata);
      }
    }

    // Extract status text
    String? status;
    if (knownTool?.extractStatus != null) {
      status = knownTool!.extractStatus!(widget.tool, widget.metadata);
    }

    // Extract subtitle
    String? subtitle;
    if (knownTool?.extractSubtitle != null) {
      subtitle = knownTool!.extractSubtitle!(widget.tool, widget.metadata);
    }

    // Determine minimal mode
    var minimal = knownTool?.minimal ?? true;
    if (isMCP) minimal = true;

    final state = _parseToolState(toolState);

    // Permission pending overrides accent colour
    final hasPermissionRequest =
        permission != null &&
        permission['status'] != 'denied' &&
        permission['status'] != 'canceled';
    final accentColor =
        hasPermissionRequest ? _permissionColor : _stateAccentColor(state);

    // Check for tool-use error
    final resultStr = toolResult?.toString() ?? '';
    final errorResult = ToolErrorParser.parse(resultStr);
    final isToolUseError = errorResult.isToolUseError;

    // Build status icon
    Widget? statusIcon;
    if (permission != null) {
      final permStatus = permission['status'] as String?;
      if (permStatus == 'denied' || permStatus == 'canceled') {
        statusIcon = Icon(
          Icons.remove_circle_outline,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        );
      }
    } else if (isToolUseError) {
      statusIcon = Icon(
        Icons.remove_circle_outline,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      );
    } else {
      switch (state) {
        case ToolState.running:
          statusIcon = _PulsingProgressIndicator(
            animation: _pulseAnim,
            size: 20,
          );
        case ToolState.error:
          statusIcon = Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.error,
          );
        case ToolState.completed:
        case ToolState.pending:
          break;
      }
    }

    // Build tool icon: emoji for MCP, KnownTools icon otherwise
    final Widget toolIcon;
    if (isMCP) {
      final serverToken =
          toolName.replaceFirst('mcp__', '').split('__').first;
      toolIcon = Text(
        _mcpServerEmoji(serverToken),
        style: const TextStyle(fontSize: 18),
      );
    } else {
      toolIcon = KnownTools.iconFor(
        toolName,
        24,
        theme.colorScheme.onSurfaceVariant,
      );
    }

    final hasContent = !minimal;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final borderOpacity =
            state == ToolState.running ? _pulseAnim.value : 1.0;
        final effectiveBorder = BorderSide(
          color: accentColor.withValues(alpha: borderOpacity),
          width: 2,
        );

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: effectiveBorder),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.onPress?.call();
                  _toggleExpanded();
                },
                child: _buildHeader(
                  context,
                  theme,
                  toolIcon,
                  toolTitle,
                  status,
                  subtitle,
                  state,
                  createdAt,
                  statusIcon,
                  hasContent,
                ),
              ),
              if (hasContent)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? _buildContent(
                          context,
                          knownTool,
                          toolInput,
                          toolResult,
                          state,
                          errorResult,
                          permission,
                        )
                      : const SizedBox.shrink(),
                ),
              if (permission != null &&
                  widget.sessionId != null &&
                  toolName != 'AskUserQuestion')
                PermissionFooter(
                  permission: permission,
                  sessionId: widget.sessionId!,
                  toolName: toolName,
                  toolInput: toolInput,
                  onAllow: () => _handlePermissionAllow(permission),
                  onDeny: () => _handlePermissionDeny(permission),
                  onAllowAllEdits: () =>
                      _handlePermissionAllowAllEdits(permission),
                  onAllowForSession: () =>
                      _handlePermissionAllowForSession(
                    permission,
                    toolName,
                    toolInput,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the header row with a subtle gradient background.
  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    Widget toolIcon,
    String toolTitle,
    String? status,
    String? subtitle,
    ToolState state,
    int? createdAt,
    Widget? statusIcon,
    bool hasContent,
  ) {
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final gradientTop = Color.lerp(
      baseColor,
      theme.colorScheme.surface,
      0.25,
    )!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientTop, baseColor],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: toolIcon,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        toolTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (status != null)
                      Text(
                        ' $status',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (state == ToolState.running && createdAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ElapsedTimeWidget(startTime: createdAt),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _showCheckFlash
                  ? Icon(
                      Icons.check_circle,
                      key: const ValueKey('flash'),
                      size: 20,
                      color: const Color(0xFF34C759),
                    )
                  : (statusIcon != null
                      ? SizedBox(
                          key: const ValueKey('status'),
                          child: statusIcon,
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('empty'),
                        )),
            ),
          ),
          if (hasContent)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: RotationTransition(
                turns: _chevronAnim,
                child: Icon(
                  Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ToolDefinition? knownTool,
    Map<String, dynamic>? toolInput,
    dynamic toolResult,
    ToolState state,
    ToolErrorParseResult errorResult,
    Map<String, dynamic>? permission,
  ) {
    final toolName = widget.tool['name'] as String? ?? '';
    final specificView = _getToolViewComponent(toolName);

    if (specificView != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            specificView(widget.tool, widget.metadata, widget.messages),
            if (state == ToolState.error &&
                toolResult != null &&
                permission != null &&
                permission['status'] != 'denied' &&
                permission['status'] != 'canceled' &&
                !(knownTool?.hideDefaultError ?? false) &&
                !errorResult.isToolUseError)
              ToolError(message: toolResult.toString()),
          ],
        ),
      );
    }

    // Default fallback content
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (toolInput != null)
            ToolSectionView(
              title: 'INPUT',
              child: _buildCodeBlock(toolInput.toString()),
            ),
          if (state == ToolState.completed && toolResult != null)
            ToolSectionView(
              title: 'OUTPUT',
              child: _buildCodeBlock(
                toolResult is String ? toolResult : toolResult.toString(),
              ),
            ),
          if (state == ToolState.error &&
              toolResult != null &&
              permission != null &&
              permission['status'] != 'denied' &&
              permission['status'] != 'canceled' &&
              !errorResult.isToolUseError)
            ToolError(message: toolResult.toString()),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFFD4D4D4),
        ),
      ),
    );
  }

  /// Returns a view builder for the named tool, or null for default fallback.
  Widget Function(
    Map<String, dynamic>,
    Map<String, dynamic>?,
    List<Map<String, dynamic>>?,
  )?
  _getToolViewComponent(String toolName) {
    final views = <
        String,
        Widget Function(
          Map<String, dynamic>,
          Map<String, dynamic>?,
          List<Map<String, dynamic>>?,
        )>{
      'Glob': (t, m, _) => GlobView(tool: t, metadata: m),
      'Grep': (t, m, _) => GrepView(tool: t, metadata: m),
      'LS': (t, m, _) => LSView(tool: t, metadata: m),
      'Read': (t, m, _) => ReadView(tool: t, metadata: m),
      'read': (t, m, _) => ReadView(tool: t, metadata: m),
      'Edit': (t, m, _) => EditView(tool: t, metadata: m),
      'MultiEdit': (t, m, _) => MultiEditView(tool: t, metadata: m),
      'Write': (t, m, _) => WriteView(tool: t, metadata: m),
      'edit': (t, m, _) => GeminiEditView(tool: t, metadata: m),
      'Bash': (t, m, _) => BashView(tool: t, metadata: m),
      'CodexBash': (t, m, _) => CodexBashView(tool: t, metadata: m),
      'execute': (t, m, _) => GeminiExecuteView(tool: t, metadata: m),
      'CodexPatch': (t, m, _) => CodexPatchView(tool: t, metadata: m),
      'CodexDiff': (t, m, _) => CodexDiffView(tool: t, metadata: m),
      'Task': (t, m, msgs) =>
          TaskView(tool: t, metadata: m, messages: msgs),
      'TodoWrite': (t, m, _) => TodoView(tool: t, metadata: m),
      'WebFetch': (t, m, _) => WebFetchView(tool: t, metadata: m),
      'WebSearch': (t, m, _) => WebSearchView(tool: t, metadata: m),
      'ExitPlanMode': (t, m, _) => ExitPlanToolView(tool: t, metadata: m),
      'exit_plan_mode': (t, m, _) =>
          ExitPlanToolView(tool: t, metadata: m),
      'AskUserQuestion': _buildAskUserQuestionView,
      'NotebookRead': (t, m, _) => ReadView(tool: t, metadata: m),
      'NotebookEdit': (t, m, _) => EditView(tool: t, metadata: m),
    };
    return views[toolName];
  }

  Widget _buildAskUserQuestionView(
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? messages,
  ) {
    final toolUseId =
        tool['toolUseId'] as String? ?? tool['id'] as String?;
    return AskUserQuestionView(
      key: toolUseId != null ? ValueKey('ask-$toolUseId') : null,
      tool: tool,
      metadata: metadata,
      sessionId: widget.sessionId,
    );
  }
}

/// A [CircularProgressIndicator] whose opacity pulses via [animation].
class _PulsingProgressIndicator extends StatelessWidget {
  const _PulsingProgressIndicator({
    required this.animation,
    required this.size,
  });

  /// The pulsing opacity animation (0.3 -> 1.0 loop).
  final Animation<double> animation;

  /// Diameter of the indicator in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: child,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// Compact tool view for minimal mode (header only, no expandable content).
class ToolViewMinimal extends StatelessWidget {
  /// Creates a [ToolViewMinimal].
  const ToolViewMinimal({
    required this.tool,
    super.key,
    this.metadata,
  });

  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata (e.g., working directory).
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = tool['name'] as String? ?? 'Unknown';
    final state = tool['state'] as String? ?? 'pending';
    final createdAt = tool['createdAt'] as int?;

    final icon = KnownTools.iconFor(
      toolName,
      18,
      theme.colorScheme.onSurfaceVariant,
    );
    final title = KnownTools.titleFor(toolName, tool, metadata);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state == 'running' && createdAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ElapsedTimeWidget(startTime: createdAt),
            ),
          const SizedBox(width: 4),
          ToolStatusIndicator(state: _parseState(state), size: 16),
        ],
      ),
    );
  }

  ToolState _parseState(String state) {
    switch (state) {
      case 'running':
        return ToolState.running;
      case 'completed':
        return ToolState.completed;
      case 'error':
        return ToolState.error;
      default:
        return ToolState.pending;
    }
  }
}
