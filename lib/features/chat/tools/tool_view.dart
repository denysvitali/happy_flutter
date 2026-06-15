import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/utils.dart' show prettyJson;
import '../../../core/providers/app_providers.dart';
import '../../../core/services/logger_service.dart' show logger;
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
import 'views/task_tool_view.dart';
import 'views/task_view.dart';
import 'views/todo_view.dart';
import 'views/web_fetch_view.dart';
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
class ToolView extends ConsumerStatefulWidget {
  /// Creates a [ToolView].
  const ToolView({
    required this.tool,
    super.key,
    this.metadata,
    this.sessionId,
    this.isSessionOnline = true,
    this.onPress,
    this.permissionActionDelegate,
  });

  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata (e.g., working directory).
  final Map<String, dynamic>? metadata;

  /// Session ID for permission actions.
  final String? sessionId;

  /// Whether the session's CLI process is currently online.
  final bool isSessionOnline;

  /// Callback when the tool header is pressed.
  final VoidCallback? onPress;

  /// Optional handler override for permission actions.
  final PermissionActionDelegate? permissionActionDelegate;

  @override
  ConsumerState<ToolView> createState() => _ToolViewState();
}

// Total duration for one full stagger-fade-out sequence across all children.
const _kStaggerTotalMs = 220;
// Per-child fade window as a fraction of the total sequence duration.
const _kStaggerFadeWindow = 0.55;
// Vertical offset (logical pixels) that children slide down while fading out.
const _kStaggerSlideOffset = 6.0;

