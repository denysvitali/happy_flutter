import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/tablet/embedded_pane.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/code_viewer_theme.dart';
import '../../core/utils/ansi_parser.dart';
import '../../core/utils/ansi_span_cache.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/utils/command_utils.dart';
import '../../core/wire/wire_parsers.dart';
import 'tools/json_viewer.dart';
import 'tools/known_tools.dart';
import 'tools/tool_status_indicator.dart';
import 'tools/tool_view.dart' show parseToolState;
import 'tools/views/codex_mcp_view.dart';
import 'tools/views/mcp_exec_view.dart';
import 'tools/views/web_search_view.dart';

const int _largePayloadThreshold = 16 * 1024;
const int _payloadPageSize = 12 * 1024;

String _encodeJsonForClipboard(dynamic value) => jsonEncode(value);

String _stripAnsiForClipboard(String value) => AnsiParser.strip(value);

/// Screen showing full details of a tool-call message.
///
/// Displays tool name, status, full input JSON, output/result,
/// permission info, and error details. For Task (sub-agent) tools,
/// shows a list of child tool calls that can be tapped for details.
class MessageDetailScreen extends ConsumerWidget {
  /// Creates a [MessageDetailScreen].
  const MessageDetailScreen({
    required this.sessionId,
    required this.messageId,
    this.messageData,
    this.embedded = false,
    this.onClose,
    super.key,
  });

  /// The ID of the session containing the message.
  final String sessionId;

  /// The ID of the message to display.
  final String messageId;

  /// Optional pre-loaded message data passed via route extra.
  final Map<String, dynamic>? messageData;

  /// When true, render as a pane inside a tablet master-detail layout.
  /// Skips the outer [Scaffold]/[AppBar] and uses a thin in-pane header.
  final bool embedded;

  /// Called when the in-pane close button is tapped (embedded only).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = messageData;

    if (data == null) {
      return EmbeddedPaneShell(
        title: context.l10n.messageDetailTitle,
        embedded: embedded,
        onClose: onClose,
        body: Center(child: Text(context.l10n.messageNotFound)),
      );
    }

    final kind = data['kind'] as String? ?? 'unknown';
    if (kind != 'tool-call') {
      return EmbeddedPaneShell(
        title: context.l10n.messageDetailTitle,
        embedded: embedded,
        onClose: onClose,
        body: _TextDetailView(data: data),
      );
    }

    return EmbeddedPaneShell(
      title: context.l10n.toolDetailsTitle,
      embedded: embedded,
      onClose: onClose,
      body: _ToolDetailView(data: data),
    );
  }
}

// ── Text detail view ───────────────────────────────────────────────────────

