import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/services/sync_service.dart';
import '../utils/tool_error_parser.dart';
import 'elapsed_time.dart';
import 'json_viewer.dart';
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
const _kAutoCollapseDelay = Duration(seconds: 8);

/// Returns the left border accent color for a given tool state.
Color _stateAccentColor(ToolState state, ColorScheme cs) {
  switch (state) {
    case ToolState.running:
      return cs.primary;
    case ToolState.completed:
      return AppColors.success; // semantic green brand color
    case ToolState.error:
      return cs.error;
    case ToolState.pending:
      return cs.onSurfaceVariant;
  }
}

/// Returns the background color for the status badge.
Color _statusBadgeBg(ToolState state, ColorScheme cs) {
  switch (state) {
    case ToolState.running:
      return cs.primary;
    case ToolState.completed:
      return AppColors.success; // semantic green brand color
    case ToolState.error:
      return cs.error;
    case ToolState.pending:
      return cs.onSurfaceVariant;
  }
}

/// Returns label text for the status badge.
String _statusBadgeLabel(ToolState state) {
  switch (state) {
    case ToolState.running:
      return 'Running';
    case ToolState.completed:
      return 'Done';
    case ToolState.error:
      return 'Error';
    case ToolState.pending:
      return 'Pending';
  }
}

/// Accent color for permission-required state (orange).
const Color _permissionColor = AppColors.warning;

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

/// Permission action kinds emitted from [ToolView].
enum PermissionActionKind {
  allow,
  deny,
  allowAllEdits,
  allowForSession,
  codexApprove,
  codexApproveForSession,
  codexAbort,
}

/// Structured permission action payload for tool permission interactions.
class PermissionAction {
  const PermissionAction({
    required this.kind,
    required this.sessionId,
    required this.permissionId,
    required this.toolName,
    this.toolInput,
  });

  final PermissionActionKind kind;
  final String sessionId;
  final String permissionId;
  final String toolName;
  final Map<String, dynamic>? toolInput;
}

