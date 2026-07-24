import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../models/sftp_log.dart';
import 'widgets/sftp_log_entry_card.dart';
import 'widgets/sftp_log_stats_tab.dart';
import '../../../core/utils/snack.dart';

export 'widgets/sftp_log_entry_card.dart';
export 'widgets/sftp_log_stats_tab.dart';

/// Log level filter
enum LogLevelFilter { all, info, warning, error }

/// Screen for viewing and managing SFTP server logs
class SftpLogViewerScreen extends StatefulWidget {
  const SftpLogViewerScreen({
    super.key,
    this.initialDeviceId,
    this.embedded = false,
    this.onClose,
  });

  final String? initialDeviceId;
  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<SftpLogViewerScreen> createState() => _SftpLogViewerScreenState();
}

class _SftpLogViewerScreenState extends State<SftpLogViewerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String? _selectedDeviceId;
  LogLevelFilter _levelFilter = LogLevelFilter.all;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  late TabController _tabController;

  List<SftpLogEntry> _allLogs = [];
  List<SftpLogEntry> _filteredLogs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _selectedDeviceId = widget.initialDeviceId;
    _loadLogs();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _loadLogs();
      _startRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadLogs(),
    );
  }

  void _loadLogs() {
    if (!mounted) return;
    setState(() {
      if (_selectedDeviceId != null) {
        _allLogs = sftpLogStore.getLogs(_selectedDeviceId!);
      } else {
        final allLogs = <SftpLogEntry>[];
        for (final deviceId in sftpLogStore.deviceIdsWithLogs) {
          allLogs.addAll(sftpLogStore.getLogs(deviceId));
        }
        allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _allLogs = allLogs;
      }
      _applyFilters();
    });
  }

  void _applyFilters() {
    var logs = List<SftpLogEntry>.from(_allLogs);

    if (_levelFilter != LogLevelFilter.all) {
      final levelName = _levelFilter.name;
      logs = logs.where((l) => l.level == levelName).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      logs = logs.where((l) {
        return l.message.toLowerCase().contains(query) ||
            (l.username?.toLowerCase().contains(query) ?? false) ||
            (l.operation?.toLowerCase().contains(query) ?? false) ||
            (l.details?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    _filteredLogs = logs;
  }

  Future<void> _exportLogs() async {
    final logs = _filteredLogs;
    if (logs.isEmpty) {
      if (mounted) {
        context.showSnack('No logs to export');
      }
      return;
    }

    final jsonStr = jsonEncode(logs.map((l) => l.toJson()).toList());
    await setClipboardTextSafely(jsonStr);

    if (mounted) {
      context.showSnack(
        '${logs.length} log entries copied '
        'to clipboard',
      );
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Logs'),
        content: Text(
          _selectedDeviceId != null
              ? 'Clear all logs for this device?'
              : 'Clear all SFTP logs?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      if (_selectedDeviceId != null) {
        await sftpLogStore.clearDeviceLogs(_selectedDeviceId!);
      } else {
        await sftpLogStore.clearAll();
      }
      _loadLogs();
    }
  }

  Future<void> _rotateLogs() async {
    await sftpLogStore.rotateLogs();
    _loadLogs();
    if (mounted) {
      context.showSnack('Old logs rotated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceIds = sftpLogStore.deviceIdsWithLogs;

    final actions = <Widget>[
      IconButton(
        icon: const Icon(Icons.file_upload),
        onPressed: _filteredLogs.isNotEmpty ? _exportLogs : null,
        tooltip: 'Export logs',
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'clear':
              _clearLogs();
            case 'rotate':
              _rotateLogs();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rotate', child: Text('Rotate old logs')),
          const PopupMenuItem(value: 'clear', child: Text('Clear logs')),
        ],
      ),
    ];

    final tabBar = PreferredSize(
      preferredSize: const Size.fromHeight(AppTouchTarget.comfortable),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Logs'),
            Tab(text: 'Stats'),
          ],
        ),
      ),
    );

    final body = TabBarView(
      controller: _tabController,
      children: [
        _buildLogsTab(deviceIds),
        SftpLogStatsTab(
          deviceIds: deviceIds,
          onRotateLogs: _rotateLogs,
          onClearLogs: _clearLogs,
        ),
      ],
    );

    if (widget.embedded) {
      final cs = Theme.of(context).colorScheme;
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant,
                  width: AppBorder.hairline,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'SFTP Logs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                ...actions,
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                    tooltip: 'Close',
                  ),
              ],
            ),
          ),
          tabBar,
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SFTP Logs'),
        actions: actions,
        bottom: tabBar,
      ),
      body: body,
    );
  }

  Widget _buildLogsTab(List<String> deviceIds) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          color: cs.surfaceContainerHighest,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.devices, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedDeviceId,
                        isDense: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Devices'),
                          ),
                          ...deviceIds.map(
                            (id) => DropdownMenuItem(
                              value: id,
                              child: Text(id, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedDeviceId = value;
                            _loadLogs();
                          });
                        },
                      ),
                    ),
                  ),
                  ...LogLevelFilter.values.map((filter) {
                    final isSelected = _levelFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text(
                          filter.name[0].toUpperCase() +
                              filter.name.substring(1),
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: isSelected ? cs.onPrimary : null,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _levelFilter = filter;
                            _applyFilters();
                          });
                        },
                        selectedColor: filter == LogLevelFilter.error
                            ? cs.error
                            : filter == LogLevelFilter.warning
                            ? AppColors.warning
                            : cs.primary,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _applyFilters();
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Text(
                '${_filteredLogs.length} entries',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (_allLogs.isNotEmpty)
                Text(
                  'Total: ${sftpLogStore.totalLogCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        Expanded(
          child: _filteredLogs.isEmpty
              ? AppEmptyState(
                  icon: Icons.article_outlined,
                  title: _allLogs.isEmpty
                      ? 'No logs yet'
                      : 'No logs match filters',
                  subtitle: _allLogs.isEmpty
                      ? 'Logs will appear here when '
                            'SFTP clients connect'
                      : 'Try adjusting your filters',
                )
              : RefreshIndicator(
                  onRefresh: () async => _loadLogs(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: _filteredLogs.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      return SftpLogEntryCard(
                        log: _filteredLogs[index],
                        onDeviceTap: (deviceId) {
                          setState(() {
                            _selectedDeviceId = deviceId;
                            _loadLogs();
                          });
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
