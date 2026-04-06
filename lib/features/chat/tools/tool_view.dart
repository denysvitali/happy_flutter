import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/services/sync_service.dart';
import '../../../core/utils/tool_error_parser.dart';
import '../../../core/utils/wire_parsers.dart';
import 'json_viewer.dart';
import 'known_tools.dart';
import 'permission_footer.dart';
import 'tool_error.dart';
import 'tool_section_view.dart';
import 'tool_status_indicator.dart' show ToolState;
import 'tool_view_helpers.dart';
import 'tool_view_widgets.dart';
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

// Re-export public helpers so existing imports continue to work.
export 'tool_view_helpers.dart'
    show
        parseToolState,
        PermissionActionKind,
        PermissionAction,
        PermissionActionDelegate;
export 'tool_view_minimal.dart' show ToolViewMinimal;

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
    this.isSessionOnline = true,
    this.onPress,
    this.permissionActionDelegate,
  });

  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata (e.g., working directory).
  final Map<String, dynamic>? metadata;

  /// Optional list of messages (for Task tool).
  final List<Map<String, dynamic>>? messages;

  /// Session ID for permission actions.
  final String? sessionId;

  /// Whether the session's CLI process is currently online.
  final bool isSessionOnline;

  /// Callback when the tool header is pressed.
  final VoidCallback? onPress;

  /// Optional handler override for permission actions.
  final PermissionActionDelegate? permissionActionDelegate;

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
      duration: const Duration(milliseconds: 250),
    );
    _chevronAnim = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronController, curve: Curves.easeInOut),
    );

    final initial = parseToolState(
      widget.tool['state'] as String? ?? 'pending',
    );
    _prevState = initial;

    final initPermission =
        WireParsers.asMap(widget.tool['permission']);
    final hasPermissionRequest = isPermissionPending(initPermission);

    if (initial == ToolState.running || hasPermissionRequest) {
      _expanded = true;
      _chevronController.forward();
      if (initial == ToolState.running) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _expanded = false;
    }
  }

  @override
  void didUpdateWidget(ToolView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newState = parseToolState(
      widget.tool['state'] as String? ?? 'pending',
    );

    final updatedPermission =
        WireParsers.asMap(widget.tool['permission']);
    final hasPermissionRequest = isPermissionPending(updatedPermission);

    if (hasPermissionRequest && !_expanded) {
      _setExpanded(true);
    }

    if (_prevState == newState) return;

    if (_prevState == ToolState.running && newState == ToolState.completed) {
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

  bool get _isPlanTool {
    final name = widget.tool['name'] as String? ?? '';
    return name == 'ExitPlanMode' || name == 'exit_plan_mode';
  }

  void _scheduleAutoCollapse() {
    // Never auto-collapse plan tools — the plan must stay visible.
    if (_isPlanTool) return;
    _collapseTimer?.cancel();
    _collapseTimer = Timer(kAutoCollapseDelay, () {
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

  /// Unified handler for all permission actions.
  Future<void> _handlePermission(
    PermissionActionKind kind,
    Map<String, dynamic> permission,
    String toolName,
    Map<String, dynamic>? toolInput,
  ) async {
    await _emitPermissionAction(
      kind: kind,
      permission: permission,
      toolName: toolName,
      toolInput: toolInput,
    );
  }

  Future<void> _emitPermissionAction({
    required PermissionActionKind kind,
    required Map<String, dynamic> permission,
    required String toolName,
    required Map<String, dynamic>? toolInput,
  }) async {
    final permId = _resolvePermissionId(permission);
    final sessionId = widget.sessionId;
    if (sessionId == null) {
      logger.warning('[ToolView] permission action ignored: missing sessionId');
      return;
    }
    if (permId == null) {
      logger.warning(
        '[ToolView] permission action ignored: missing permission id '
        'for tool=$toolName keys=${permission.keys.toList()}',
      );
      return;
    }

    final action = PermissionAction(
      kind: kind,
      sessionId: sessionId,
      permissionId: permId,
      toolName: toolName,
      toolInput: toolInput,
    );

    final delegate = widget.permissionActionDelegate;
    if (delegate != null) {
      await delegate(action);
      return;
    }

    await _performPermissionAction(action);
  }

  String? _resolvePermissionId(Map<String, dynamic> permission) {
    final candidates = <dynamic>[
      permission['id'],
      permission['requestId'],
      permission['request_id'],
      permission['toolUseId'],
      permission['tool_use_id'],
      widget.tool['toolUseId'],
      widget.tool['id'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<void> _performPermissionAction(PermissionAction action) async {
    switch (action.kind) {
      case PermissionActionKind.allow:
        await sync.sessionAllow(action.sessionId, action.permissionId);
      case PermissionActionKind.deny:
        await sync.sessionDeny(action.sessionId, action.permissionId);
      case PermissionActionKind.allowAllEdits:
        await sync.sessionAllow(
          action.sessionId,
          action.permissionId,
          mode: 'acceptEdits',
        );
      case PermissionActionKind.allowForSession:
        final List<String> allowTools;
        if (action.toolName == 'Bash') {
          final command = action.toolInput?['command'] as String? ?? '';
          allowTools = ['Bash($command)'];
        } else {
          allowTools = [action.toolName];
        }
        await sync.sessionAllow(
          action.sessionId,
          action.permissionId,
          allowTools: allowTools,
        );
      case PermissionActionKind.codexApprove:
        await sync.sessionAllow(
          action.sessionId,
          action.permissionId,
          decision: 'approved',
        );
      case PermissionActionKind.codexApproveForSession:
        await sync.sessionAllow(
          action.sessionId,
          action.permissionId,
          decision: 'approved_for_session',
        );
      case PermissionActionKind.codexAbort:
        await sync.sessionDeny(
          action.sessionId,
          action.permissionId,
          decision: 'abort',
        );
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _pulseController.dispose();
    _chevronController.dispose();
    super.dispose();
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
    return str
        .split('_')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = widget.tool['name'] as String? ?? 'Unknown';
    final toolState = widget.tool['state'] as String? ?? 'pending';
    final toolInput = WireParsers.asMap(widget.tool['input']);
    final toolResult = widget.tool['result'];
    final permission = WireParsers.asMap(widget.tool['permission']);
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
      } else if (knownTool.title
          is String Function(Map<String, dynamic>, Map<String, dynamic>?)) {
        toolTitle =
            (knownTool.title
                as String Function(
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
    final bool minimal;
    if (knownTool != null) {
      minimal = knownTool.minimal;
    } else {
      // Unknown/MCP tools: always minimal — details via tap/long-press only.
      minimal = true;
    }

    final state = parseToolState(toolState);

    // Permission pending overrides accent colour
    final hasPermissionRequest = isPermissionPending(permission);
    final accentColor = hasPermissionRequest
        ? permissionColor
        : stateColor(state, theme.colorScheme);

    // Check for tool-use error
    final resultStr = toolResult?.toString() ?? '';
    final errorResult = ToolErrorParser.parse(resultStr);
    final isToolUseError = errorResult != null;

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
          statusIcon = PulsingProgressIndicator(
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
        mcpServerEmoji(serverToken),
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

    // Build the invariant children outside the AnimatedBuilder so they are
    // not rebuilt on every pulse animation frame (60 fps while running).
    final invariantChild = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (hasContent) {
              _toggleExpanded();
            } else {
              widget.onPress?.call();
            }
          },
          onLongPress: widget.onPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  widget.onPress!.call();
                }
              : null,
          child: ToolHeader(
            toolIcon: toolIcon,
            toolTitle: toolTitle,
            status: status,
            subtitle: subtitle,
            state: state,
            createdAt: createdAt,
            statusIcon: statusIcon,
            hasContent: hasContent,
            showCheckFlash: _showCheckFlash,
            chevronAnim: _chevronAnim,
            hasPermissionRequest: hasPermissionRequest,
          ),
        ),
        if (hasContent)
          AnimatedSize(
            duration: AppDuration.normal,
            curve: AppCurve.standard,
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
            flavor: widget.metadata?['flavor'] as String?,
            isSessionOnline: widget.isSessionOnline,
            onAllow: () => _handlePermission(
              PermissionActionKind.allow,
              permission,
              toolName,
              toolInput,
            ),
            onDeny: () => _handlePermission(
              PermissionActionKind.deny,
              permission,
              toolName,
              toolInput,
            ),
            onAllowAllEdits: () => _handlePermission(
              PermissionActionKind.allowAllEdits,
              permission,
              toolName,
              toolInput,
            ),
            onAllowForSession: () => _handlePermission(
              PermissionActionKind.allowForSession,
              permission,
              toolName,
              toolInput,
            ),
            onCodexApprove: () => _handlePermission(
              PermissionActionKind.codexApprove,
              permission,
              toolName,
              toolInput,
            ),
            onCodexApproveForSession: () => _handlePermission(
              PermissionActionKind.codexApproveForSession,
              permission,
              toolName,
              toolInput,
            ),
            onCodexAbort: () => _handlePermission(
              PermissionActionKind.codexAbort,
              permission,
              toolName,
              toolInput,
            ),
          ),
      ],
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseAnim,
        child: invariantChild,
        builder: (context, child) {
          final borderOpacity =
              state == ToolState.running ? _pulseAnim.value : 1.0;
          final accentBorder = BorderSide(
            color: accentColor.withValues(alpha: borderOpacity),
            width: 4,
          );
          final sideBorder = BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: 1,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
            child: ClipRRect(
              clipBehavior: Clip.hardEdge,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border(
                    left: accentBorder,
                    top: sideBorder,
                    right: sideBorder,
                    bottom: sideBorder,
                  ),
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ToolDefinition? knownTool,
    Map<String, dynamic>? toolInput,
    dynamic toolResult,
    ToolState state,
    ParsedToolError? errorResult,
    Map<String, dynamic>? permission,
  ) {
    final toolName = widget.tool['name'] as String? ?? '';
    final specificView = _getToolViewComponent(toolName);

    if (specificView != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            specificView(
              widget.tool,
              widget.metadata,
              widget.messages,
              widget.sessionId,
            ),
            if (state == ToolState.error &&
                toolResult != null &&
                isPermissionNotDeniedOrCanceled(permission) &&
                !(knownTool?.hideDefaultError ?? false) &&
                !(errorResult?.isToolUseError ?? false))
              ToolError(message: toolResult.toString()),
          ],
        ),
      );
    }

    // Default fallback content
    final toolId =
        widget.tool['toolUseId'] as String? ??
        widget.tool['id'] as String? ??
        toolName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (toolInput != null)
            ToolSectionView(
              title: 'INPUT',
              child: SmartOutputContainer(content: toolInput),
            ),
          if (state == ToolState.completed && toolResult != null)
            CollapsibleOutput(
              toolId: toolId,
              child: ToolSectionView(
                title: 'OUTPUT',
                child: SmartOutputContainer(content: toolResult),
              ),
            ),
          if (state == ToolState.error &&
              toolResult != null &&
              isPermissionNotDeniedOrCanceled(permission) &&
              !(errorResult?.isToolUseError ?? false))
            ToolError(message: toolResult.toString()),
        ],
      ),
    );
  }

  // Static set of known tool names — used to skip the per-call map allocation
  // when the tool name is not in the set.
  static const Set<String> _knownToolNames = {
    'Glob',
    'Grep',
    'LS',
    'Read',
    'read',
    'Edit',
    'MultiEdit',
    'Write',
    'edit',
    'Bash',
    'CodexBash',
    'execute',
    'CodexPatch',
    'CodexDiff',
    'Task',
    'Agent',
    'TodoWrite',
    'WebFetch',
    'WebSearch',
    'ExitPlanMode',
    'exit_plan_mode',
    'AskUserQuestion',
    'NotebookRead',
    'NotebookEdit',
  };

  /// Returns a view builder for the named tool, or null for default fallback.
  ///
  /// The lambda map is only allocated when [toolName] is a known tool, and
  /// immediately discarded after the single lookup — avoiding repeated large
  /// allocations at 60 fps when a tool is running.
  ToolViewBuilder? _getToolViewComponent(String toolName) {
    // Fast path: avoid allocating the map for unknown tool names.
    if (!_knownToolNames.contains(toolName)) return null;

    final views = <String, ToolViewBuilder>{
      'Glob': (t, m, _, s) => GlobView(tool: t, metadata: m),
      'Grep': (t, m, _, s) => GrepView(tool: t, metadata: m),
      'LS': (t, m, _, s) => LSView(tool: t, metadata: m),
      'Read': (t, m, _, s) => ReadView(tool: t, metadata: m, sessionId: s),
      'read': (t, m, _, s) => ReadView(tool: t, metadata: m, sessionId: s),
      'Edit': (t, m, _, s) => EditView(tool: t, metadata: m, sessionId: s),
      'MultiEdit': (t, m, _, s) => MultiEditView(tool: t, metadata: m),
      'Write': (t, m, _, s) => WriteView(tool: t, metadata: m),
      'edit': (t, m, _, s) => GeminiEditView(tool: t, metadata: m),
      'Bash': (t, m, _, s) => BashView(tool: t, metadata: m),
      'CodexBash': (t, m, _, s) => CodexBashView(tool: t, metadata: m),
      'execute': (t, m, _, s) => GeminiExecuteView(tool: t, metadata: m),
      'CodexPatch': (t, m, _, s) => CodexPatchView(tool: t, metadata: m),
      'CodexDiff': (t, m, _, s) => CodexDiffView(tool: t, metadata: m),
      'Task': (t, m, msgs, s) => TaskView(
        tool: t,
        metadata: m,
        messages: msgs,
        onNavigate: () => widget.onPress?.call(),
      ),
      'Agent': (t, m, msgs, s) => TaskView(
        tool: t,
        metadata: m,
        messages: msgs,
        onNavigate: () => widget.onPress?.call(),
      ),
      'TodoWrite': (t, m, _, s) => TodoView(tool: t, metadata: m),
      'WebFetch': (t, m, _, s) => WebFetchView(tool: t, metadata: m),
      'WebSearch': (t, m, _, s) => WebSearchView(tool: t, metadata: m),
      'ExitPlanMode': (t, m, _, s) => ExitPlanToolView(tool: t, metadata: m),
      'exit_plan_mode': (t, m, _, s) =>
          ExitPlanToolView(tool: t, metadata: m),
      'AskUserQuestion': _buildAskUserQuestionView,
      'NotebookRead': (t, m, _, s) =>
          ReadView(tool: t, metadata: m, sessionId: s),
      'NotebookEdit': (t, m, _, s) =>
          EditView(tool: t, metadata: m, sessionId: s),
    };
    return views[toolName];
  }

  Widget _buildAskUserQuestionView(
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? messages,
    String? sessionId,
  ) {
    final toolUseId = tool['toolUseId'] as String? ?? tool['id'] as String?;
    return AskUserQuestionView(
      key: toolUseId != null ? ValueKey('ask-$toolUseId') : null,
      tool: tool,
      metadata: metadata,
      sessionId: widget.sessionId,
    );
  }
}
