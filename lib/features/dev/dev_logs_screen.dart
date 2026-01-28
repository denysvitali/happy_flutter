import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/logger_service.dart';
import '../../core/providers/logger_provider.dart';
import '../../core/utils/datetime_extensions.dart';

/// Debug logs screen - only available in debug builds
class DevLogsScreen extends ConsumerWidget {
  const DevLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only allow access in debug builds
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Logs')),
        body: Center(
          child: Text(
            'Logs are only available in debug builds',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final loggerState = ref.watch(loggerNotifierProvider);
    final filteredLogs = loggerState.filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: Text('Logs (${filteredLogs.length})'),
        actions: [
          // Add test log button
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Test Log',
            onPressed: () {
              final timestamp = DateTime.now().toIsoTimeString();
              ref.read(loggerNotifierProvider.notifier).debug(
                  'Test log entry at $timestamp');
            },
          ),
          // Copy all logs
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy All Logs',
            onPressed: filteredLogs.isEmpty
                ? null
                : () => _copyAllLogs(context, ref),
          ),
          // Clear logs
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Logs',
            onPressed: filteredLogs.isEmpty
                ? null
                : () => _showClearConfirmDialog(context, ref),
          ),
          // Filter dropdown
          PopupMenuButton<LogLevel?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by Level',
            onSelected: (value) {
              ref.read(loggerNotifierProvider.notifier).setFilterLevel(value?.index);
            },
            itemBuilder: (context) => [
              const PopupMenuItem<LogLevel?>(
                value: null,
                child: Text('All Levels'),
              ),
              const PopupMenuItem<LogLevel?>(
                value: LogLevel.debug,
                child: Text('Debug'),
              ),
              const PopupMenuItem<LogLevel?>(
                value: LogLevel.info,
                child: Text('Info'),
              ),
              const PopupMenuItem<LogLevel?>(
                value: LogLevel.warning,
                child: Text('Warning'),
              ),
              const PopupMenuItem<LogLevel?>(
                value: LogLevel.error,
                child: Text('Error'),
              ),
            ],
          ),
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Logs',
            onPressed: () => _showSearchDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Logs (${filteredLogs.length}${loggerState.filterLevel != null ? ' filtered' : ''})',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                if (loggerState.filterLevel != null)
                  TextButton(
                    onPressed: () {
                      ref
                          .read(loggerNotifierProvider.notifier)
                          .setFilterLevel(null);
                    },
                    child: const Text('Clear Filter'),
                  ),
              ],
            ),
          ),
          // Logs display
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No logs yet',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Logs will appear here as they are generated',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : LogListView(logs: filteredLogs),
          ),
        ],
      ),
    );
  }

  Future<void> _copyAllLogs(BuildContext context, WidgetRef ref) async {
    final logs = ref.read(loggerNotifierProvider).filteredLogs;
    if (logs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No logs to copy')),
        );
      }
      return;
    }

    final allLogs =
        logs.map((entry) => entry.toFormattedString()).join('\n');
    await Clipboard.setData(ClipboardData(text: allLogs));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${logs.length} log entries copied')),
      );
    }
  }

  Future<void> _showClearConfirmDialog(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(loggerNotifierProvider.notifier).clear();
    }
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Logs'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter search term...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            // Filter is handled by the search in LogListView
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.clear();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              // Store search query and apply filter
              ref.read(loggerNotifierProvider.notifier).setSearchQuery(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}

/// Scrollable list of log entries
class LogListView extends StatefulWidget {
  final List<LogEntry> logs;

  const LogListView({super.key, required this.logs});

  @override
  State<LogListView> createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll to bottom when new logs arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(LogListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length != oldWidget.logs.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        _scrollController.position.maxScrollExtent,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: widget.logs.length,
        itemBuilder: (context, index) {
          // Show most recent at bottom (reversed order)
          final entry = widget.logs[widget.logs.length - 1 - index];
          return LogEntryWidget(entry: entry);
        },
      ),
    );
  }
}

/// Individual log entry widget with color coding by level
class LogEntryWidget extends StatelessWidget {
  final LogEntry entry;

  const LogEntryWidget({super.key, required this.entry});

  Color _getLevelColor(BuildContext context) {
    switch (entry.level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  IconData _getLevelIcon() {
    switch (entry.level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getLevelColor(context);
    final time = entry.timestamp.toIsoTimeString();

    return Material(
      child: InkWell(
        onTap: () => _showEntryDetails(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time
              SizedBox(
                width: 80,
                child: Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
              // Level indicator
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  entry.level.name.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              // Message
              Expanded(
                child: Text(
                  entry.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Error indicator
              if (entry.error != null || entry.stackTrace != null)
                Icon(
                  _getLevelIcon(),
                  size: 16,
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEntryDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _getLevelIcon(),
                  color: _getLevelColor(context),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.level.name.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _getLevelColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  entry.timestamp.toIso8601String(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              entry.message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            if (entry.error != null) ...[
              const SizedBox(height: 16),
              Text(
                'Error:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            if (entry.stackTrace != null) ...[
              const SizedBox(height: 16),
              Text(
                'Stack Trace:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  entry.stackTrace.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: entry.toFormattedString()),
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log entry copied')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
