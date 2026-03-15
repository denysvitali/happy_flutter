import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/logger_provider.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/datetime_extensions.dart';

/// Debug logs screen - available when developer mode is enabled
class DevLogsScreen extends ConsumerWidget {
  const DevLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Allow access when developer mode is enabled
    final isDeveloperMode = ref.watch(
      settingsNotifierProvider.select((s) => s.developerModeEnabled),
    );
    final l10n = AppLocalizations.of(context);
    if (!isDeveloperMode) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.devLogsTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              l10n.devLogsOnlyAvailableInDevMode,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final loggerState = ref.watch(loggerNotifierProvider);
    final filteredLogs = loggerState.filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.devLogsCount(filteredLogs.length)),
        actions: [
          // Add test log button
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.devLogsAddTestLog,
            onPressed: () {
              final timestamp = DateTime.now().toIsoTimeString();
              ref.read(loggerNotifierProvider.notifier).debug(
                  'Test log entry at $timestamp');
            },
          ),
          // Copy all logs
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.devLogsCopyAllLogs,
            onPressed: filteredLogs.isEmpty
                ? null
                : () => _copyAllLogs(context, ref),
          ),
          // Clear logs
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: l10n.devLogsClearTitle,
            onPressed: filteredLogs.isEmpty
                ? null
                : () => _showClearConfirmDialog(context, ref),
          ),
          // Filter dropdown
          PopupMenuButton<LogLevel?>(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.devLogsFilterByLevel,
            onSelected: (value) {
              ref.read(
                loggerNotifierProvider.notifier,
              ).setFilterLevel(value?.index);
            },
            itemBuilder: (context) => [
              PopupMenuItem<LogLevel?>(
                value: null,
                child: Text(l10n.devLogsAllLevels),
              ),
              PopupMenuItem<LogLevel?>(
                value: LogLevel.debug,
                child: Text(l10n.devLogsLevelDebug),
              ),
              PopupMenuItem<LogLevel?>(
                value: LogLevel.info,
                child: Text(l10n.devLogsLevelInfo),
              ),
              PopupMenuItem<LogLevel?>(
                value: LogLevel.warning,
                child: Text(l10n.devLogsLevelWarning),
              ),
              PopupMenuItem<LogLevel?>(
                value: LogLevel.error,
                child: Text(l10n.devLogsLevelError),
              ),
            ],
          ),
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.devLogsSearchLogs,
            onPressed: () => _showSearchDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loggerState.filterLevel != null
                      ? l10n.devLogsCountFiltered(
                          filteredLogs.length,
                        )
                      : l10n.devLogsCount(filteredLogs.length),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                if (loggerState.filterLevel != null)
                  TextButton(
                    onPressed: () {
                      ref
                          .read(loggerNotifierProvider.notifier)
                          .setFilterLevel(null);
                    },
                    child: Text(l10n.devLogsClearFilter),
                  ),
              ],
            ),
          ),
          // Logs display
          Expanded(
            child: filteredLogs.isEmpty
                ? AppEmptyState(
                    icon: Icons.note_alt_outlined,
                    title: l10n.devLogsEmpty,
                    subtitle: l10n.devLogsEmptyDesc,
                  )
                : LogListView(logs: filteredLogs),
          ),
        ],
      ),
    );
  }

  Future<void> _copyAllLogs(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final noLogsMsg = l10n.devLogsNoLogsToCopy;
    final logs = ref.read(loggerNotifierProvider).filteredLogs;
    if (logs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(noLogsMsg)),
        );
      }
      return;
    }

    final copiedMsg = l10n.devLogsCopied(logs.length);
    final allLogs =
        logs.map((entry) => entry.toFormattedString()).join('\n');
    await Clipboard.setData(ClipboardData(text: allLogs));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copiedMsg)),
      );
    }
  }

  Future<void> _showClearConfirmDialog(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.devLogsClearTitle),
          content: Text(l10n.devLogsClearConfirm),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => context.pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.devLogsClearAction),
            ),
          ],
        );
      },
    );

    if (confirmed ?? false) {
      ref.read(loggerNotifierProvider.notifier).clear();
    }
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(dialogL10n.devLogsSearchTitle),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: dialogL10n.devLogsSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) {
              // Filter is handled by the search in LogListView
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(context);
              },
              child: Text(dialogL10n.devLogsClearAction),
            ),
            FilledButton(
              onPressed: () {
                ref.read(
                  loggerNotifierProvider.notifier,
                ).setSearchQuery(controller.text);
                controller.dispose();
                Navigator.pop(context);
              },
              child: Text(dialogL10n.commonSearch),
            ),
          ],
        );
      },
    );
  }
}

/// Scrollable list of log entries
class LogListView extends StatefulWidget {

  const LogListView({required this.logs, super.key});
  final List<LogEntry> logs;

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

  const LogEntryWidget({required this.entry, super.key});
  final LogEntry entry;

  Color _getLevelColor(BuildContext context) {
    switch (entry.level) {
      case LogLevel.debug:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case LogLevel.info:
        return AppColors.success;
      case LogLevel.warning:
        return AppColors.warning;
      case LogLevel.error:
        return Theme.of(context).colorScheme.error;
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

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      child: InkWell(
        onTap: () => _showEntryDetails(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant
                    .withValues(alpha: AppOpacity.medium),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  time,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.xs,
                    color: cs.outline,
                  ),
                ),
              ),
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: AppOpacity.subtle,
                  ),
                  borderRadius:
                      BorderRadius.circular(AppRadius.xs),
                  border: Border.all(
                    color: color.withValues(
                      alpha: AppOpacity.medium,
                    ),
                  ),
                ),
                child: Text(
                  entry.level.name.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  entry.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.md,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.error != null ||
                  entry.stackTrace != null)
                Icon(
                  _getLevelIcon(),
                  size: AppSpacing.lg,
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
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final color = _getLevelColor(ctx);

        return Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(_getLevelIcon(), color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    entry.level.name.toUpperCase(),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    entry.timestamp.toIso8601String(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                entry.message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.md,
                ),
              ),
              if (entry.error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Error:',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.errorContainer
                        .withValues(alpha: AppOpacity.medium),
                    borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    entry.error.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.md,
                      color: cs.error,
                    ),
                  ),
                ),
              ],
              if (entry.stackTrace != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Stack Trace:',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    entry.stackTrace.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: entry.toFormattedString(),
                      ),
                    );
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)
                              .devLogsLogEntryCopied,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(
                    AppLocalizations.of(context).devLogsCopyEntry,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