class _TextDetailView extends StatelessWidget {
  const _TextDetailView({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final content = data['content'] ?? data['text'] ?? '';
    final text = content is String ? content : content.toString();
    return ListView(
      padding: AppScreenPadding.standard,
      children: [
        _DetailCard(
          title: context.l10n.messageDetailContent,
          icon: Icons.message_outlined,
          child: _PagedSelectableText(
            content: text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────

// Re-export the shared parser from tool_view.dart — used by multiple widgets
// in this file. The function handles null/unknown values as ToolState.pending.
// ignore: unused_element
ToolState _parseToolState(String? state) => parseToolState(state);

// ── Tool detail view ───────────────────────────────────────────────────────

class _ToolDetailView extends StatelessWidget {
  const _ToolDetailView({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = data['name'] as String? ?? 'Unknown';
    final toolState = data['state'] as String? ?? 'pending';
    final input = WireParsers.asMap(data['input']);
    final result = data['result'];
    final permission = WireParsers.asMap(data['permission']);
    final messages = WireParsers.asList(data['messages']);

    final knownTool = KnownTools.get(toolName);
    final isTask =
        toolName == 'Task' || toolName == 'Agent' || toolName == 'Workflow';

    var toolTitle = toolName;
    if (knownTool != null) {
      if (knownTool.title is String) {
        toolTitle = knownTool.title;
      }
    }

    final state = _parseToolState(toolState);
    final inputText = _commandInputText(toolName, input);
    final resultText = _commandResultText(toolName, result);
    final hasInput = _hasMeaningfulPayload(input);
    final hasResult = _hasMeaningfulPayload(result);
    final isWebSearch =
        toolName == 'WebSearch' ||
        toolName == 'web_search' ||
        toolName == 'web_search_preview';
    final isRunning = state == ToolState.running;
    final hasLargePayload =
        _isLargePayload(input, null) ||
        _isLargePayload(
          result is Map || result is List ? result : null,
          result is String ? result : null,
        );
    final execResult =
        (toolName.startsWith('mcp__') || isSshMcpExecuteTool(toolName)) &&
            !isRunning &&
            !hasLargePayload
        ? McpExecResult.tryParse(result)
        : null;

    return ListView(
      padding: AppScreenPadding.standard,
      children: [
        _MessageHeader(
          toolTitle: toolTitle,
          toolName: toolName,
          toolState: toolState,
          state: state,
          isTask: isTask,
          input: input,
        ),
        const SizedBox(height: AppSpacing.md),

        // Permission info
        if (permission != null) ...[
          _DetailCard(
            title: context.l10n.messageDetailPermission,
            icon: Icons.shield_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelValue(
                  label: context.l10n.messageDetailStatus,
                  value: permission['status'] as String? ?? 'unknown',
                ),
                if (permission['reason'] != null)
                  _LabelValue(
                    label: context.l10n.messageDetailReason,
                    value: permission['reason'].toString(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Web search tools get a first-class body (query, expanded
        // queries, sources, or a "results not in transcript" note) so
        // the detail screen is informative even when the daemon's
        // result envelope is empty (Codex web_search items carry no
        // result pages on the wire).
        if (isWebSearch && !hasLargePayload) ...[
          WebSearchView(tool: data),
          if (input != null || result != null) ...[
            const SizedBox(height: AppSpacing.md),
            _RawPayloadDisclosure(input: input, result: result, state: state),
          ],
          const SizedBox(height: AppSpacing.md),
        ] else if (execResult != null) ...[
          // Exec-shaped MCP tools (ssh and friends): terminal card instead of
          // a JSON tree the reader has to decode field by field. Raw payloads
          // stay one disclosure away.
          McpExecView(tool: data, exec: execResult, boxed: false),
          const SizedBox(height: AppSpacing.md),
          _RawPayloadDisclosure(input: input, result: result, state: state),
          const SizedBox(height: AppSpacing.md),
        ] else if (KnownTools.codexMcpToolNames.contains(toolName) &&
            !hasLargePayload) ...[
          CodexMcpView(tool: data),
          if (input != null || result != null) ...[
            const SizedBox(height: AppSpacing.md),
            _RawPayloadDisclosure(input: input, result: result, state: state),
          ],
          const SizedBox(height: AppSpacing.md),
        ] else ...[
          // Input
          if (hasInput) ...[
            _ToolResultSection(
              title: context.l10n.messageDetailInput,
              icon: Icons.input,
              json: inputText == null ? input : null,
              text: inputText,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Output/Result
          if (hasResult && state != ToolState.running) ...[
            _ToolResultSection(
              title: state == ToolState.error
                  ? context.l10n.commonError
                  : context.l10n.messageDetailOutput,
              icon: state == ToolState.error
                  ? Icons.error_outline
                  : Icons.output,
              json: resultText == null && (result is Map || result is List)
                  ? result
                  : null,
              text:
                  resultText ??
                  (result is! Map && result is! List
                      ? result.toString()
                      : null),
              isError: state == ToolState.error,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],

        // Child tools for Task/sub-agent
        if (isTask && messages != null && messages.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              context.l10n.messageDetailSubagentTools,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _TaskChildToolList(messages: messages),
        ],
      ],
    );
  }
}

class _TaskChildToolList extends StatefulWidget {
  const _TaskChildToolList({required this.messages});

  final List<dynamic> messages;

  @override
  State<_TaskChildToolList> createState() => _TaskChildToolListState();
}

class _TaskChildToolListState extends State<_TaskChildToolList> {
  static const int _pageSize = 20;
  int _visible = _pageSize;

  @override
  Widget build(BuildContext context) {
    final shown = <Map<String, dynamic>>[];
    var hasMore = false;
    for (final item in widget.messages) {
      if (item is! Map<String, dynamic> || item['kind'] != 'tool-call') {
        continue;
      }
      if (shown.length == _visible) {
        hasMore = true;
        break;
      }
      shown.add(item);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final message in shown)
          _ChildToolItem(
            tool: WireParsers.asMap(message['tool']) ?? message,
            message: message,
          ),
        if (hasMore)
          TextButton.icon(
            onPressed: () => setState(() => _visible += _pageSize),
            icon: const Icon(Icons.expand_more),
            label: const Text('Show more'),
          ),
      ],
    );
  }
}

bool _hasMeaningfulPayload(dynamic value) {
  if (value == null) return false;
  if (value is Map) return value.isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is String) return value.trim().isNotEmpty;
  return true;
}

String? _commandResultText(String toolName, dynamic result) {
  if (!_isCommandTool(toolName)) return null;
  if (result is String) return result;

  final map = WireParsers.asMap(result);
  if (map == null) return null;

  final stdout = map['stdout'];
  if (stdout is String && stdout.isNotEmpty) return stdout;

  final output = map['output'];
  if (output is String && output.isNotEmpty) return output;

  final stderr = map['stderr'];
  if (stderr is String && stderr.isNotEmpty) return stderr;

  return null;
}

String? _commandInputText(String toolName, Map<String, dynamic>? input) {
  if (!_isCommandTool(toolName) || input == null) return null;

  final parsedCmd = WireParsers.asList(input['parsed_cmd']);
  if (parsedCmd != null && parsedCmd.isNotEmpty) {
    final firstCmd = WireParsers.asMap(parsedCmd.first);
    final cmd = firstCmd?['cmd'];
    if (cmd is String && cmd.isNotEmpty) return cleanShellCommand(cmd);
  }

  final cmd = input['cmd'];
  if (cmd is String && cmd.isNotEmpty) return cleanShellCommand(cmd);

  final command = input['command'];
  if (command is String && command.isNotEmpty) {
    return cleanShellCommand(command);
  }

  final commandList = WireParsers.asList(command);
  if (commandList != null && commandList.isNotEmpty) {
    return cleanShellCommand(commandList.join(' '));
  }

  return null;
}

bool _isCommandTool(String toolName) {
  switch (toolName) {
    case 'Bash':
    case 'CodexBash':
    case 'GeminiBash':
    case 'execute':
    case 'exec_command':
    case 'functions.exec_command':
      return true;
    default:
      return false;
  }
}

// ── Message header ─────────────────────────────────────────────────────────

/// Header card showing tool identity, state badge, and key metadata.
class _MessageHeader extends StatelessWidget {
  const _MessageHeader({
    required this.toolTitle,
    required this.toolName,
    required this.toolState,
    required this.state,
    required this.isTask,
    required this.input,
  });

  final String toolTitle;
  final String toolName;
  final String toolState;
  final ToolState state;
  final bool isTask;
  final Map<String, dynamic>? input;

  @override
  Widget build(BuildContext context) {
    final isWebSearch =
        toolName == 'WebSearch' ||
        toolName == 'web_search' ||
        toolName == 'web_search_preview';
    return _DetailCard(
      title: toolTitle,
      icon: isWebSearch ? Icons.public_rounded : Icons.build_outlined,
      trailing: state == ToolState.completed
          ? null
          : ToolStatusIndicator(state: state, size: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelValue(label: context.l10n.messageDetailTool, value: toolName),
          _LabelValue(label: context.l10n.messageDetailState, value: toolState),
          if (isTask && input != null) ...[
            if (input?['subagent_type'] != null)
              _LabelValue(
                label: context.l10n.messageDetailAgentType,
                value: input?['subagent_type'].toString() ?? '',
              ),
            if (input?['description'] != null)
              _LabelValue(
                label: context.l10n.messageDetailDescription,
                value: input?['description'].toString() ?? '',
              ),
          ],
        ],
      ),
    );
  }
}

// ── Tool result section ────────────────────────────────────────────────────

/// Displays a JSON or text result block.
///
/// When [json] is provided (a pre-parsed Map or List) or [text] contains
/// valid JSON, renders an interactive [JsonTreeViewer] with syntax
/// highlighting and expand/collapse.  Plain text falls back to a dark
/// monospace [_CodeBlock].
class _ToolResultSection extends StatelessWidget {
  const _ToolResultSection({
    required this.title,
    required this.icon,
    this.json,
    this.text,
    this.isError = false,
  });

  final String title;
  final IconData icon;
  final dynamic json; // Map<String, dynamic> or List<dynamic>
  final String? text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (_isLargePayload(json, text)) {
      return _DeferredToolResultSection(
        title: title,
        icon: icon,
        json: json,
        text: text,
        isError: isError,
      );
    }
    return _ImmediateToolResultSection(
      title: title,
      icon: icon,
      json: json,
      text: text,
      isError: isError,
    );
  }
}

bool _isLargePayload(dynamic json, String? text) {
  if (text != null && text.length > _largePayloadThreshold) return true;
  if (json is List && json.length > 50) return true;
  if (json is Map) {
    if (json.length > 50) return true;
    var shallowTextLength = 0;
    var visited = 0;
    for (final value in json.values) {
      if (value is String) {
        shallowTextLength += value.length;
        if (shallowTextLength > _largePayloadThreshold) return true;
      }
      if (++visited >= 50) break;
    }
  }
  return false;
}

class _DeferredToolResultSection extends StatefulWidget {
  const _DeferredToolResultSection({
    required this.title,
    required this.icon,
    this.json,
    this.text,
    this.isError = false,
  });

  final String title;
  final IconData icon;
  final dynamic json;
  final String? text;
  final bool isError;

  @override
  State<_DeferredToolResultSection> createState() =>
      _DeferredToolResultSectionState();
}

class _DeferredToolResultSectionState
    extends State<_DeferredToolResultSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (_expanded) {
      return _ImmediateToolResultSection(
        title: widget.title,
        icon: widget.icon,
        json: widget.json,
        text: widget.text,
        isError: widget.isError,
      );
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: cs.outlineVariant, width: AppBorder.hairline),
      ),
      child: ListTile(
        leading: Icon(
          widget.icon,
          color: widget.isError ? cs.error : cs.primary,
        ),
        title: Text(widget.title),
        subtitle: const Text('Large output kept collapsed for smooth opening'),
        trailing: const Icon(Icons.expand_more),
        onTap: () => setState(() => _expanded = true),
      ),
    );
  }
}

class _ImmediateToolResultSection extends StatefulWidget {
  const _ImmediateToolResultSection({
    required this.title,
    required this.icon,
    this.json,
    this.text,
    this.isError = false,
  });

  final String title;
  final IconData icon;
  final dynamic json;
  final String? text;
  final bool isError;

  @override
  State<_ImmediateToolResultSection> createState() =>
      _ImmediateToolResultSectionState();
}

class _ImmediateToolResultSectionState
    extends State<_ImmediateToolResultSection> {
  late final dynamic _jsonValue;

  @override
  void initState() {
    super.initState();
    _jsonValue = _resolveJson();
  }

  /// Returns a parsed JSON value (Map or List) if the content is JSON,
  /// or null if it should be rendered as plain text.
  dynamic _resolveJson() {
    if (widget.json is Map || widget.json is List) return widget.json;
    final t = widget.text;
    if (t == null) return null;
    final trimmed = t.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return jsonDecode(t);
      } catch (_) {
        // Text starts with { or [ but isn't JSON — render as plain text.
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: cs.outlineVariant, width: AppBorder.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.isError ? cs.error : cs.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.isError ? cs.error : null,
                    ),
                  ),
                ),
                _CopyButton(json: widget.json, content: widget.text ?? ''),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Interactive JSON tree or plain code block
            if (_jsonValue != null)
              _JsonTreeBlock(value: _jsonValue)
            else
              _CodeBlock(content: widget.text ?? ''),
          ],
        ),
      ),
    );
  }
}

// ── Raw payload disclosure ─────────────────────────────────────────────────

/// Collapsed "Raw JSON" card holding the full wire input/output for tools
/// whose detail body is a dedicated pretty view (e.g. Codex MCP). Keeps
/// full fidelity one tap away without burying the readable content.
class _RawPayloadDisclosure extends StatelessWidget {
  const _RawPayloadDisclosure({
    required this.input,
    required this.result,
    required this.state,
  });