/// Optional delegate for handling permission actions.
typedef PermissionActionDelegate =
    Future<void> Function(PermissionAction action);

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

    final initial = _parseToolState(
      widget.tool['state'] as String? ?? 'pending',
    );
    _prevState = initial;

    final initPermission = widget.tool['permission'] as Map<String, dynamic>?;
    final hasPermissionRequest =
        initPermission != null &&
        initPermission['status'] != 'approved' &&
        initPermission['status'] != 'denied' &&
        initPermission['status'] != 'canceled';

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

    final newState = _parseToolState(
      widget.tool['state'] as String? ?? 'pending',
    );

    final updatedPermission =
        widget.tool['permission'] as Map<String, dynamic>?;
    final hasPermissionRequest =
        updatedPermission != null &&
        updatedPermission['status'] != 'approved' &&
        updatedPermission['status'] != 'denied' &&
        updatedPermission['status'] != 'canceled';

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
    } else if (_prevState == ToolState.running && newState == ToolState.error) {
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

  Future<void> _handlePermissionAllow(
    Map<String, dynamic> permission,
    String toolName,
    Map<String, dynamic>? toolInput,
  ) async {
    await _emitPermissionAction(
      kind: PermissionActionKind.allow,
      permission: permission,
      toolName: toolName,
      toolInput: toolInput,
    );
  }

  Future<void> _handlePermissionDeny(
    Map<String, dynamic> permission,
    String toolName,
    Map<String, dynamic>? toolInput,
  ) async {
    await _emitPermissionAction(
      kind: PermissionActionKind.deny,
      permission: permission,
      toolName: toolName,
      toolInput: toolInput,
    );
  }

  Future<void> _handlePermissionAllowAllEdits(
    Map<String, dynamic> permission,
    String toolName,
    Map<String, dynamic>? toolInput,
  ) async {
    await _emitPermissionAction(
      kind: PermissionActionKind.allowAllEdits,
      permission: permission,
      toolName: toolName,
      toolInput: toolInput,
    );
  }

  Future<void> _handlePermissionAllowForSession(
    Map<String, dynamic> permission,
    String toolName,
    Map<String, dynamic>? toolInput,
  ) async {
    await _emitPermissionAction(
      kind: PermissionActionKind.allowForSession,
      permission: permission,
      toolName: toolName,
      toolInput: toolInput,
    );
  }

  Future<void> _handleCodexApprove(
    Map<String, dynamic> permission,
    String toolName,
    Map<String, dynamic>? toolInput,
  ) async {
    await _emitPermissionAction(
      kind: PermissionActionKind.codexApprove,
      permission: permission,
      toolName: toolName,
      toolInput: toolInput,
    );
  }

  Future<void> _handleCodexApproveForSession(
    Map<String, dynamic> permission,
    String toolName,
    Map<String, dynamic>? toolInput,
  ) async {
    await _emitPermissionAction(
      kind: PermissionActionKind.codexApproveForSession,
      permission: permission,
      toolName: toolName,
      toolInput: toolInput,
    );
  }

  Future<void> _handleCodexAbort(
    Map<String, dynamic> permission,
    String toolName,
    Map<String, dynamic>? toolInput,
  ) async {
    await _emitPermissionAction(
      kind: PermissionActionKind.codexAbort,
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

    final state = _parseToolState(toolState);

    // Permission pending overrides accent colour
    final hasPermissionRequest =
        permission != null &&
        permission['status'] != 'approved' &&
        permission['status'] != 'denied' &&
        permission['status'] != 'canceled';
    final accentColor = hasPermissionRequest
        ? _permissionColor
        : _stateAccentColor(state, theme.colorScheme);

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
      final serverToken = toolName.replaceFirst('mcp__', '').split('__').first;
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
          child: _ToolHeader(
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
            onAllow: () =>
                _handlePermissionAllow(permission, toolName, toolInput),
            onDeny: () =>
                _handlePermissionDeny(permission, toolName, toolInput),
            onAllowAllEdits: () =>
                _handlePermissionAllowAllEdits(permission, toolName, toolInput),
            onAllowForSession: () => _handlePermissionAllowForSession(
              permission,
              toolName,
              toolInput,
            ),
            onCodexApprove: () =>
                _handleCodexApprove(permission, toolName, toolInput),
            onCodexApproveForSession: () =>
                _handleCodexApproveForSession(permission, toolName, toolInput),
            onCodexAbort: () =>
                _handleCodexAbort(permission, toolName, toolInput),
          ),
      ],
    );

    return AnimatedBuilder(
      animation: _pulseAnim,
      child: invariantChild,
      builder: (context, child) {
        final borderOpacity = state == ToolState.running
            ? _pulseAnim.value
            : 1.0;
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
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
    final toolId =
        widget.tool['toolUseId'] as String? ??
        widget.tool['id'] as String? ??
        toolName;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
      ),
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
            _CollapsibleOutput(
              toolId: toolId,
              child: ToolSectionView(
                title: 'OUTPUT',
                child: SmartOutputContainer(
                  content: toolResult,
                ),
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
  Widget Function(
    Map<String, dynamic>,
    Map<String, dynamic>?,
    List<Map<String, dynamic>>?,
  )?
  _getToolViewComponent(String toolName) {
    // Fast path: avoid allocating the map for unknown tool names.
    if (!_knownToolNames.contains(toolName)) return null;

    final views =
        <
          String,
          Widget Function(
            Map<String, dynamic>,
            Map<String, dynamic>?,
            List<Map<String, dynamic>>?,
          )
        >{
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
          'Task': (t, m, msgs) => TaskView(
            tool: t,
            metadata: m,
            messages: msgs,
            onNavigate: () => widget.onPress?.call(),
          ),
          'Agent': (t, m, msgs) => TaskView(
            tool: t,
            metadata: m,
            messages: msgs,
            onNavigate: () => widget.onPress?.call(),
          ),
          'TodoWrite': (t, m, _) => TodoView(tool: t, metadata: m),
          'WebFetch': (t, m, _) => WebFetchView(tool: t, metadata: m),
          'WebSearch': (t, m, _) => WebSearchView(tool: t, metadata: m),
          'ExitPlanMode': (t, m, _) => ExitPlanToolView(tool: t, metadata: m),
          'exit_plan_mode': (t, m, _) => ExitPlanToolView(tool: t, metadata: m),
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
    final toolUseId = tool['toolUseId'] as String? ?? tool['id'] as String?;
    return AskUserQuestionView(
      key: toolUseId != null ? ValueKey('ask-$toolUseId') : null,
      tool: tool,
      metadata: metadata,
      sessionId: widget.sessionId,
    );
  }
}

// ---------------------------------------------------------------------------
// Extracted private widget classes for composability
// ---------------------------------------------------------------------------

/// Header row for a tool card — icon, title, status badge, elapsed time,
/// check flash, and expand/collapse chevron.
class _ToolHeader extends StatelessWidget {
  const _ToolHeader({
    required this.toolIcon,
    required this.toolTitle,
    required this.state,
    required this.hasContent,
    required this.showCheckFlash,
    required this.chevronAnim,
    required this.hasPermissionRequest,
    this.status,
    this.subtitle,
    this.createdAt,
    this.statusIcon,
  });

  /// The leading icon widget for this tool type.
  final Widget toolIcon;

  /// The resolved display title for this tool.
  final String toolTitle;

  /// Optional inline status text shown after the title.
  final String? status;

  /// Optional subtitle shown below the title.
  final String? subtitle;

  /// The current execution state.
  final ToolState state;

  /// Unix-ms timestamp when the tool started (for elapsed time).
  final int? createdAt;

  /// Optional status icon override (error/denied/cancelled).
  final Widget? statusIcon;

  /// Whether this tool card has expandable content.
  final bool hasContent;

  /// Whether to show the green check-circle flash animation.
  final bool showCheckFlash;

  /// The chevron rotation animation (0 = collapsed, 0.5 = expanded).
  final Animation<double> chevronAnim;

  /// Whether a permission request is currently pending.
  final bool hasPermissionRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sm),
          topRight: Radius.circular(AppRadius.sm),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Align(alignment: Alignment.centerLeft, child: toolIcon),
          ),
          const SizedBox(width: AppSpacing.sm),
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
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          fontFamilyFallback: const ['Courier New', 'Courier'],
                          fontSize: 13,
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
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Status badge pill
          if (!hasPermissionRequest) ...[
            const SizedBox(width: AppSpacing.sm - 2),
            _ToolStatusBadge(state: state),
          ],
          // Elapsed time while running
          if (state == ToolState.running && createdAt != null) ...[
            const SizedBox(width: AppSpacing.sm - 2),
            _ToolDuration(startTime: createdAt!),
          ],
          // Status icon / check flash
          const SizedBox(width: AppSpacing.sm - 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: showCheckFlash
                ? Icon(
                    Icons.check_circle,
                    key: const ValueKey('flash'),
                    size: 20,
                    color: AppColors.success,
                  )
                : (statusIcon != null
                      ? SizedBox(
                          key: const ValueKey('status'),
                          child: statusIcon,
                        )
                      : const SizedBox.shrink(key: ValueKey('empty'))),
          ),
          // Expand/collapse chevron
          if (hasContent) ...[
            const SizedBox(width: AppSpacing.sm - 2),
            RotationTransition(
              turns: chevronAnim,
              child: Icon(
                Icons.expand_more,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact status pill showing Running / ✓ / ✕ / Pending.
///
/// 20px tall pill with 0.15-opacity background and matching colour.
/// Completed and error states show an icon; others show text.
class _ToolStatusBadge extends StatelessWidget {
  const _ToolStatusBadge({required this.state});

  /// The current execution state.
  final ToolState state;

  @override
  Widget build(BuildContext context) {
    final bg = _statusBadgeBg(state, Theme.of(context).colorScheme);

    final Widget child;
    if (state == ToolState.completed) {
      child = Icon(Icons.check, size: 12, color: bg);
    } else if (state == ToolState.error) {
      child = Icon(Icons.close, size: 12, color: bg);
    } else {
      child = Text(
        _statusBadgeLabel(state),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: bg,
          letterSpacing: 0.2,
        ),
      );
    }

    return Container(
      height: 20,
      width: (state == ToolState.completed || state == ToolState.error)
          ? 20
          : null,
      padding: (state == ToolState.completed || state == ToolState.error)
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bg.withValues(alpha: 0.35), width: 0.5),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Elapsed time label — only visible while the tool is running.
class _ToolDuration extends StatelessWidget {
  const _ToolDuration({required this.startTime});

  /// The Unix-ms timestamp when the tool started.
  final int startTime;

  @override
  Widget build(BuildContext context) {
    return ElapsedTimeWidget(startTime: startTime);
  }
}


/// Wraps tool output in a height-constrained container with a
/// "Show more" / "Show less" toggle button.
///
/// When collapsed the content is clipped at [_kCollapsedHeight]
/// logical pixels. Tapping the toggle reveals or hides the full
/// output with an animated transition.
class _CollapsibleOutput extends StatefulWidget {
  const _CollapsibleOutput({
    required this.toolId,
    required this.child,
  });

  /// Unique identifier used to track expansion state.
  final String toolId;

  /// The output content widget to wrap.
  final Widget child;

  @override
  State<_CollapsibleOutput> createState() =>
      _CollapsibleOutputState();
}

class _CollapsibleOutputState extends State<_CollapsibleOutput> {
  static const double _kCollapsedHeight = 200;

  bool _expanded = false;
  final GlobalKey _contentKey = GlobalKey();
  double? _contentHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureContent();
    });
  }

  void _measureContent() {
    final box = _contentKey.currentContext
        ?.findRenderObject() as RenderBox?;
    if (box != null && mounted) {
      setState(() {
        _contentHeight = box.size.height;
      });
    }
  }

  bool get _needsCollapsing =>
      _contentHeight != null &&
      _contentHeight! > _kCollapsedHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If the content fits within the threshold, render it
    // directly without any collapse mechanism.
    if (!_needsCollapsing) {
      return KeyedSubtree(
        key: _contentKey,
        child: widget.child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppDuration.normal,
          curve: AppCurve.standard,
          constraints: BoxConstraints(
            maxHeight: _expanded
                ? _contentHeight!
                : _kCollapsedHeight,
          ),
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: widget.child,
        ),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      builder: (context, child) =>
          Opacity(opacity: animation.value, child: child),
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
  const ToolViewMinimal({required this.tool, super.key, this.metadata});

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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state == 'running' && createdAt != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: ElapsedTimeWidget(startTime: createdAt),
            ),
          const SizedBox(width: AppSpacing.xs),
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
