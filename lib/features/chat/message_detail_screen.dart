import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/wire_parsers.dart';
import 'tools/json_viewer.dart';
import 'tools/known_tools.dart';
import 'tools/tool_status_indicator.dart';
import 'tools/tool_view.dart' show parseToolState;

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
    super.key,
  });

  /// The ID of the session containing the message.
  final String sessionId;

  /// The ID of the message to display.
  final String messageId;

  /// Optional pre-loaded message data passed via route extra.
  final Map<String, dynamic>? messageData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = messageData;

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.messageDetailTitle)),
        body: Center(child: Text(context.l10n.messageNotFound)),
      );
    }

    final kind = data['kind'] as String? ?? 'unknown';
    if (kind != 'tool-call') {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.messageDetailTitle)),
        body: _TextDetailView(data: data),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.toolDetailsTitle)),
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
          child: SelectableText(
            text,
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
    final isTask = toolName == 'Task';

    var toolTitle = toolName;
    if (knownTool != null) {
      if (knownTool.title is String) {
        toolTitle = knownTool.title;
      }
    }

    final state = _parseToolState(toolState);

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

        // Input
        if (input != null) ...[
          _ToolResultSection(
            title: context.l10n.messageDetailInput,
            icon: Icons.input,
            json: input,
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Output/Result
        if (result != null && state != ToolState.running) ...[
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
          const SizedBox(height: AppSpacing.md),
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
          ...messages
              .whereType<Map<String, dynamic>>()
              .where((m) => m['kind'] == 'tool-call')
              .map(
                (m) => _ChildToolItem(
                  tool: WireParsers.asMap(m['tool']) ?? m,
                  message: m,
                ),
              ),
        ],
      ],
    );
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
    return _DetailCard(
      title: toolTitle,
      icon: Icons.build_outlined,
      trailing: ToolStatusIndicator(state: state, size: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelValue(
            label: context.l10n.messageDetailTool,
            value: toolName,
          ),
          _LabelValue(
            label: context.l10n.messageDetailState,
            value: toolState,
          ),
          if (isTask && input != null) ...[
            if (input!['subagent_type'] != null)
              _LabelValue(
                label: context.l10n.messageDetailAgentType,
                value: input!['subagent_type'].toString(),
              ),
            if (input!['description'] != null)
              _LabelValue(
                label: context.l10n.messageDetailDescription,
                value: input!['description'].toString(),
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
class _ToolResultSection extends StatefulWidget {
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
  State<_ToolResultSection> createState() =>
      _ToolResultSectionState();
}

class _ToolResultSectionState extends State<_ToolResultSection> {
  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  late final String _copyText;
  late final dynamic _jsonValue;

  @override
  void initState() {
    super.initState();
    _copyText = widget.json != null
        ? _jsonEncoder.convert(widget.json)
        : (widget.text ?? '');
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
      } catch (e) {
        logger.info('Failed to parse JSON: $e');
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
        side: BorderSide(
          color: cs.outlineVariant,
          width: AppBorder.hairline,
        ),
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
                // Copy button — always copies the raw JSON string
                _CopyButton(content: _copyText),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Interactive JSON tree or plain code block
            if (_jsonValue != null)
              _JsonTreeBlock(value: _jsonValue)
            else
              _CodeBlock(content: _copyText),
          ],
        ),
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
              ToolStatusIndicator(
                state: _parseToolState(state),
                size: 14,
              ),
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

  void _showToolDetail(
    BuildContext context,
    Map<String, dynamic> tool,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) =>
            _ToolDetailBottomSheet(
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
              ToolStatusIndicator(
                state: _parseToolState(state),
                size: 18,
              ),
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
                  json: input,
                ),
              if (input != null) const SizedBox(height: AppSpacing.md),
              if (result != null) ...[
                _ToolResultSection(
                  title: state == 'error'
                      ? context.l10n.commonError
                      : context.l10n.messageDetailOutput,
                  icon: state == 'error'
                      ? Icons.error_outline
                      : Icons.output,
                  json: result is Map<String, dynamic> ? result : null,
                  text: result is! Map<String, dynamic>
                      ? result.toString()
                      : null,
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
        side: BorderSide(
          color: cs.outlineVariant,
          width: AppBorder.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: cs.primary,
                ),
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
            child: SelectableText(
              value,
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Theme(
        // Force dark brightness so JsonTreeViewer always uses the dark palette
        // inside the always-dark code container.
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          colorScheme: Theme.of(context).colorScheme.copyWith(
            brightness: Brightness.dark,
            onSurface: const Color(0xFFD4D4D4),
          ),
        ),
        child: JsonTreeViewer(value: value),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: AppFontSize.sm,
          color: Color(0xFFD4D4D4),
        ),
      ),
    );
  }
}

/// Small icon button that copies [content] to the clipboard.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy, size: 16),
      tooltip: context.l10n.commonCopy,
      onPressed: () {
        Clipboard.setData(ClipboardData(text: content));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.commonCopiedToClipboard),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