  final Map<String, dynamic>? input;
  final dynamic result;
  final ToolState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: cs.outlineVariant, width: AppBorder.hairline),
      ),
      child: ExpansionTile(
        leading: Icon(Icons.data_object, size: 18, color: cs.primary),
        // TODO(i18n): raw-payload label not yet localized
        title: Text(
          'Raw JSON',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          if (input != null) ...[
            _ToolResultSection(
              title: context.l10n.messageDetailInput,
              icon: Icons.input,
              json: input,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (result != null && state != ToolState.running)
            _ToolResultSection(
              title: state == ToolState.error
                  ? context.l10n.commonError
                  : context.l10n.messageDetailOutput,
              icon: state == ToolState.error
                  ? Icons.error_outline
                  : Icons.output,
              json: result is Map || result is List ? result : null,
              text: result is! Map && result is! List
                  ? result.toString()
                  : null,
              isError: state == ToolState.error,
            ),
        ],
      ),
    );
  }
}

// ── Child tool item ────────────────────────────────────────────────────────

class _ChildToolItem extends StatelessWidget {
  const _ChildToolItem({required this.tool, required this.message});
  final Map<String, dynamic> tool;
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = tool['name'] as String? ?? 'Unknown';
    final state = tool['state'] as String? ?? 'pending';
    final icon = KnownTools.iconFor(
      toolName,
      18,
      theme.colorScheme.onSurfaceVariant,
    );

