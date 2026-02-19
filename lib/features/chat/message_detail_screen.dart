import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
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
        _DetailCard(
          title: toolTitle,
          icon: Icons.build_outlined,
          trailing: ToolStatusIndicator(state: state, size: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabelValue(label: 'Tool', value: toolName),
              _LabelValue(label: 'State', value: toolState),
              if (isTask && input != null) ...[
                if (input['subagent_type'] != null)
                  _LabelValue(
                    label: 'Agent type',
                    value: input['subagent_type'].toString(),
                  ),
                if (input['description'] != null)
                  _LabelValue(
                    label: 'Description',
                    value: input['description'].toString(),
                  ),
              ],
            ],
          ),
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
                  value:
                      permission['status'] as String? ?? 'unknown',
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
          _JsonCard(
            title: 'Input',
            icon: Icons.input,
            json: input,
          ),
          const SizedBox(height: 12),
        ],

        // Output/Result
        if (result != null &&
            state != ToolState.running) ...[
          _JsonCard(
            title: state == ToolState.error ? 'Error' : 'Output',
            icon: state == ToolState.error
                ? Icons.error_outline
                : Icons.output,
            json: result is Map<String, dynamic>
                ? result
                : null,
            text: result is! Map<String, dynamic>
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
      title =
          knownTool!.extractDescription!(tool, null) ?? toolName;
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
                _JsonCard(
                  title: 'Input',
                  icon: Icons.input,
                  json: input,
                ),
              if (input != null) const SizedBox(height: 12),
              if (result != null) ...[
                _JsonCard(
                  title: state == 'error' ? 'Error' : 'Output',
                  icon: state == 'error'
                      ? Icons.error_outline
                      : Icons.output,
                  json: result is Map<String, dynamic>
                      ? result
                      : null,
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

// ── Shared detail widgets ──────────────────────────────────────

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

class _JsonCard extends StatelessWidget {
  const _JsonCard({
    required this.title,
    required this.icon,
    this.json,
    this.text,
    this.isError = false,
  });
  final String title;
  final IconData icon;
  final Map<String, dynamic>? json;
  final String? text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = json != null
        ? const JsonEncoder.withIndent('  ').convert(json)
        : (text ?? '');

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
                  color: isError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isError
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                ),
                // Copy button
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: content),
                    );
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
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
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
            ),
          ],
        ),
      ),
    );
  }
}
