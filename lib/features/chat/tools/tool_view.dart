import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/utils.dart' show prettyJson;
import '../../../core/providers/app_providers.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/utils/grok_acp_normalize.dart';
import '../../../core/utils/tool_error_parser.dart';
import '../../../core/wire/wire_parsers.dart';
import '../message_render_signature.dart';
import 'json_viewer.dart';
import 'known_tools.dart';
import 'permission_footer.dart';
import 'tool_error.dart';
import 'tool_section_view.dart';
import 'tool_status_indicator.dart' show ToolState;
import 'tool_view_helpers.dart';
import 'tool_view_registry.dart';
import 'tool_view_widgets.dart';
import 'views/ask_user_question_view.dart';
import 'views/mcp_result_view.dart';
import 'views/task_tool_view.dart';

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

/// Tools whose subtitle is a shell command or file path, rendered in
/// monospace in the collapsed header.
const Set<String> _monoSubtitleToolNames = {
  'bash',
  'exec_command',
  'functions.exec_command',
  'codexbash',
  'geminibash',
  'shell',
  'read',
  'edit',
  'file-edit',
  'write',
  'multiedit',
  'ls',
  'glob',
  'grep',
  'notebookread',
  'notebookedit',
  'codexpatch',
  'apply_patch',
  'functions.apply_patch',
  'codexdiff',
};