class _ToolViewState extends ConsumerState<ToolView>
    with TickerProviderStateMixin {
  // Default to collapsed. Tools that need to be visible while running (e.g.
  // Bash with streaming output) explicitly expand in [didUpdateWidget];
  // task-family tools (TaskCreate/Update/List/Get, TodoWrite) never auto-expand.
  // One-tap preview is a header summary — full body and raw JSON are reached
  // via long-press → [MessageDetailScreen].
  bool _expanded = false;
  bool _showCheckFlash = false;
  bool _collapsing = false;
  ToolState? _prevState;
  Timer? _collapseTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  late final AnimationController _chevronController;
  late final Animation<double> _chevronAnim;

  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();

    _maybePushTaskTool();

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

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kStaggerTotalMs),
    );

    final initial = parseToolState(
      widget.tool['state'] as String? ?? 'pending',
    );
    _prevState = initial;

    final initPermission = WireParsers.asMap(widget.tool['permission']);
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

    // Task tool results need to reach the global notifier even when this
    // tool is auto-collapsed — the body that would normally push the state
    // is unmounted in that case. Push from here so the session banner and
    // Zen list stay in sync with the latest tool data.
    if (!identical(widget.tool, oldWidget.tool)) {
      _maybePushTaskTool();
    }

    final newState = parseToolState(
      widget.tool['state'] as String? ?? 'pending',
    );

    final updatedPermission = WireParsers.asMap(widget.tool['permission']);
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
    } else if (_prevState == ToolState.running && newState == ToolState.error) {
      _pulseController
        ..stop()
        ..reset();
      _scheduleAutoCollapse();
    } else if (newState == ToolState.running) {
      _collapseTimer?.cancel();
      // Task-family tools never auto-expand: their body is a short summary
      // (subject/activeForm/status) and forcing it open just to flash it
      // closed is noise. The header subtitle carries the same info, and
      // the full task body is reachable via long-press → details.
      if (!_expanded && !_isTaskTool) _setExpanded(true);
      _pulseController.repeat(reverse: true);
    }

    _prevState = newState;
  }

  bool get _isPlanTool {
    final name = widget.tool['name'] as String? ?? '';
    return name == 'ExitPlanMode' || name == 'exit_plan_mode';
  }

  bool get _isTaskTool {
    final name = widget.tool['name'] as String? ?? '';
    return name == 'TaskCreate' ||
        name == 'TaskUpdate' ||
        name == 'TaskList' ||
        name == 'TaskGet';
  }

  /// Forward task-tool data to the global todo notifier.
  ///
  /// Done at the [ToolView] level (always mounted) rather than inside the
  /// task-specific body (only mounted while expanded) so a tool that
  /// completes while collapsed still updates the session banner / Zen list.
  ///
  /// Deferred to post-frame: this runs from initState/didUpdateWidget
  /// (i.e. during build), and the notifier push rebuilds widgets outside
  /// this subtree (session banner), which is illegal mid-build.
  void _maybePushTaskTool() {
    if (!_isTaskTool) return;
    final tool = widget.tool;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TaskToolView.pushToolToGlobalState(
        context,
        tool,
        widget.sessionId,
      );
    });
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
    if (!value && _expanded && !_collapsing) {
      // Start stagger-fade sequence before AnimatedSize collapses.
      setState(() => _collapsing = true);
      _staggerController
        ..reset()
        ..forward().whenCompleteOrCancel(() {
          // Only finalise collapse if we weren't interrupted by a re-expand.
          if (mounted && _collapsing) {
            setState(() {
              _expanded = false;
              _collapsing = false;
            });
            _staggerController.reset();
          }
        });
      _chevronController.reverse();
      return;
    }
    // Expanding (or re-expanding mid-collapse): abort any in-flight stagger.
    if (_collapsing) {
      _staggerController.stop();
    }
    setState(() {
      _expanded = value;
      _collapsing = false;
    });
    if (value) {
      _staggerController.reset();
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
    final notifier = ref.read(permissionsNotifierProvider.notifier);
    switch (action.kind) {
      case PermissionActionKind.allow:
        await notifier.allow(action.sessionId, action.permissionId);
      case PermissionActionKind.deny:
        await notifier.deny(action.sessionId, action.permissionId);
      case PermissionActionKind.allowAllEdits:
        await notifier.allow(
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
        await notifier.allow(
          action.sessionId,
          action.permissionId,
          allowTools: allowTools,
        );
      case PermissionActionKind.yolo:
        await notifier.allow(
          action.sessionId,
          action.permissionId,
          mode: 'yolo',
        );
      case PermissionActionKind.codexApprove:
        await notifier.allow(
          action.sessionId,
          action.permissionId,
          decision: 'approved',
        );
      case PermissionActionKind.codexApproveForSession:
        await notifier.allow(
          action.sessionId,
          action.permissionId,
          decision: 'approved_for_session',
        );
      case PermissionActionKind.codexAbort:
        await notifier.deny(
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
    _staggerController.dispose();
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

    // Extract status text. Capture the function reference locally so we
    // do not re-read the public field after the null guard — Dart's flow
    // analysis cannot promote public fields, and `!.` on an instance
    // field is a runtime null-unwrap that explodes if the value is null.
    String? status;
    final extractStatus = knownTool?.extractStatus;
    if (extractStatus != null) {
      status = extractStatus(widget.tool, widget.metadata);
    }

    String? subtitle;
    final extractSubtitle = knownTool?.extractSubtitle;
    if (extractSubtitle != null) {
      subtitle = extractSubtitle(widget.tool, widget.metadata);
    }

    // Determine minimal mode
    final bool minimal;
    if (knownTool != null) {
      minimal = knownTool.minimal;
    } else if (isMCP && _mcpTextResult(toolResult) != null) {
      minimal = false;
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
      final serverToken = toolName.replaceFirst('mcp__', '').split('__').first;
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
            // Task/Agent tools navigate directly on tap — the full
            // conversation is the primary action. Toggle is available
            // via long-press.
            if ((toolName == 'Task' || toolName == 'Agent') &&
                widget.onPress != null) {
              widget.onPress!.call();
            } else if (hasContent) {
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
            child: (_expanded || _collapsing)
                ? _StaggerFadeContent(
                    controller: _staggerController,
                    collapsing: _collapsing,
                    child: _buildContent(
                      context,
                      knownTool,
                      toolInput,
                      toolResult,
                      state,
                      errorResult,
                      permission,
                    ),
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
            onYolo: () => _handlePermission(
              PermissionActionKind.yolo,
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

          return ClipRRect(
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
    final mcpTextResult = toolName.startsWith('mcp__')
        ? _mcpTextResult(toolResult)
        : null;
    final toolCallDebug = ref.watch(
      settingsNotifierProvider.select((s) => s.toolCallDebugEnabled),
    );
    // In debug mode we want the raw INPUT/OUTPUT fallback to surface, so we
    // bypass the per-tool specific view. In normal mode we keep the specific
    // view (or the MCP text-only path, or nothing) — JSON is reachable via
    // long-press → [MessageDetailScreen], not inline.
    final specificView = toolCallDebug
        ? null
        : _getToolViewComponent(toolName);

    if (specificView != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            specificView(widget.tool, widget.metadata, widget.sessionId),
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

    // MCP tools with a text content block: show the text only. No "Show JSON"
    // toggle inline — the raw JSON is one long-press away.
    if (mcpTextResult != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
        child: _McpTextOutput(
          text: mcpTextResult,
          rawResult: toolResult,
          maxHeight: double.infinity,
        ),
      );
    }

    // Debug mode: full INPUT/OUTPUT JSON fallback for any tool (including
    // unknown ones) so devs can inspect wire payloads inline.
    if (toolCallDebug) {
      final toolId =
          widget.tool['toolUseId'] as String? ??
          widget.tool['id'] as String? ??
          toolName;
      final outputCopyText = _copyableTextFor(toolResult);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (toolInput != null)
              ToolSectionView(
                title: 'INPUT',
                trailing:
                    ToolViewCopyButton(text: _copyableTextFor(toolInput)),
                child: SmartOutputContainer(content: toolInput),
              ),
            if (state == ToolState.completed && toolResult != null)
              CollapsibleOutput(
                toolId: toolId,
                scrollable: true,
                child: ToolSectionView(
                  title: 'OUTPUT',
                  trailing: ToolViewCopyButton(text: outputCopyText),
                  child: SmartOutputContainer(
                    content: toolResult,
                    maxHeight: double.infinity,
                  ),
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

    // Non-debug, no specific view, no MCP text: nothing to show inline.
    // The user can long-press to open the full details.
    return const _OpenDetailsHint();
  }

  // Static set of known tool names — used to skip the per-call map allocation
  // when the tool name is not in the set.
  static const Set<String> _knownToolNames = {
    'Glob',
    'Grep',
    'grep',
    'LS',
    'ls',
    'Read',
    'read',
    'Edit',
    'file-edit',
    'MultiEdit',
    'Write',
    'write',
    'edit',
    'Bash',
    'bash',
    'exec_command',
    'functions.exec_command',
    'CodexBash',
    'execute',
    'CodexPatch',
    'apply_patch',
    'functions.apply_patch',
    'CodexDiff',
    'Task',
    'Agent',
    'TaskCreate',
    'TaskUpdate',
    'TaskList',
    'TaskGet',
    'TodoWrite',
    'todo_list',
    'WebFetch',
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
    final canonicalName = KnownTools.canonicalName(toolName);

    final views = <String, ToolViewBuilder>{
      'Glob': (t, m, s) => GlobView(tool: t, metadata: m),
      'Grep': (t, m, s) => GrepView(tool: t, metadata: m),
      'LS': (t, m, s) => LSView(tool: t, metadata: m),
      'Read': (t, m, s) => ReadView(tool: t, metadata: m, sessionId: s),
      'read': (t, m, s) => ReadView(tool: t, metadata: m, sessionId: s),
      'Edit': (t, m, s) => EditView(tool: t, metadata: m, sessionId: s),
      'file-edit': (t, m, s) => EditView(tool: t, metadata: m, sessionId: s),
      'MultiEdit': (t, m, s) => MultiEditView(tool: t, metadata: m),
      'Write': (t, m, s) => WriteView(tool: t, metadata: m),
      'edit': (t, m, s) => GeminiEditView(tool: t, metadata: m),
      'Bash': (t, m, s) => BashView(tool: t, metadata: m),
      'exec_command': (t, m, s) => ExecCommandView(tool: t),
      'functions.exec_command': (t, m, s) => ExecCommandView(tool: t),
      'CodexBash': (t, m, s) => CodexBashView(tool: t, metadata: m),
      'execute': (t, m, s) => GeminiExecuteView(tool: t, metadata: m),
      'CodexPatch': (t, m, s) => CodexPatchView(tool: t, metadata: m),
      'apply_patch': (t, m, s) => CodexPatchView(tool: t, metadata: m),
      'functions.apply_patch': (t, m, s) =>
          CodexPatchView(tool: t, metadata: m),
      'CodexDiff': (t, m, s) => CodexDiffView(tool: t, metadata: m),
      'Task': (t, m, s) => TaskView(
        tool: t,
        metadata: m,
        onNavigate: () => widget.onPress?.call(),
      ),
      'Agent': (t, m, s) => TaskView(
        tool: t,
        metadata: m,
        onNavigate: () => widget.onPress?.call(),
      ),
      'TaskCreate': (t, m, s) =>
          TaskToolView(tool: t, metadata: m, sessionId: s),
      'TaskUpdate': (t, m, s) =>
          TaskToolView(tool: t, metadata: m, sessionId: s),
      'TaskList': (t, m, s) =>
          TaskToolView(tool: t, metadata: m, sessionId: s),
      'TaskGet': (t, m, s) =>
          TaskToolView(tool: t, metadata: m, sessionId: s),
      'TodoWrite': (t, m, s) =>
          TodoView(tool: t, metadata: m, sessionId: s),
      'todo_list': (t, m, s) =>
          TodoView(tool: t, metadata: m, sessionId: s),
      'WebFetch': (t, m, s) => WebFetchView(tool: t, metadata: m),
      'ExitPlanMode': (t, m, s) => ExitPlanToolView(tool: t, metadata: m),
      'exit_plan_mode': (t, m, s) => ExitPlanToolView(tool: t, metadata: m),
      'AskUserQuestion': _buildAskUserQuestionView,
      'NotebookRead': (t, m, s) => ReadView(tool: t, metadata: m, sessionId: s),
      'NotebookEdit': (t, m, s) => EditView(tool: t, metadata: m, sessionId: s),
    };
    return views[canonicalName] ?? views[toolName];
  }

  Widget _buildAskUserQuestionView(
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
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

  static String? _mcpTextResult(dynamic result) {
    final direct = _mcpTextFromContentBlocks(result);
    if (direct != null) return direct;

    final map = WireParsers.asMap(result);
    if (map == null) return null;

    final content = _mcpTextFromContentBlocks(map['content']);
    if (content != null) return content;

    final nestedResult = WireParsers.asMap(map['result']);
    return _mcpTextFromContentBlocks(nestedResult?['content']);
  }

  static String? _mcpTextFromContentBlocks(dynamic value) {
    final blocks = WireParsers.asList(value);
    if (blocks == null || blocks.isEmpty) return null;

    final texts = <String>[];
    for (final block in blocks) {
      final map = WireParsers.asMap(block);
      if (map == null || map['type'] != 'text') return null;
      final text = map['text'];
      if (text is! String) return null;
      texts.add(text);
    }

    if (texts.isEmpty) return null;
    return texts.join('\n');
  }

  /// Returns a plain-text representation of [value] suitable for copying.
  static String _copyableTextFor(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map || value is List) {
      try {
        return prettyJson(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }
}

class _McpTextOutput extends StatefulWidget {
  const _McpTextOutput({
    required this.text,
    required this.rawResult,
    this.maxHeight = 300,
  });

  final String text;
  final dynamic rawResult;

  /// Maximum height of the output pane.
  ///
  /// Pass [double.infinity] to fill an external bounded parent such as
  /// [CollapsibleOutput]. A finite fallback of 300 is used when this is
  /// not bounded by a parent.
  final double maxHeight;

  @override
  State<_McpTextOutput> createState() => _McpTextOutputState();
}

class _McpTextOutputState extends State<_McpTextOutput> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveMaxHeight = widget.maxHeight.isFinite
        ? widget.maxHeight
        : 300.0;

    final textOutput = Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: ToolOutputScrollFrame(
        child: SelectableText(
          widget.text,
          style: TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Courier New', 'Courier'],
            fontSize: AppFontSize.sm,
            color: theme.colorScheme.onSurface,
            height: AppLineHeight.relaxed,
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ToolViewCopyButton(text: widget.text),
            ),
            // Only expand when the widget has a finite max height. When placed
            // inside an unbounded-height ancestor (e.g. a scrollable), Expanded
            // would receive infinite remaining space and throw.
            if (hasBoundedHeight)
              Expanded(child: textOutput)
            else
              textOutput,
          ],
        );

        if (widget.maxHeight.isFinite) {
          content = ConstrainedBox(
            constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
            child: content,
          );
        }

        return content;
      },
    );
  }
}

/// Wraps [child] — a [Column] returned by `_buildContent` — and stagger-fades
/// its children out top-to-bottom when [collapsing] is true.
///
/// Each child fades from full opacity to zero and slides slightly downward,
/// with later children starting their fade a bit after earlier ones. When
/// [collapsing] is false the widget delegates directly without any overhead.
class _StaggerFadeContent extends StatelessWidget {
  const _StaggerFadeContent({
    required this.controller,
    required this.collapsing,
    required this.child,
  });

  final AnimationController controller;
  final bool collapsing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!collapsing) return child;

    // Unwrap the outermost Padding + Column produced by _buildContent so we
    // can stagger each child independently.  If the structure doesn't match
    // (e.g. some future refactor), fall back to fading the whole block at once.
    if (child is Padding) {
      final padding = child as Padding;
      final inner = padding.child;
      if (inner is Column) {
        final column = inner;
        // Filter to concrete widgets (if-guards produce null slots).
        final visibleChildren = column.children
            .whereType<Widget>()
            .toList(growable: false);
        final count = visibleChildren.length;
        if (count > 0) {
          return Padding(
            padding: padding.padding,
            child: Column(
              crossAxisAlignment: column.crossAxisAlignment,
              mainAxisSize: column.mainAxisSize,
              children: [
                for (var i = 0; i < count; i++)
                  _staggeredChild(visibleChildren[i], i, count),
              ],
            ),
          );
        }
      }
    }

    // Fallback: fade the entire content block as one unit.
    return _staggeredChild(child, 0, 1);
  }

  Widget _staggeredChild(Widget child, int index, int total) {
    // Each child starts fading after a small staggered delay, then fades out
    // over [_kStaggerFadeWindow] of the total duration.
    final staggerStep =
        total > 1 ? (1.0 - _kStaggerFadeWindow) / total : 0.0;
    final start = index * staggerStep;
    final end = (start + _kStaggerFadeWindow).clamp(0.0, 1.0);

    final curvedAnim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: AppCurve.exit),
    );
    final opacity = Tween<double>(begin: 1.0, end: 0.0).animate(curvedAnim);
    final slideY = Tween<double>(
      begin: 0.0,
      end: _kStaggerSlideOffset,
    ).animate(curvedAnim);

    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, innerChild) => Transform.translate(
        offset: Offset(0, slideY.value),
        child: Opacity(
          opacity: opacity.value,
          child: innerChild,
        ),
      ),
    );
  }
}

/// Inline hint shown when a tool has no specific body and JSON is hidden
/// (non-debug mode). Tells the user how to reach the full input/output
/// without burying them in JSON inline.
class _OpenDetailsHint extends StatelessWidget {
  const _OpenDetailsHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        'Long-press to view input & output',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