    final knownTool = KnownTools.get(toolName);
    var title = toolName;
    if (knownTool?.extractDescription != null) {
      title = knownTool?.extractDescription?.call(tool, null) ?? toolName;
    } else if (knownTool?.title is String) {
      title = knownTool?.title as String? ?? toolName;
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showToolDetail(context, tool),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          child: Row(
            children: [
              SizedBox(width: 18, height: 18, child: icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.sm,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ToolStatusIndicator(state: _parseToolState(state), size: 14),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToolDetail(BuildContext context, Map<String, dynamic> tool) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _ToolDetailBottomSheet(
          tool: tool,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// ── Tool detail bottom sheet ───────────────────────────────────────────────

class _ToolDetailBottomSheet extends StatelessWidget {
  const _ToolDetailBottomSheet({
    required this.tool,
    required this.scrollController,
  });
  final Map<String, dynamic> tool;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = tool['name'] as String? ?? 'Unknown';
    final state = tool['state'] as String? ?? 'pending';
    final input = WireParsers.asMap(tool['input']);
    final result = tool['result'];
    final inputText = _commandInputText(toolName, input);
    final resultText = _commandResultText(toolName, result);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              KnownTools.iconFor(
                toolName,
                20,
                theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  toolName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ToolStatusIndicator(state: _parseToolState(state), size: 18),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (input != null)
                _ToolResultSection(
                  title: context.l10n.messageDetailInput,
                  icon: Icons.input,
                  json: inputText == null ? input : null,
                  text: inputText,
                ),
              if (input != null) const SizedBox(height: AppSpacing.md),
              if (result != null) ...[
                _ToolResultSection(
                  title: state == 'error'
                      ? context.l10n.commonError
                      : context.l10n.messageDetailOutput,
                  icon: state == 'error' ? Icons.error_outline : Icons.output,
                  json: resultText == null && result is Map<String, dynamic>
                      ? result
                      : null,
                  text:
                      resultText ??
                      (result is! Map<String, dynamic>
                          ? result.toString()
                          : null),
                  isError: state == 'error',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared detail widgets ──────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: cs.outlineVariant, width: AppBorder.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: _PagedSelectableText(
              content: value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Code block + copy button ───────────────────────────────────────────────

/// Renders a [JsonTreeViewer] in a container styled to match [_CodeBlock].
class _JsonTreeBlock extends StatelessWidget {
  const _JsonTreeBlock({required this.value});

  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: CodeViewerTheme.dark.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ToolOutputScrollFrame(
        maxHeight: 320,
        child: Theme(
          // Force dark brightness so JsonTreeViewer always uses the dark
          // palette inside the always-dark code container.
          data: Theme.of(context).copyWith(
            brightness: Brightness.dark,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              brightness: Brightness.dark,
              onSurface: CodeViewerTheme.dark.foreground,
            ),
          ),
          child: JsonTreeViewer(value: value),
        ),
      ),
    );
  }
}

/// Always-dark monospace code container used inside [_ToolResultSection].
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: AppFontSize.sm,
      color: CodeViewerTheme.dark.foreground,
      height: AppLineHeight.relaxed,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: CodeViewerTheme.dark.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ToolOutputScrollFrame(
        maxHeight: 320,
        child: _PagedAnsiText(content: content, style: defaultStyle),
      ),
    );
  }
}

/// Renders a bounded slice of a large string so text layout remains capped.
/// The full value is still available through the copy button.
class _PagedSelectableText extends StatefulWidget {
  const _PagedSelectableText({required this.content, required this.style});

  final String content;
  final TextStyle? style;

  @override
  State<_PagedSelectableText> createState() => _PagedSelectableTextState();
}

class _PagedSelectableTextState extends State<_PagedSelectableText> {
  int _page = 0;

  int get _pageCount =>
      (widget.content.length / _payloadPageSize).ceil().clamp(1, 1 << 20);

  String get _slice {
    final start = _page * _payloadPageSize;
    final end = (start + _payloadPageSize).clamp(0, widget.content.length);
    return widget.content.substring(start, end);
  }

  @override
  Widget build(BuildContext context) {
    if (_pageCount == 1) {
      return SelectableText(widget.content, style: widget.style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(_slice, style: widget.style),
        _PayloadPager(
          page: _page,
          pageCount: _pageCount,
          onChanged: (page) => setState(() => _page = page),
        ),
      ],
    );
  }
}

class _PagedAnsiText extends StatefulWidget {
  const _PagedAnsiText({required this.content, required this.style});

  final String content;
  final TextStyle style;

  @override
  State<_PagedAnsiText> createState() => _PagedAnsiTextState();
}

class _PagedAnsiTextState extends State<_PagedAnsiText> {
  int _page = 0;

  int get _pageCount =>
      (widget.content.length / _payloadPageSize).ceil().clamp(1, 1 << 20);

  @override
  Widget build(BuildContext context) {
    final start = _page * _payloadPageSize;
    final end = (start + _payloadPageSize).clamp(0, widget.content.length);
    final pageText = widget.content.substring(start, end);
    // Memoized: this build method has no change guard, so theme or
    // inherited rebuilds re-ran a full ANSI parse of the page on every
    // tick; identical (page, style) pairs now reuse cached spans.
    final spans = AnsiSpanCache.instance.parse(
      pageText,
      defaultStyle: widget.style,
    );
    final text = SelectableText.rich(
      TextSpan(children: spans),
      style: widget.style,
    );
    if (_pageCount == 1) return text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text,
        _PayloadPager(
          page: _page,
          pageCount: _pageCount,
          onChanged: (page) => setState(() => _page = page),
        ),
      ],
    );
  }
}

class _PayloadPager extends StatelessWidget {
  const _PayloadPager({
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous output page',
          onPressed: page == 0 ? null : () => onChanged(page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text('${page + 1} / $pageCount'),
        IconButton(
          tooltip: 'Next output page',
          onPressed: page + 1 >= pageCount ? null : () => onChanged(page + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// Small icon button that copies [content] to the clipboard.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.content, this.json});

  final String content;
  final dynamic json;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy, size: 16),
      constraints: const BoxConstraints.tightFor(
        width: AppTouchTarget.min,
        height: AppTouchTarget.min,
      ),
      tooltip: context.l10n.commonCopy,
      onPressed: () async {
        final String copyText;
        if (json != null) {
          copyText = await compute(_encodeJsonForClipboard, json);
        } else if (content.length > _largePayloadThreshold) {
          copyText = await compute(_stripAnsiForClipboard, content);
        } else {
          copyText = AnsiParser.strip(content);
        }
        await setClipboardTextSafely(copyText);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.commonCopiedToClipboard),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