class _ToolViewState extends ConsumerState<ToolView>
    with TickerProviderStateMixin {
  // Collapsed by default — the header summary is the one-tap preview, and the
  // full body is reached via a tap on the header. The only auto-expand case
  // is a pending permission request: the Allow/Deny footer must stay visible
  // so the user can respond, and the user dismisses it themselves afterward.
  // Full input/JSON is always reachable via long-press → [MessageDetailScreen].
  bool _expanded = false;
  bool _showCheckFlash = false;
  bool _collapsing = false;
  ToolState? _prevState;
  late int _toolSignature;

  late final AnimationController _chevronController;
  late final Animation<double> _chevronAnim;

  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();

    _toolSignature = messageRenderSignature(widget.tool);
    _maybePushTaskTool();

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

    // Only a pending permission request auto-expands — the user needs the
    // Allow/Deny footer in view. Anything else (running, completed, error,
    // pending) starts collapsed and waits for an explicit tap. A running
    // tool still shows its spinner + tinted row even while collapsed so the
    // user can see it's in flight.
    if (hasPermissionRequest) {
      _expanded = true;
      _chevronController.forward();
    }
  }

  @override
  void didUpdateWidget(ToolView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Task tool results need to reach the global notifier even when this
    // tool is auto-collapsed — the body that would normally push the state
    // is unmounted in that case. Push from here so the session banner and
    // Zen list stay in sync with the latest tool data.
    final nextToolSignature = messageRenderSignature(widget.tool);
    if (nextToolSignature != _toolSignature) {
      _toolSignature = nextToolSignature;
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
      setState(() => _showCheckFlash = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showCheckFlash = false);
      });
    }

    _prevState = newState;
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
      TaskToolView.pushToolToGlobalState(context, tool, widget.sessionId);
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
    _chevronController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  /// Format MCP tool name for display.
  ///
  /// Example: `mcp__linear__create_issue` -> `Linear: Create Issue`
  ///
  /// A redundant server prefix in the tool part is dropped so
  /// `mcp__codex__codex` renders as `Codex` (not `Codex: Codex`) and
  /// `mcp__codex__codex-reply` as `Codex: Reply`.
  String _formatMCPTitle(String toolName) {
    final withoutPrefix = toolName.replaceFirst('mcp__', '');
    final parts = withoutPrefix.split('__');
    if (parts.length >= 2) {
      final serverToken = parts[0];
      final serverName = _snakeToPascal(serverToken);
      var toolPart = parts.skip(1).join('_');
      if (toolPart == serverToken) return serverName;
      for (final prefix in ['${serverToken}_', '$serverToken-']) {
        if (toolPart.startsWith(prefix)) {
          toolPart = toolPart.substring(prefix.length);
          break;
        }
      }
      return '$serverName: ${_snakeToPascal(toolPart)}';
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
    // Defense-in-depth: unwrap Grok use_tool for historical messages that
    // were stored before happy-cli-go / ACP normalize rewrote the name.
    final displayDispatch = normalizeGrokToolCall(
      widget.tool['name'] as String? ?? 'Unknown',
      WireParsers.asMap(widget.tool['input']),
    );
    final toolName = displayDispatch.name;
    final toolState = widget.tool['state'] as String? ?? 'pending';
    final toolInput = displayDispatch.input;
    final toolResult = widget.tool['result'];
    final permission = WireParsers.asMap(widget.tool['permission']);
    final createdAt = widget.tool['createdAt'] as int?;

    final knownTool = KnownTools.get(toolName);
    final isMCP = toolName.startsWith('mcp__') || toolName.contains('__');

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
    } else {
      // Unknown third-party tool: never show the raw wire name.
      toolTitle = humanizeToolName(toolName);
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

    // MCP results carry no per-tool view, so the collapsed row would say
    // nothing at all about what came back. Summarize the payload shape
    // ("4 items", "29 traces") inline next to the title.
    final mcpText = isMCP ? mcpToolTextResult(toolResult) : null;
    if (status == null && subtitle == null && mcpText != null) {
      status = mcpResultSummary(mcpText);
    }

    // Determine minimal mode
    final bool minimal;
    if (knownTool != null) {
      minimal = knownTool.minimal;
    } else if (isMCP && mcpText != null) {
      minimal = false;
    } else {
      // Unknown/MCP tools: always minimal — details via tap/long-press only.
      minimal = true;
    }

    final state = parseToolState(toolState);

    final typeAccentColor = toolAccentColor(toolName, theme.colorScheme);

    // A pending permission request tints the header warning-orange.
    final hasPermissionRequest = isPermissionPending(permission);

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
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        );
      }
    } else if (isToolUseError && state != ToolState.error) {
      statusIcon = Icon(
        Icons.remove_circle_outline,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      );
    } else {
      switch (state) {
        case ToolState.running:
        case ToolState.error:
        case ToolState.completed:
        case ToolState.pending:
          break;
      }
    }

    // Build tool icon: one consistent outlined Material set, tinted with the
    // tool-family accent. MCP tools share the extension glyph — arbitrary
    // per-server emojis mixed badly with the rest of the iconography.
    final iconColor = hasPermissionRequest ? permissionColor : typeAccentColor;
    final toolIcon = isMCP
        ? KnownTools.mcpIcon(18, iconColor)
        : KnownTools.iconFor(toolName, 18, iconColor);

    final hasContent = !minimal;

    // State emphasis without card chrome: the collapsed row sits directly on
    // the chat background so a run of tool calls reads as a timeline, while
    // states that deserve attention get a tinted surface behind the header
    // (running = primary, error = error, pending permission = warning).
    final headerTint = hasPermissionRequest
        ? permissionColor.withValues(alpha: 0.09)
        : switch (state) {
            ToolState.running => theme.colorScheme.primary.withValues(
              alpha: 0.07,
            ),
            ToolState.error => theme.colorScheme.error.withValues(alpha: 0.07),
            _ => null,
          };

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: headerTint ?? Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                // Task/Agent/Workflow tools navigate directly on tap — the
                // full conversation is the primary action. Toggle is
                // available via long-press.
                if ((toolName == 'Task' ||
                        toolName == 'Agent' ||
                        toolName == 'Workflow') &&
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
                subtitleMonospace: _monoSubtitleToolNames.contains(
                  KnownTools.canonicalName(toolName).toLowerCase(),
                ),
                state: state,
                createdAt: createdAt,
                statusIcon: statusIcon,
                hasContent: hasContent,
                showCheckFlash: _showCheckFlash,
                chevronAnim: _chevronAnim,
                hasPermissionRequest: hasPermissionRequest,
              ),
            ),
          ),
          // Expanded body: nested panel below the chromeless header.
          if (hasContent)
            AnimatedSize(
              duration: AppDuration.normal,
              curve: AppCurve.standard,
              child: (_expanded || _collapsing)
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.38,
                            ),
                            width: AppBorder.hairline,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: _StaggerFadeContent(
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
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          if (permission != null &&
              widget.sessionId != null &&
              toolName != 'AskUserQuestion')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: PermissionFooter(
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
    ParsedToolError? errorResult,
    Map<String, dynamic>? permission,
  ) {
    final toolName = widget.tool['name'] as String? ?? '';
    final mcpTextResult = toolName.startsWith('mcp__')
        ? mcpToolTextResult(toolResult)
        : null;
    final toolCallDebug = ref.watch(
      settingsNotifierProvider.select((s) => s.toolCallDebugEnabled),
    );
    // In debug mode we want the raw INPUT/OUTPUT fallback to surface, so we
    // bypass the per-tool specific view. In normal mode we keep the specific
    // view (or the MCP text-only path, or nothing) — JSON is reachable via
    // long-press → [MessageDetailScreen], not inline.
    final specificView = toolCallDebug ? null : _getToolViewComponent(toolName);

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
              ToolError(message: ToolError.messageFromResult(toolResult)),
          ],
        ),
      );
    }

    // MCP tools with a text content block: show the text only. No "Show JSON"
    // toggle inline — the raw JSON is one long-press away.
    if (mcpTextResult != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
        child: McpResultView(text: mcpTextResult),
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
                trailing: ToolViewCopyButton(text: _copyableTextFor(toolInput)),
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
              ToolError(message: ToolError.messageFromResult(toolResult)),
          ],
        ),
      );
    }

    // Unknown tools normally keep their raw payload in the details view, but
    // an error needs an inline explanation even when debug mode is off.
    if (state == ToolState.error &&
        toolResult != null &&
        isPermissionNotDeniedOrCanceled(permission) &&
        !(errorResult?.isToolUseError ?? false)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
        child: ToolError(message: ToolError.messageFromResult(toolResult)),
      );
    }

    // Non-debug, no specific view, no MCP text: nothing to show inline. The
    // user can long-press to open the full details.
    return const _OpenDetailsHint();
  }

  /// Returns a view builder for the named tool, or null for default fallback.
  ///
  /// Delegates to [ToolViewRegistry] so aliases + builders live in one place.
  ToolViewBuilder? _getToolViewComponent(String toolName) {
    if (!ToolViewRegistry.has(toolName)) return null;
    return ToolViewRegistry.resolve(
      toolName,
      onNavigate: () {
        widget.onPress?.call();
      },
      askUserBuilder: (t, m, s) {
        final toolUseId = t['toolUseId'] as String? ?? t['id'] as String?;
        return AskUserQuestionView(
          key: toolUseId != null ? ValueKey('ask-$toolUseId') : null,
          tool: t,
          metadata: m,
          sessionId: widget.sessionId ?? s,
        );
      },
    );
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
        final visibleChildren = column.children.whereType<Widget>().toList(
          growable: false,
        );
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
    final staggerStep = total > 1 ? (1.0 - _kStaggerFadeWindow) / total : 0.0;
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
        child: Opacity(opacity: opacity.value, child: innerChild),
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
