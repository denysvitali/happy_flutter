import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import 'tools/json_viewer.dart';
import 'tools/known_tools.dart';
import 'tools/tool_status_indicator.dart';

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
    final data = messageData ?? _lookupMessage(ref);

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Message')),
        body: const Center(child: Text('Message not found')),
      );
    }

    final kind = data['kind'] as String? ?? 'unknown';
    if (kind != 'tool-call') {
      return Scaffold(
        appBar: AppBar(title: const Text('Message')),
        body: _TextDetailView(data: data),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tool Details')),
      body: _ToolDetailView(data: data),
    );
  }

  Map<String, dynamic>? _lookupMessage(WidgetRef ref) {
    // Try to find message from sync service session messages
    final sessions = ref.watch(sessionsNotifierProvider);
    if (sessions[sessionId] == null) return null;
    return null; // Messages aren't stored on session model
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
      padding: const EdgeInsets.all(16),
      children: [
        _DetailCard(
          title: 'Content',
          icon: Icons.message_outlined,
          child: SelectableText(text),
        ),
      ],
    );
  }
}

// ── Tool detail view ───────────────────────────────────────────────────────

class _ToolDetailView extends StatelessWidget {
  const _ToolDetailView({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = data['name'] as String? ?? 'Unknown';
    final toolState = data['state'] as String? ?? 'pending';
    final input = data['input'] as Map<String, dynamic>?;
    final result = data['result'];
    final permission = data['permission'] as Map<String, dynamic>?;
    final messages = data['messages'] as List<dynamic>?;

    final knownTool = KnownTools.get(toolName);
    final isTask = toolName == 'Task';

    var toolTitle = toolName;
    if (knownTool != null) {
      if (knownTool.title is String) {
        toolTitle = knownTool.title;
      }
    }

    final state = _parseState(toolState);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        _MessageHeader(
          toolTitle: toolTitle,
          toolName: toolName,
          toolState: toolState,
          state: state,
          isTask: isTask,
          input: input,
        ),
        const SizedBox(height: 12),

        // Permission info
        if (permission != null) ...[
          _DetailCard(
            title: 'Permission',
            icon: Icons.shield_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelValue(
                  label: 'Status',
                  value: permission['status'] as String? ?? 'unknown',
                ),
                if (permission['reason'] != null)
                  _LabelValue(
                    label: 'Reason',
                    value: permission['reason'].toString(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Input
        if (input != null) ...[
          _ToolResultSection(
            title: 'Input',
            icon: Icons.input,
            json: input,
          ),
          const SizedBox(height: 12),
        ],

        // Output/Result
        if (result != null && state != ToolState.running) ...[
          _ToolResultSection(
            title: state == ToolState.error ? 'Error' : 'Output',
            icon: state == ToolState.error
                ? Icons.error_outline
                : Icons.output,
            json: result is Map || result is List ? result : null,
            text: result is! Map && result is! List
                ? result.toString()
                : null,
            isError: state == ToolState.error,
          ),
          const SizedBox(height: 12),
        ],

        // Child tools for Task/sub-agent
        if (isTask && messages != null && messages.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Sub-agent Tools',
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
                  tool: m['tool'] as Map<String, dynamic>? ?? m,
                  message: m,
                ),
              ),
        ],
      ],
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
          _LabelValue(label: 'Tool', value: toolName),
          _LabelValue(label: 'State', value: toolState),
          if (isTask && input != null) ...[
            if (input!['subagent_type'] != null)
              _LabelValue(
                label: 'Agent type',
                value: input!['subagent_type'].toString(),
              ),
            if (input!['description'] != null)
              _LabelValue(
                label: 'Description',
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Resolve a copyable plain-text representation for the copy button.
    final copyText = json != null
        ? const JsonEncoder.withIndent('  ').convert(json)
        : (text ?? '');

    // Determine whether to show the interactive JSON tree.
    final dynamic jsonValue = _resolveJson();

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isError ? cs.error : cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isError ? cs.error : null,
                    ),
                  ),
                ),
                // Copy button — always copies the raw JSON string
                _CopyButton(content: copyText),
              ],
            ),
            const SizedBox(height: 8),
            // Interactive JSON tree or plain code block
            if (jsonValue != null)
              _JsonTreeBlock(value: jsonValue)
            else
              _CodeBlock(content: copyText),
          ],
        ),
      ),
    );
  }

  /// Returns a parsed JSON value (Map or List) if the content is JSON,
  /// or null if it should be rendered as plain text.
  dynamic _resolveJson() {
    if (json is Map || json is List) return json;
    final t = text;
    if (t == null) return null;
    final trimmed = t.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return jsonDecode(t);
      } catch (_) {}
    }
    return null;
  }
}

// ── Message actions bar ────────────────────────────────────────────────────

/// Clean bottom action bar with icon buttons and a subtle top border.
// ignore: unused_element
class _MessageActions extends StatelessWidget {
  const _MessageActions({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy',
            iconSize: 20,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            iconSize: 20,
            onPressed: null, // placeholder — wire up if needed
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border_outlined),
            tooltip: 'Bookmark',
            iconSize: 20,
            onPressed: null, // placeholder — wire up if needed
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────

/// Renders a single chat message bubble with rounded corners (16 px).
/// User messages are right-aligned with a primary-tinted background;
/// assistant messages are left-aligned with the surface variant.
// ignore: unused_element
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bgColor = isUser
        ? cs.primaryContainer
        : cs.surfaceContainerHighest;
    final textColor = isUser
        ? cs.onPrimaryContainer
        : cs.onSurface;
    final borderColor = isUser
        ? cs.primary.withValues(alpha: 0.3)
        : cs.outlineVariant.withValues(alpha: 0.5);

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isUser
          ? const Radius.circular(16)
          : const Radius.circular(4),
      bottomRight: isUser
          ? const Radius.circular(4)
          : const Radius.circular(16),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: radius,
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: SelectableText(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
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
      title = knownTool!.extractDescription!(tool, null) ?? toolName;
    } else if (knownTool?.title is String) {
      title = knownTool!.title;
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showToolDetail(context, tool),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            children: [
              SizedBox(width: 18, height: 18, child: icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ToolStatusIndicator(
                state: _parseState(state),
                size: 14,
              ),
              const SizedBox(width: 4),
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
    final input = tool['input'] as Map<String, dynamic>?;
    final result = tool['result'];

    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(77),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              KnownTools.iconFor(
                toolName,
                20,
                theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toolName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ToolStatusIndicator(
                state: _parseState(state),
                size: 18,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              if (input != null)
                _ToolResultSection(
                  title: 'Input',
                  icon: Icons.input,
                  json: input,
                ),
              if (input != null) const SizedBox(height: 12),
              if (result != null) ...[
                _ToolResultSection(
                  title: state == 'error' ? 'Error' : 'Output',
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
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(bottom: 4),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
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
      tooltip: 'Copy',
      onPressed: () {
        Clipboard.setData(ClipboardData(text: content));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
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
